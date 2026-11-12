function modelPath = tdm_residual_build_observer(d, holdoutLimit_V, outDir, model)
% 生成独立的原生 Simulink 分时窗口残差观测器。
% 每拍输入一帧对齐到物理采样时刻的 X/Y 数据与聚合过载标志。
% 相位、模板和投影矩阵在离线标定时确定，运行时只用原生矩阵乘法和门控。
arguments
    d (1,1) struct
    holdoutLimit_V (1,1) double {mustBePositive}
    outDir (1,:) char = fullfile(fileparts(mfilename('fullpath')),'models')
    model (1,:) char = 'hrg_tdm_residual_observer'
end

obs.sampleCount = size(d.jointCarrierMap,2);
assert(obs.sampleCount > 1 && isequal(size(d.jointCarrierMap),[2 obs.sampleCount]) && ...
    isequal(size(d.lateCarrierMap),[2 obs.sampleCount]) && ...
    size(d.holdoutErrorMap,2) == obs.sampleCount && numel(d.lateMask) == obs.sampleCount, ...
    '残差设计矩阵与观测器窗口长度不一致。');
obs.jointCarrierMap = d.jointCarrierMap;
obs.lateCarrierMap = d.lateCarrierMap;
obs.holdoutErrorMap = d.holdoutErrorMap;
obs.holdoutCount = size(d.holdoutErrorMap,1);
if obs.holdoutCount == 0
    % 留出集合为空时仍保留定长诊断端口，联合通路由设计门禁禁止。
    obs.holdoutErrorMap = zeros(1,obs.sampleCount);
