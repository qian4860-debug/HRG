function receipt = split_reference_native_replay(cache, project, numpy_file)
% 原生 Simulink 测频包处理与积分回放。先用 prepare_rate_replay(cache,project)
% 生成闭环轨迹，并运行 score_rate_replay.py 生成 NumPy 对照回执，再调用本函数。
% 模型工作区内保存完整标称输入，直接打开 SLX 可重放；真值只在离线评分中使用。
folder = fileparts(mfilename('fullpath'));
if nargin < 2, project = fileparts(fileparts(folder)); end
if nargin < 3, numpy_file = fullfile(folder,'rate_replay.json'); end
model = 'hrg_split_reference_replay';
assert(~bdIsLoaded(model),'请先关闭同名模型再重建，避免覆盖打开的模型。');
scope = jsondecode(fileread(fullfile(cache,'catalog.json')));
selected = strcmp({scope.mode},'tdm_shared') & [scope.rate_mrad_s]==0.3 & [scope.split_mHz]==50;
traj = scope(selected); dt = traj.dt_s;
fid = fopen(fullfile(cache,traj.file),'rb','ieee-le'); assert(fid>=0);
cleanupFile = onCleanup(@() fclose(fid));
v = fread(fid,[2 Inf],'double').'; clear cleanupFile
t = (0:size(v,1)-1)'*dt;
fit = jsondecode(fileread(fullfile(project,'research','three_angle_observation_20261115','split_bias_verification.json')));
W = fit.modes(strcmp({fit.modes.mode},traj.mode)).calibration_rad_s;
e = jsondecode(fileread(fullfile(folder,'estimates.json')));
r = e.rows(strcmp({e.rows.run_id},'nominal_f050_r01'));
[replayData,ref] = inputs(t,dt,v,r,W);
build(model,folder,replayData,W,dt); cleanupModel = onCleanup(@() close_system(model,0));
nominal = run_case(model,replayData,ref,t);
% 构造只掉包的对照，保留观察量及包自身精度标志，使旧有效包自然到期。
usable = find([r.valid] & [r.split_est_mHz]<=50 & [r.t_s]<18,1);
assert(~isempty(usable));
dropped = r; dropped(usable+(1:2)) = [];
[stressData,stressRef] = inputs(t,dt,v,dropped,W);
stress = run_case(model,stressData,stressRef,t);
assert(nominal.startup_rejected && nominal.explicit_overrange_frames>0);
assert(stress.expired_valid_packet_frames > 0);
% 与 NumPy 按相同半开时间窗核对有效覆盖、空窗和角斜率误差。
np = jsondecode(fileread(numpy_file)); a = np.rows;
ix = strcmp({a.mode},traj.mode) & strcmp({a.run_id},r(1).run_id) & [a.rate_mrad_s]==0.3;
assert(nnz(ix)==1);
expected = a(ix).methods.estimated;
assert(abs(expected.frame_coverage-nominal.good_frames/numel(t)) <= 0.51e-6);
assert(isequaln(isnan(nominal.half_s_errors),isnan(expected.half_s_errors(:))));
mask = isfinite(nominal.half_s_errors);
assert(any(mask));
delta = max(abs(expected.half_s_errors(mask)-nominal.half_s_errors(mask)));
assert(delta < 1e-7);
receipt = struct('scope',"native held reference, quality gate and bias replay; diagnostic angle across gaps", ...
    'plant_file',traj.file,'witness_id',r(1).run_id,'dt_s',dt,'nominal',nominal,'drop_two_packets',stress, ...
    'max_half_window_error_vs_numpy_mrad_s',delta);
fid=fopen(fullfile(folder,'native_reference_replay.json'),'w','n','UTF-8'); assert(fid>=0);
closer = onCleanup(@() fclose(fid));
fprintf(fid,'%s\n',jsonencode(receipt,'PrettyPrint',true));
end

