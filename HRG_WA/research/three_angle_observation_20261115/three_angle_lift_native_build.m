function model=three_angle_lift_native_build(c,L,folder,source)
% 原生帧级模型：Gain/Sum/UnitDelay 实现提升矩阵；直接复制已有原生AGC/正交控制子系统。
% 不封装 MATLAB 函数，不从工作区回放波形；只读矩阵参数存于模型工作区。
model=['hrg_lift_' c.mode];if bdIsLoaded(model),close_system(model,0);end
new_system(model); cleanup=onCleanup(@() close_system(model,0)); %#ok<NASGU>
assignin(get_param(model,'ModelWorkspace'),'c',c);assignin(get_param(model,'ModelWorkspace'),'L',L);
set_param(model,'Solver','FixedStepDiscrete','SolverType','Fixed-step','FixedStep','L.T', ...
    'StopTime','(floor(c.duration/L.T+1e-9)-1)*L.T','ReturnWorkspaceOutputs','on');
add('State','Discrete/Unit Delay','InitialCondition','c.x0');
add('Fx','Math Operations/Gain','Gain','L.F','Multiplication','Matrix(K*u)');
add('Gu','Math Operations/Gain','Gain','L.G','Multiplication','Matrix(K*u)');
add('Next state','Math Operations/Sum','Inputs','++');
add('Hc','Math Operations/Gain','Gain','L.Hc','Multiplication','Matrix(K*u)');
add('Jc','Math Operations/Gain','Gain','L.Jc','Multiplication','Matrix(K*u)');
add('Estimate','Math Operations/Sum','Inputs','++');
add('Hm','Math Operations/Gain','Gain','L.Hm','Multiplication','Matrix(K*u)');
add('Jm','Math Operations/Gain','Gain','L.Jm','Multiplication','Matrix(K*u)');
add('Mechanical IQ','Math Operations/Sum','Inputs','++');
add('Energy','Math Operations/Dot Product');
add('Capture','Sources/Constant','Value','true','OutDataTypeStr','boolean');
% 本首版原生提升模型仅验收全帧有效轨迹；失锁/门控逻辑仍用逐拍模型作为依据。
add_block([source '/Amplitude and quadrature'],[model '/Control']);
% 原子系统的命令寄存器显式使用ADC时钟，提升后必须改为每帧更新一次。
set_param([model '/Control/Last DAC command'],'SampleTime','L.T');
add('Trace','Signal Routing/Mux','Inputs','4');
add('Export','Sinks/To Workspace','VariableName','liftTrace','SaveFormat','Array','MaxDataPoints','inf');
line('State/1','Fx/1');line('Fx/1','Next state/1');line('Control/1','Gu/1');line('Gu/1','Next state/2');line('Next state/1','State/1');
line('State/1','Hc/1');line('Control/1','Jc/1');line('Hc/1','Estimate/1');line('Jc/1','Estimate/2');
line('State/1','Hm/1');line('Control/1','Jm/1');line('Hm/1','Mechanical IQ/1');line('Jm/1','Mechanical IQ/2');
line('Estimate/1','Energy/1');line('Estimate/1','Energy/2');
line('Estimate/1','Control/1');line('Energy/1','Control/2');line('Capture/1','Control/3');line('Capture/1','Control/4');
line('State/1','Trace/1');line('Control/1','Trace/2');line('Estimate/1','Trace/3');line('Mechanical IQ/1','Trace/4');line('Trace/1','Export/1');
Simulink.Annotation(model,'帧级无量化研究模型：保留机电/CV状态；Capture/Accept恒真，仅用于全帧有效工况。');
Simulink.BlockDiagram.arrangeSystem(model);
if ~isfolder(folder),mkdir(folder);end
save_system(model,fullfile(folder,[model '.slx']));
    function add(name,lib,varargin),add_block(['simulink/' lib],[model '/' name],varargin{:});end
    function line(a,b),add_line(model,a,b,'autorouting','on');end
end