end
obs.holdoutMean = ones(1,size(obs.holdoutErrorMap,1))/max(1,obs.holdoutCount);
obs.allMask = ones(1,obs.sampleCount);
obs.lateMask = double(d.lateMask(:).');
obs.jointDesignOK = logical(d.jointDesignOK) && obs.holdoutCount > 0;
obs.lateDesignOK = logical(d.lateDesignOK);
obs.holdoutLimit = holdoutLimit_V;

% 试验回放可使用独立名称，与已打开的交付模型并存。
assert(isvarname(model),'原生观测器需要有效的模型名。');
assert(~bdIsLoaded(model),'生成前请先关闭已打开的 %s。',model);
if ~isfolder(outDir), mkdir(outDir); end
load_system('simulink');
new_system(model);
cleanup = onCleanup(@() close_system(model,0));
assignin(get_param(model,'ModelWorkspace'),'obs',obs);
set_param(model,'Solver','FixedStepDiscrete','SolverType','Fixed-step','FixedStep','1', ...
    'StopTime','0','SaveTime','off','SaveOutput','on','OutputSaveName','yout', ...
    'SaveFormat','Dataset','SignalLogging','on','SignalLoggingName','logsout', ...
    'ReturnWorkspaceOutputs','on');
set_param(model,'Description',sprintf('原生分时残差观测器，%d 个样本/帧，留出 RMS 门限 %.6g V。', ...
    obs.sampleCount,obs.holdoutLimit));

% 每个模型时间单位代表一帧，帧内样本相位由离线投影包含。
% 两路同用一个采样门禁。clipped 为 ADC 流水线前的逐拍合并标志。
add(model,'Frame samples V','Ports & Subsystems/In1','Port','1', ...
    'PortDimensions','[obs.sampleCount 2]','SampleTime','1','OutDataTypeStr','double');
add(model,'Clipped samples','Ports & Subsystems/In1','Port','2', ...
    'PortDimensions','obs.sampleCount','SampleTime','1','OutDataTypeStr','boolean');
samples = 'Frame samples V';
clipped = unary(model,'Clips to numbers','Signal Attributes/Data Type Conversion', ...
    'Clipped samples','OutDataTypeStr','double');

% 联合解与晚窗基线都直接投影原始双通道输入。
% 留出误差投影来自仅使用训练点拟合的联合模型。
joint = matrix(model,'Joint carrier estimate','obs.jointCarrierMap',samples);
late = matrix(model,'Late carrier estimate','obs.lateCarrierMap',samples);
errorVoltage = matrix(model,'Held-out prediction error','obs.holdoutErrorMap',samples);
squared = connect(model,'Squared held-out error','Math Operations/Product', ...
    {errorVoltage,errorVoltage},'Inputs','**','Multiplication','Element-wise(.*)');
meanSquare = matrix(model,'Held-out mean square','obs.holdoutMean',squared);
rms = unary(model,'Held-out RMS by channel','Math Operations/Math Function',meanSquare,'Operator','sqrt');
limit = constant(model,'Held-out limit V','obs.holdoutLimit');
goodHoldout = compare(model,'Within held-out limit','<=',rms,limit);
goodHoldout = unary(model,'Holdout flags to numbers','Signal Attributes/Data Type Conversion', ...
    goodHoldout,'OutDataTypeStr','double');
goodHoldoutCount = unary(model,'Number of passing channels','Math Operations/Gain', ...
    goodHoldout,'Gain','[1;1]','Multiplication','Matrix(u*K)');
holdoutOK = compare(model,'Both channels predict held-out samples','==', ...
    goodHoldoutCount,constant(model,'Two channels','2'));

% 过载点不会被静默修补。早窗过载仅阻断联合解，晚窗过载同时阻断两路。
anyClip = matrix(model,'Full window clip count','obs.allMask',clipped);
lateClip = matrix(model,'Late window clip count','obs.lateMask',clipped);
zero = constant(model,'Zero clips','0');
eligible = logic(model,'Joint candidate eligible','AND', ...
    {compare(model,'Full window clear','==',anyClip,zero), ...
    constant(model,'Joint rank and information valid','obs.jointDesignOK')});
jointOK = logic(model,'Joint candidate valid','AND',{eligible,holdoutOK});
reportedRms = pick(model,'Held-out RMS or unavailable',rms,eligible, ...
    constant(model,'Unavailable RMS','NaN(1,2)'));
lateOK = logic(model,'Late candidate valid','AND', ...
    {compare(model,'Late window clear','==',lateClip,zero), ...
    constant(model,'Late carrier rank valid','obs.lateDesignOK')});
safeLate = pick(model,'Late estimate or invalid',late,lateOK, ...
    constant(model,'Invalid I Q','NaN(2,2)'));
chosen = pick(model,'Selected I Q',joint,jointOK,safeLate);
fallback = pick(model,'Late or invalid mode',constant(model,'Late mode','1'), ...
    lateOK,constant(model,'Invalid mode','0'));
mode = pick(model,'Selected mode',constant(model,'Joint mode','2'),jointOK,fallback);

outputs = {
    'IQ', chosen
    'Mode', mode
    'HoldoutRMS_V', reportedRms
    'JointOK', jointOK
    'LateOK', lateOK
    };
for k = 1:size(outputs,1)
    name = outputs{k,1};
    add(model,name,'Ports & Subsystems/Out1','Port',num2str(k));
    line = wire(model,outputs{k,2},name,1);
    set_param(line,'Name',name);
end
add(model,'Estimate mode display','Sinks/Display');
wire(model,mode,'Estimate mode display',1);
logNode(model,joint,'joint_iq');
logNode(model,late,'late_iq');
logNode(model,reportedRms,'holdout_rms_V');
logNode(model,mode,'observer_mode');
logNode(model,anyClip,'full_clip_count');
logNode(model,lateClip,'late_clip_count');
Simulink.BlockDiagram.arrangeSystem(model);
addDescription(model);
modelPath = fullfile(outDir,[model '.slx']);
save_system(model,modelPath);
end

function addDescription(model)
% 原生图上说明矩阵输入的量纲与回退编码。
positions = get_param(find_system(model,'SearchDepth',1,'Type','Block'),'Position');
positions = vertcat(positions{:});
left = min(positions(:,1));
top = min(positions(:,2))-110;
lines = {
    '分时窗口残差观测器'
    '输入为按 ADC 物理时刻对齐的整帧 X/Y 电压，模型时间单位为帧。'
    '留出检验使用独立训练拟合，过关后用全窗联合估计。'
    'Mode 2 使用联合估计，Mode 1 使用晚窗基线，Mode 0 表示当前帧无效。'
    };
note = Simulink.Annotation(model,strjoin(lines,newline));
note.FontSize = 12;
note.BackgroundColor = 'lightBlue';
note.Position = [left top left+750 top+92];
end

function logNode(model, node, label)
% 运行后可在 Data Inspector 中核对各级波形和门禁。
ports = get_param([model '/' node],'PortHandles');
set_param(ports.Outport(1),'DataLogging','on', ...
    'DataLoggingNameMode','Custom','DataLoggingName',label);
end

function name = pick(model, name, pass, gate, fail)
name = connect(model,name,'Signal Routing/Switch',{pass,gate,fail},'Criteria','u2 ~= 0');
end

function name = compare(model, name, operator, left, right)
name = connect(model,name,'Logic and Bit Operations/Relational Operator',{left,right},'Operator',operator);
end

function name = logic(model, name, operator, sources)
name = connect(model,name,'Logic and Bit Operations/Logical Operator',sources, ...
    'Operator',operator,'Inputs',num2str(numel(sources)));
end

function name = matrix(model, name, gain, source)
name = unary(model,name,'Math Operations/Gain',source,'Gain',gain,'Multiplication','Matrix(K*u)');
end

function name = constant(model, name, value)
name = add(model,name,'Sources/Constant','Value',value);
end

function name = unary(model, name, path, source, varargin)
name = connect(model,name,path,{source},varargin{:});
end

function name = connect(model, name, path, sources, varargin)
name = add(model,name,path,varargin{:});
for k = 1:numel(sources), wire(model,sources{k},name,k); end
end

function name = add(model, name, path, varargin)
count = numel(find_system(model,'SearchDepth',1,'Type','Block'));
x = 40+145*mod(count,7);
y = 40+75*floor(count/7);
add_block(['simulink/' path],[model '/' name],'Position',[x y x+55 y+30],varargin{:});
end

function line = wire(model, source, target, port)
line = add_line(model,[source '/1'],sprintf('%s/%d',target,port),'autorouting','on');
end
