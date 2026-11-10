function five_instrument_model(model)
% 为两个五电极原生模型添加中文导览、节点记录和旁路记分板。
% 各监测支路只读原信号，不参与控制或表头状态更新。

plant = [model '/Four electrode groups and COM'];
converters = [model '/Converters'];
timing = [model '/Timing'];
alignment = [model '/ADC sample alignment'];
demod = [model '/Coherent demodulation'];
control = [model '/Amplitude and quadrature'];
angle = [model '/Whole angle'];
trace = [model '/Trace'];
c = getVariable(get_param(model,'ModelWorkspace'),'c');

% 在原生节点的输出端记录完整波形，并沿用原来的 trace 和 frames。
% Dataset 自带时间轴，可直接在 Simulation Data Inspector 中分组比较。
set_param(model,'SignalLogging','on','SignalLoggingName','logsout');
ports = {
    timing, 2, 'timing_drive'
    timing, 3, 'timing_sense'
    timing, 4, 'timing_valid'
    alignment, 2, 'capture_aligned'
    plant, 1, 'afe_xy_V'
    plant, 2, 'motion_charge'
    plant, 4, 'terminal_voltage_V'
    [plant '/Filtered equivalent CV input'], 1, 'cv_input_filtered'
    [plant '/THX2024 matched CV gain'], 1, 'cv_output_V'
    [converters '/ADC input and noise'], 1, 'adc_input_V'
    converters, 1, 'dac_output_V'
    converters, 2, 'adc_output_V'
    converters, 3, 'adc_clip'
    converters, 4, 'dac_clip'
    [demod '/Mixed IQ'], 1, 'iq_mixed'
    [demod '/IQ and channel calibration'], 1, 'iq_calibrated'
    demod, 2, 'frame_usable'
    demod, 4, 'energy'
    control, 1, 'control_command'
    angle, 2, 'frame_pulse'
    angle, 3, 'angle_rad'
    angle, 4, 'angle_valid'
    angle, 5, 'tracking_lost'
    };
for k = 1:size(ports,1)
    handles = get_param(ports{k,1},'PortHandles');
    set_param(handles.Outport(ports{k,2}),'DataLogging','on', ...
        'DataLoggingNameMode','Custom','DataLoggingName',ports{k,3});
end

% 说明放在各子系统画布上方。独立回放不同模型时仍可辨认量纲和判据。
if c.reuse
    mode = '分时复用：驱动 → 泄放 → 检测建立 → 有效采样 → 保护';
    routing = '驱动 A/C 与 B/D 成对反相，检测以半差形成 X/Y。';
    timingNote = '分时检测连接早于有效采样，先留出 C/V 建立窗。';
else
    mode = '连续驱检：A/B 固定驱动，C/D 固定检测';
    routing = 'A/B 驱动 X/Y，C/D 的独立 C/V 经极性校准输出 X/Y。';
    timingNote = '连续版每个载波周期发布一帧，两路在同一时间基准上采样。';
end
addNote(model,{'五电极压电全角行为模型',mode, ...
    '运行后打开 Data Inspector 查看命名波形，双击 Scoreboard monitor 看本次计数。', ...
    '详细 MATLAB/Simulink 对照与误差评分使用 five_inspect。'});
addNote(timing,{timingNote,'timing_valid 为 ADC 采样窗口，捕获脉冲位于有效窗末拍。'});
addNote([model '/Carrier'],{'载波源同时产生 cos 和 sin，供调制与相干解调共用。'});
addNote(alignment,{'流水延迟对齐槽号、捕获脉冲和载波相位，解调使用 ADC 对应采样时刻。'});
addNote(converters,{'DAC 输出是 X/Y 驱动电压指令，ADC 输出是量化并经流水延迟后的等效电压。', ...
    'adc_input_V 在 ADC 量化前，包含配置的噪声。adc_clip 和 dac_clip 分别观察。'});
addNote(plant,{routing, ...
    'terminal_voltage_V 顺序为 A/B/C/D 对 COM；COM 是理想模型参考。', ...
    'cv_output_V 为 thx2024 等效增益输出，afe_xy_V 为组合后的双路 ADC 模拟输入。'});
