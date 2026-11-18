function score=split_bias_native_check(folder,mode,c,L,weights,raw,corrected,caseNumber)
% 原生帧级复验。复用电气与控制模型的 Estimate，实时计算 Stokes 角、机体角及漂移积分。
% 冻结系数由离线标定入口在验证频差范围后装载。研究副本沿用全帧有效假设。
model=['hrg_bias_' mode]; outDir=fullfile(folder,'split_bias_models');
if ~isfolder(outDir),mkdir(outDir);end
file=fullfile(outDir,[model '.slx']);
if caseNumber==6
    source=['hrg_lift_' mode];load_system(fullfile(folder,'lift_models',[source '.slx']));
    sourceCleanup=onCleanup(@() closeIfLoaded(source));
    save_system(source,file);clear sourceCleanup
    load_system(file);closeModel=onCleanup(@() closeIfLoaded(model)); %#ok<NASGU>
    ws=get_param(model,'ModelWorkspace');ws.assignin('c',c);ws.assignin('L',L);ws.assignin('biasWeights',weights);
    % 输入向量按 Ix,Iy,Qx,Qy 排列。两项二次型得到 S1、S2。
    gain('Q1','diag([1 -1 1 -1])');gain('Q2','[0 1 0 0;1 0 0 0;0 0 0 1;0 0 1 0]');
    block('S1','Math Operations/Dot Product');block('S2','Math Operations/Dot Product');
    for i=1:2
        q=sprintf('Q%d',i);s=sprintf('S%d',i);
        wire('Estimate',1,q,1);wire('Estimate',1,s,1);wire(q,1,s,2);
    end
    trig('Az4','atan2');wire('S2',1,'Az4',1);wire('S1',1,'Az4',2);
    gain('Double azimuth','2');wire('Az4',1,'Double azimuth',1);
    block('One','Sources/Constant','Value','1');
    block('Harmonics','Signal Routing/Mux','Inputs','5');wire('One',1,'Harmonics',1);
    signals={'Az4','Az4','Double azimuth','Double azimuth'};
    ops={'cos','sin','cos','sin'};
    for i=1:4
        name=sprintf('Harmonic %d',i);trig(name,ops{i});wire(signals{i},1,name,1);wire(name,1,'Harmonics',i+1);
    end
    gain('Bias rate','biasWeights(:)''');wire('Harmonics',1,'Bias rate',1);
    gain('Bias increment','L.T');wire('Bias rate',1,'Bias increment',1);
    delay('Bias integral');sumBlock('Next integral','++');
    wire('Bias integral',1,'Next integral',1);wire('Bias increment',1,'Next integral',2);wire('Next integral',1,'Bias integral',1);
    % 将跨±pi的增量包裹到主值，第一帧建立零角锚点。
    delay('Previous azimuth');wire('Az4',1,'Previous azimuth',1);sumBlock('Delta','+-');
    wire('Az4',1,'Delta',1);wire('Previous azimuth',1,'Delta',2);
    trig('Delta sin','sin');trig('Delta cos','cos');trig('Wrap','atan2');
    wire('Delta',1,'Delta sin',1);wire('Delta',1,'Delta cos',1);
    wire('Delta sin',1,'Wrap',1);wire('Delta cos',1,'Wrap',2);
    gain('Body increment','-1/(4*c.B)');wire('Wrap',1,'Body increment',1);
    delay('Has anchor');wire('One',1,'Has anchor',1);block('Valid increment','Math Operations/Product');
    wire('Has anchor',1,'Valid increment',1);wire('Body increment',1,'Valid increment',2);
    delay('Prior raw angle');sumBlock('Raw angle','++');wire('Prior raw angle',1,'Raw angle',1);
    wire('Valid increment',1,'Raw angle',2);wire('Raw angle',1,'Prior raw angle',1);
    sumBlock('Corrected angle','+-');wire('Raw angle',1,'Corrected angle',1);wire('Bias integral',1,'Corrected angle',2);
    block('Score angles','Signal Routing/Mux','Inputs','2');wire('Raw angle',1,'Score angles',1);wire('Corrected angle',1,'Score angles',2);
    block('Export angles','Sinks/To Workspace','VariableName','biasAngles','SaveFormat','Array','MaxDataPoints','inf');
    wire('Score angles',1,'Export angles',1);
    Simulink.Annotation(model,'零速角向标定，频差系数冻结。每帧由检测 I/Q 计算发布角与补偿角，单位 rad。');
    Simulink.BlockDiagram.arrangeSystem(model);save_system(model);
else
    load_system(file);closeModel=onCleanup(@() closeIfLoaded(model)); %#ok<NASGU>
end
in=Simulink.SimulationInput(model);in=in.setVariable('c',c,'Workspace',model);
in=in.setVariable('L',L,'Workspace',model);in=in.setVariable('biasWeights',weights,'Workspace',model);
out=sim(in); delta=max(abs(out.biasAngles-[raw corrected]),[],1);
assert(all(delta<1e-8));
score=struct('case_index',caseNumber,'frames',size(raw,1),'max_raw_corrected_delta_rad',delta);
    function block(n,type,varargin),add_block(['simulink/' type],[model '/' n],varargin{:});end
    function gain(n,g),block(n,'Math Operations/Gain','Gain',g,'Multiplication','Matrix(K*u)');end
    function delay(n),block(n,'Discrete/Unit Delay','SampleTime','L.T','InitialCondition','0');end
    function trig(n,op),block(n,'Math Operations/Trigonometric Function','Operator',op);end
    function sumBlock(n,op),block(n,'Math Operations/Sum','Inputs',op);end
    function wire(a,pa,b,pb),add_line(model,sprintf('%s/%d',a,pa),sprintf('%s/%d',b,pb),'autorouting','on');end
end

function closeIfLoaded(name)
if bdIsLoaded(name),close_system(name,0);end
end
