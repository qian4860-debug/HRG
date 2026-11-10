function [report, data] = five_inspect(mode, engine, omega, overrides, opts)
% 运行五电极 MATLAB 或原生 Simulink，打开计分板、关键节点和闭环趋势。
% 示例：five_inspect('continuous','simulink')；无窗口回归请用 Plots=false。
arguments
    mode (1,:) char {mustBeMember(mode,{'continuous','tdm_shared'})} = 'continuous'
    engine (1,:) char {mustBeMember(engine,{'matlab','simulink'})} = 'matlab'
    omega (1,1) double {mustBeFinite} = 0.5
    overrides (1,1) struct = struct()
    opts.Plots (1,1) logical = true
    opts.SettleTime_s (1,1) double = NaN
    opts.MinimumFrames (1,1) double {mustBeInteger,mustBePositive} = 101
    opts.AngleRmsLimit_rad (1,1) double {mustBePositive} = 0.015
    opts.AmplitudeBounds (1,2) double {mustBePositive} = [0.8 1.2]
    opts.WaveWindow_s (1,2) double {mustBeFinite,mustBeNonnegative} = [0 .002]
end
assert(opts.WaveWindow_s(1)<opts.WaveWindow_s(2),'波形窗的起止时间必须递增。');
if ~isfield(overrides,'duration'), overrides.duration = 0.18; end
if ~isfield(overrides,'log_decimation'), overrides.log_decimation = 1; end
c = five_config(mode,omega,overrides);
settle = opts.SettleTime_s;
if isnan(settle)
    settle = 0.06;
    if c.p.seed_enabled && c.p.initial_fraction==0, settle = 0.35; end
end

% 两引擎保持独立。Simulink 从已生成的 SLX 运行，并临时注入模型工作区。
data = struct('c',c,'t',[],'trace',[],'frames',[],'adcMonitor',[],'logsout',[]);
if strcmp(engine,'matlab')
    if opts.Plots || nargout>1
        [data.t,data.trace,data.frames,data.adcMonitor] = five_reference(c);
    else
        [data.t,data.trace,data.frames] = five_reference(c);
    end
else
    name = ['hrg_5e_' mode '_inspect'];
    modelPath = fullfile(fileparts(mfilename('fullpath')),'models',[name '.slx']);
    assert(isfile(modelPath), '缺少观察版模型 %s，请检查仓库中的模型文件。',modelPath);
    if ~bdIsLoaded(name)
        load_system(modelPath);
    end
    assert(strcmpi(get_param(name,'FileName'),modelPath), ...
        '已加载同名模型，但路径与本工程不一致：%s',get_param(name,'FileName'));
    in = Simulink.SimulationInput(name);
    in = in.setVariable('c',c,'Workspace',name);
    in = in.setModelParameter('SaveTime','off');
    out = sim(in);
    data.trace = out.trace;
    data.frames = out.frames;
    data.t = (0:size(out.trace,1)-1)'*(c.logDecimation*c.Ts);
    if any(strcmp(who(out),'logsout'))
        data.logsout = out.logsout;
    end
end

% 验收输出按同一时间轴和判据计算，控制台适合批跑，窗口适合定位问题。
report = five_scoreboard(c,data.t,data.trace,data.frames, ...
    SettleTime_s=settle,MinimumFrames=opts.MinimumFrames, ...
    AngleRmsLimit_rad=opts.AngleRmsLimit_rad,AmplitudeBounds=opts.AmplitudeBounds);
report.engine = engine;
fprintf('\n五电极计分板 | %s | %s | %s\n',engine,mode,report.status);
fprintf('输入 %.6g rad/s，ADC %.6g S/s，DAC %.6g S/s，帧率 %.6g Hz\n', ...
    omega,report.adc_rate_Hz,report.dac_rate_Hz,report.frame_rate_Hz);
disp(report.checks);
if opts.Plots
    drawBoard(report);
    drawWaveforms(data,opts.WaveWindow_s);
    drawFrames(data,settle);
end
end

function drawBoard(r)
% 用可滚动表格直显判据结果、量化指标和警告。
name = sprintf('五电极计分板 | %s | %s',r.engine,r.mode);
f = figure('Name',name,'NumberTitle','off','Position',[90 150 840 505]);
annotation(f,'textbox',[.025 .83 .95 .15], 'EdgeColor','none', ...
    'Interpreter','none','String',{sprintf('%s | %s',name,r.status), ...
    sprintf('角 RMS %.4g rad，斜率 %.6g rad/s，首次有效 %.4g s', ...
    r.angle_rms_rad,r.angle_slope_rad_s,r.first_valid_s), ...
    sprintf('ADC 占用率 X/Y %.2f%% / %.2f%%，DAC 峰值 X/Y %.4g / %.4g V', ...
    100*r.adc_utilization(1),100*r.adc_utilization(2),r.dac_peak_V(1),r.dac_peak_V(2))});