addNote(demod,{'iq_mixed 是逐拍载波乘积；iq_calibrated 是窗内累加后的候选值。', ...
    '按对齐捕获脉冲与 frame_usable 判断帧末的有效候选。'});
addNote(control,{'使用幅值与正交误差生成驱动力系数；只有接受的帧更新控制命令。'});
addNote(angle,{'参考帧建立后累计机体角度 rad；跟踪丢失时 angle_valid 清零。', ...
    'angle_rad 在更新帧之间保持，评分以 frame_pulse 的时间戳为准。'});
addNote(trace,{'trace 为采样记录，按配置抽取；frames 为逐帧发布记录，首列是时间 s。', ...
    '观察载波请使用命名的全采样率节点日志。'});
addMonitor(model);
end

function addNote(system, lines)
% 以直属模块包围框为基准留出标题区域，避免文字遮盖信号线。
blocks = find_system(system,'SearchDepth',1,'Type','Block');
positions = get_param(blocks,'Position');
positions = vertcat(positions{:});
left = min(positions(:,1));
height = 22*numel(lines)+10;
top = min(positions(:,2))-height-20;
note = Simulink.Annotation(system,strjoin(lines,newline));
note.FontSize = 12;
note.BackgroundColor = 'lightBlue';
note.Position = [left top left+680 top+height];
end

function addMonitor(model)
% 用原生块累计逻辑事件，只统计采样拍与发布帧，不回写任何控制量。
name = 'Scoreboard monitor';
system = [model '/' name];
tracePosition = get_param([model '/Trace'],'Position');
xy = tracePosition(3:4) + [95 45];
add_block('built-in/Subsystem',system,'Position',[xy xy+[170 130]]);
channels = {
    'ADC clipping samples','Converters/3','ADC 越界采样拍数'
    'DAC clipping samples','Converters/4','DAC 限幅采样拍数'
    'Published frames','Whole angle/2','已发布帧数'
    'Angle valid','Whole angle/4','角度有效'
    'Tracking lost','Whole angle/5','跟踪丢失'
    'Held angle rad','Whole angle/3','最近发布角度 rad'
    };
for k = 1:size(channels,1)
    key = channels{k,1};
    y = 35 + 85*(k-1);
    add_block('built-in/Inport',[system '/' key], ...
        'Port',num2str(k),'Position',[25 y+3 55 y+17]);
    add_line(model,channels{k,2},sprintf('%s/%d',name,k),'autorouting','on');
    source = key;
    if k <= 3
        % 输入脉冲取 0 或 1。记忆保存前一拍总数，显示包含当前拍。
        data = [key ' as number'];
        state = [key ' previous'];
        total = [key ' total'];
        add_block('simulink/Signal Attributes/Data Type Conversion',[system '/' data], ...
            'OutDataTypeStr','double','Position',[105 y-3 155 y+23],'ShowName','off');
        add_block('simulink/Math Operations/Sum',[system '/' total], ...
            'Inputs','++','Position',[205 y-4 229 y+24],'ShowName','off');
        add_block('simulink/Discrete/Unit Delay',[system '/' state], ...
            'InitialCondition','0','SampleTime','c.Ts', ...
            'Position',[245 y+32 275 y+54],'Orientation','left','ShowName','off');
        add_line(system,[key '/1'],[data '/1'],'autorouting','on');
        add_line(system,[data '/1'],[total '/1'],'autorouting','on');
        add_line(system,[total '/1'],[state '/1'],'autorouting','on');
        add_line(system,[state '/1'],[total '/2'],'autorouting','on');
        source = total;
    end
    add_block('simulink/Sinks/Display',[system '/' channels{k,3}], ...
        'Position',[320 y-5 425 y+25]);
    add_line(system,[source '/1'],[channels{k,3} '/1'],'autorouting','on');
end
addNote(system,{'原生仿真记分板：一拍限幅计一次，跨通道合并标志。', ...
    '观察帧数、角度有效与失锁；角度跟踪误差与频谱用 five_inspect 分析。'});
end