function [data,ref] = inputs(t,dt,v,r,W)
% 输入仅在真实到达时产生一个新包脉冲。在输出前一帧到当帧间到达的新包从当帧生效。
n=numel(t); packet=zeros(n,4);
freq=zeros(n,1); good=false(n,1); stale=good; over=good;
for i=1:numel(r)
    lo=find(t+1e-12 >= r(i).t_s,1);
    if isempty(lo), continue, end
    if i<numel(r), hi=find(t+1e-12 >= r(i+1).t_s,1); else, hi=[]; end
    if isempty(hi), hi=n+1; end
    vals=r(i).split_est_mHz; finite=isscalar(vals) && isfinite(vals);
    if ~finite, vals=0; end
    valid=r(i).valid && finite;
    packet(lo,:)=[1 vals valid r(i).valid_until_s];
    ix=lo:hi-1;
    fresh=t(ix)<r(i).valid_until_s-1e-12;
    good(ix)=valid & fresh & abs(vals)<=50;
    stale(ix)=valid & ~fresh & abs(vals)<=50;
    over(ix)=valid & fresh & abs(vals)>50;
    freq(ix)=vals*good(ix);
end
z=v(:,1); h=[ones(n,1) cos(z) sin(z) cos(2*z) sin(2*z)];
b0=h*W(:,1); d=h*(W(:,2)-W(:,1)); bias=b0+d.*(freq/50).^2;
integ=[0;cumsum(bias(1:end-1))*dt];
data=[t v packet]; ref=[good bias integ v(:,2)-integ stale over];
end

function score = run_case(model,data,ref,t)
in=Simulink.SimulationInput(model);
in=in.setVariable('replayData',data,'Workspace',model);
out=sim(in); y=out.referenceTrace;
assert(isequal(size(y),[numel(t),4]));
maxima=max(abs(y-ref(:,1:4)),[],1);
assert(maxima(1)==0 && all(maxima(2:4)<1e-11));
errors=nan(40,1);
dt=t(2);
for k=1:40
    ix=round((k-1)*0.5/dt)+1:round(k*0.5/dt);
    if all(y(ix,1))
        x=t(ix)-mean(t(ix)); ang=y(ix,4)-mean(y(ix,4));
        errors(k)=1000*(x'*ang)/(x'*x)-0.3;
    end
end
score=struct('frames',numel(t),'good_frames',nnz(y(:,1)), ...
    'maximum_gate_rate_integral_angle_differences',maxima, ...
    'startup_rejected',all(y(t<0.5,1)==0), ...
    'expired_valid_packet_frames',nnz(ref(:,5)),'explicit_overrange_frames',nnz(ref(:,6)), ...
    'half_s_errors',errors);
end

function build(m,folder,data,W,dt)
load_system('simulink'); new_system(m);
set_param(m,'SolverType','Fixed-step','Solver','FixedStepDiscrete','FixedStep','frameDt', ...
    'StopTime','(size(replayData,1)-1)*frameDt','ReturnWorkspaceOutputs','on');
ws=get_param(m,'ModelWorkspace');
ws.assignin('frameDt',dt); ws.assignin('replayData',data); ws.assignin('weights',W);
add('Input frames','Sources/From Workspace','VariableName','replayData','Interpolate','off', ...
    'OutputAfterFinalValue','Holding final value','SampleTime','frameDt');
add('Channels','Signal Routing/Demux','Outputs','6'); wire('Input frames',1,'Channels',1);
% 频差、有效位和失效时刻由同一个到达脉冲载入，未到包时维持上一次状态。
for i=1:3
    names={'Frequency','PacketValid','Expiry'}; name=names{i}; hold=[name ' register'];
    add(hold,'Discrete/Unit Delay','SampleTime','frameDt','InitialCondition','0');
    add(name,'Signal Routing/Switch','Criteria','u2 >= Threshold','Threshold','0.5');
    wire('Channels',i+3,name,1); wire('Channels',3,name,2); wire(hold,1,name,3); wire(name,1,hold,1);