uitable(f,'Units','normalized','Position',[.025 .035 .95 .77], ...
    'Data',cellstr(table2array(r.checks)),'ColumnName',{'节点与判据','结果','测量值和条件'}, ...
    'ColumnWidth',{185 115 470},'RowName',[]);
end

function drawWaveforms(d,window)
% 载波视图保留采样拍细节，用短时间窗分开幅度和布尔标志。
take = d.t>=window(1) & d.t<=window(2);
if ~any(take)
    warning('五电极波形窗没有记录样本。');
    return
end
t = d.t(take)*1e3;
x = d.trace(take,:);
figure('Name','五电极关键节点 | 载波时间尺度','NumberTitle','off');
tiles = tiledlayout(3,2,'TileSpacing','compact');
ax = gobjects(6,1);
ax(1) = nexttile; plot(t,x(:,7:8)); title('DAC 输出 (V)'); grid on
legend('X','Y');
ax(2) = nexttile; plot(t,x(:,23:26)); title('电极端相对 COM (V)'); grid on
legend('A','B','C','D');
ax(3) = nexttile;
if ~isempty(d.adcMonitor)
    monitor = d.adcMonitor;
    mt = monitor(:,1)*d.c.Ts;
    inside = mt>=window(1) & mt<=window(2);
    plot(mt(inside)*1e3,monitor(inside,10:13),'.-');
else
    plotLogged(d.logsout,'cv_output_V',window);
end
title('THX2024 等效 C/V (V)'); grid on; legendIfData(gca,{'A','B','C','D'});

ax(4) = nexttile;
if ~isempty(d.adcMonitor)
    plot(mt(inside)*1e3,monitor(inside,5:6),'.-');
else
    plotLogged(d.logsout,'adc_input_V',window);
end
hold on; plot(t,x(:,5:6),'--');
title('ADC 输入（实线）与量化流水输出（虚线）(V)'); grid on

ax(5) = nexttile; stairs(t,x(:,2:4)+[0 1.2 2.4]); title('驱动、检测和有效采样窗'); grid on
legend('驱动','检测','有效');
ax(6) = nexttile; stairs(t,x(:,[20 22])+[0 1.2]); title('转换器限幅标志'); grid on
legend('ADC','DAC');
linkaxes(ax,'x');
xlabel(tiles,'仿真时间 (ms)');
end

function plotLogged(logs,name,window)
% 已保存的历史模型可能缺少该日志，保留其它波形并提示可用性。
if isempty(logs) || ~any(strcmp(getElementNames(logs),name))
    text(.5,.5,'当前仿真无该节点日志','Units','normalized','HorizontalAlignment','center');
    return
end
signal = getElement(logs,name);
v = signal.Values;
take = find(v.Time>=window(1) & v.Time<=window(2));
if isempty(take)
    return
end
samples = getdatasamples(v,take);
if ~v.IsTimeFirst
    samples = permute(samples,[ndims(samples),1:ndims(samples)-1]);
end
plot(v.Time(take)*1e3,reshape(samples,numel(take),[]));
end

function legendIfData(ax,names)
% 节点没有可用日志时，不额外显示通道图例。
if ~isempty(findobj(ax,'Type','line'))
    legend(ax,names);
end
end

function drawFrames(d,settle)
% 控制视图按发布帧绘图，避免载波压缩后遮挡低速角度趋势。
f = d.frames;
figure('Name','五电极全角闭环 | 发布帧时间尺度','NumberTitle','off');
tiles = tiledlayout(2,2,'TileSpacing','compact');
ax = gobjects(4,1);
ax(1) = nexttile; plot(f(:,1),f(:,11:14)); title('已接受 I/Q'); grid on
legend('I_X','I_Y','Q_X','Q_Y');
ax(2) = nexttile; plot(f(:,1),sqrt(sum(f(:,11:14).^2,2))); title('归一化振幅'); grid on
yline(1,':','目标');
ax(3) = nexttile; plot(f(:,1),f(:,15)); title('机体角度 (rad)'); grid on
xline(settle,':','评分起点');
ax(4) = nexttile;
f = f(f(:,1)>=settle,:);
if ~isempty(f)
    errorAngle = f(:,15)-f(1,15)-d.c.omega*(f(:,1)-f(1,1));
    plot(f(:,1),errorAngle*1e3);
else
    text(.5,.5,'评分窗内暂无有效帧','Units','normalized','HorizontalAlignment','center');
end
title('机体角增量误差 (mrad)'); grid on
linkaxes(ax,'x');
xlabel(tiles,'仿真时间 (s)');
end