end
add('Abs frequency','Math Operations/Abs'); wire('Frequency',1,'Abs frequency',1);
add('Limit','Sources/Constant','Value','50'); add('In range','Logic and Bit Operations/Relational Operator','Operator','<=');
wire('Abs frequency',1,'In range',1); wire('Limit',1,'In range',2);
add('Clock','Sources/Digital Clock','SampleTime','frameDt');
add('Expiry tolerance','Math Operations/Bias','Bias','-1e-12'); wire('Expiry',1,'Expiry tolerance',1);
add('Fresh','Logic and Bit Operations/Relational Operator','Operator','<');
wire('Clock',1,'Fresh',1); wire('Expiry tolerance',1,'Fresh',2);
add('Can use','Logic and Bit Operations/Logical Operator','Operator','AND','Inputs','3');
wire('Fresh',1,'Can use',1); wire('In range',1,'Can use',2); wire('PacketValid',1,'Can use',3);
add('Gate double','Signal Attributes/Data Type Conversion','OutDataTypeStr','double'); wire('Can use',1,'Gate double',1);
add('Zero','Sources/Constant','Value','0'); add('Use frequency','Signal Routing/Switch','Threshold','0.5');
wire('Frequency',1,'Use frequency',1); wire('Can use',1,'Use frequency',2); wire('Zero',1,'Use frequency',3);
gain('Normalize','1/50'); wire('Use frequency',1,'Normalize',1);
add('Fraction squared','Math Operations/Math Function','Operator','square'); wire('Normalize',1,'Fraction squared',1);
% 四倍驻波角 z 直接来自闭环观测。0/50mHz 冻结端点给出每帧机体等效漂移 rad/s。
gain('Twice z','2'); wire('Channels',1,'Twice z',1);
add('One','Sources/Constant','Value','1'); add('Harmonics','Signal Routing/Mux','Inputs','5');
wire('One',1,'Harmonics',1);
names={'cos z','sin z','cos 2z','sin 2z'}; op={'cos','sin','cos','sin'};
for i=1:4
    n=names{i}; add(n,'Math Operations/Trigonometric Function','Operator',op{i});
    if i<=2, wire('Channels',1,n,1); else, wire('Twice z',1,n,1); end
    wire(n,1,'Harmonics',i+1);
end
gain('Base drift','weights(:,1)'''); gain('Endpoint difference','(weights(:,2)-weights(:,1))''');
wire('Harmonics',1,'Base drift',1); wire('Harmonics',1,'Endpoint difference',1);
add('Interpolated delta','Math Operations/Product'); wire('Endpoint difference',1,'Interpolated delta',1); wire('Fraction squared',1,'Interpolated delta',2);
add('Bias rate','Math Operations/Sum','Inputs','++'); wire('Base drift',1,'Bias rate',1); wire('Interpolated delta',1,'Bias rate',2);
% 积分仅用先前帧，上电为零。缺口中输出角只供诊断，外部评分须整窗有效。
gain('Frame increment','frameDt'); wire('Bias rate',1,'Frame increment',1);
add('Accumulated drift','Discrete/Unit Delay','SampleTime','frameDt','InitialCondition','0');
add('Next drift','Math Operations/Sum','Inputs','++'); wire('Accumulated drift',1,'Next drift',1);
wire('Frame increment',1,'Next drift',2); wire('Next drift',1,'Accumulated drift',1);
add('Diagnostic angle','Math Operations/Sum','Inputs','+-'); wire('Channels',2,'Diagnostic angle',1); wire('Accumulated drift',1,'Diagnostic angle',2);
add('Scoreboard','Signal Routing/Mux','Inputs','4');
ns={'Gate double','Bias rate','Accumulated drift','Diagnostic angle'};
for i=1:4, wire(ns{i},1,'Scoreboard',i); end
add('Trace','Sinks/To Workspace','VariableName','referenceTrace','SaveFormat','Array','MaxDataPoints','inf');
wire('Scoreboard',1,'Trace',1);
add('View','Sinks/Scope'); wire('Scoreboard',1,'View',1);
Simulink.BlockDiagram.arrangeSystem(m);
note=Simulink.Annotation(m,'测频读数回放。Scoreboard 输出依次为有效位、漂移速率 rad/s、累计漂移 rad、诊断角 rad。整窗有效才评分。');
note.Position=[10 -90 790 -32];
set_param([m '/Channels'],'Description','依次为四倍驻波角、原机体角、新包事件、频差 mHz、包有效位、到期绝对时刻 s。');
set_param([m '/Can use'],'Description','包有效、未到期且频差不超过 50 mHz 时允许使用；上电和新无效包立即拒绝。');
set_param([m '/Diagnostic angle'],'Description','仅整段有效区间的相对角或局部斜率可评分。跨缺口绝对角连续性未经验证。');
save_system(m,fullfile(folder,[m '.slx']));
    function add(n,path,varargin), add_block(['simulink/' path],[m '/' n],varargin{:}); end
    function gain(n,g), add(n,'Math Operations/Gain','Gain',g,'Multiplication','Matrix(K*u)'); end
    function wire(a,i,b,j), add_line(m,sprintf('%s/%d',a,i),sprintf('%s/%d',b,j),'autorouting','on'); end
end
