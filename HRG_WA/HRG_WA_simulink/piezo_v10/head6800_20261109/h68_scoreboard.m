function report = h68_scoreboard(c, t, trace, frames, opts)
% 6800 Hz 计分板。基线用 22 列 trace，五电极用 26 列 trace，发布帧另有时间列。
% 样本级判据使用实际记录时刻反推采样拍；抽取记录只给观测结论。
arguments
    c (1,1) struct
    t (:,1) double
    trace (:,:) double
    frames (:,:) double
    opts.SettleTime_s (1,1) double {mustBeNonnegative} = 0.1
    opts.MinimumFrames (1,1) double {mustBeInteger,mustBePositive} = 101
    opts.AngleRmsLimit_rad (1,1) double {mustBePositive} = 0.015
    opts.AmplitudeBounds (1,2) double {mustBePositive} = [0.8 1.2]
end
hasGroups = isfield(c,'groupVoltage');
width = 22 + 4*hasGroups;
assert(size(trace,2)==width && size(frames,2)==width+1, ...
    '当前配置要求 trace 有 %d 列、frames 有 %d 列。',width,width+1);
assert(size(trace,1)==numel(t), 'trace 与时间轴的行数必须一致。');
assert(opts.AmplitudeBounds(1)<opts.AmplitudeBounds(2), '振幅上下界必须递增。');

checks = strings(0,3);
report = struct('mode',c.mode,'duration_s',c.duration,'input_rate_rad_s',c.omega, ...
    'adc_rate_Hz',1/c.Ts,'dac_rate_Hz',1/(c.Ts*c.p.dac_divisor), ...
    'frame_rate_Hz',1/(c.Ts*c.frame),'settle_time_s',opts.SettleTime_s);
finiteData = all(isfinite(t)) && all(isfinite(trace),'all') && all(isfinite(frames),'all');
addCheck("数据有限且存在",~isempty(t) && finiteData, ...
    sprintf('%d 个记录样本，%d 个发布帧',numel(t),size(frames,1)));

% 以物理采样拍对齐开关、流水 ADC 和帧发布事件。
tick = round(t/c.Ts);
fullRate = ~isempty(t) && tick(1)==0 && all(diff(tick)==1) && ...
    tick(end)==round(c.duration/c.Ts);
timeAligned = ~isempty(t) && all(abs(t/c.Ts-tick)<1e-6) && all(diff(tick)>0);
report.full_rate_capture = fullRate && timeAligned;
addCheck("采样时间轴",timeAligned,sprintf('配置记录抽取 %d，完整记录 %d',c.logDecimation,fullRate));
slot = mod(tick,c.frame);
drive = trace(:,2)~=0;
sense = trace(:,3)~=0;
valid = trace(:,4)~=0;
windowOK = isequal(trace(:,1),slot) && isequal(drive,slot<c.driveEnd) && ...
    isequal(sense,slot>=c.senseStart & slot<c.validEnd) && ...
    isequal(valid,sense & slot>=c.validStart);
addCheck("驱动、检测、有效窗",timeAligned && windowOK, ...
    sprintf('有效窗 [%d, %d)，帧长 %d 拍',c.validStart,c.validEnd,c.frame));
if c.continuous
    addCheck("连续驱检",~isempty(t) && all(drive & sense & valid),"每拍同时驱动和检测");
else
    addCheck("分时驱检隔离",~isempty(t) && ~any(drive & sense),"驱动与检测窗口互斥");
end
sourceSlot = mod(tick-c.adcLatency,c.frame);
adcPresent = tick>=c.adcLatency & sourceSlot>=c.validStart & sourceSlot<c.validEnd;
quiet = ~any(trace(~adcPresent,5:6),'all') && ~any(trace(~adcPresent,20));
dacQuiet = ~any(trace(~drive,7:8),'all');
published = round(frames(:,1)/c.Ts);
publishPhase = mod(c.validEnd+c.adcLatency,c.frame);
frameTimesAligned = all(abs(frames(:,1)/c.Ts-published)<1e-6) && ...
    all(mod(published,c.frame)==publishPhase);
addCheck("ADC 流水线与 DAC 门控",timeAligned && quiet && dacQuiet, ...
    sprintf('ADC 延迟 %d 拍',c.adcLatency));
if isempty(published)
    addRow("发布拍位置","SKIP","无可检查的发布帧");
else
    addCheck("发布拍位置",frameTimesAligned && all(frames(:,10)==1), ...
        sprintf('每帧第 %d 拍发布（从 0 计）',publishPhase));
end

% 转换器量程和故障。对于抽取记录，不能用零计数证明未触发过载。
report.adc_peak_V = peaks(trace(:,5:6));
report.dac_peak_V = peaks(trace(:,7:8));
if hasGroups
    report.terminal_peak_V = peaks(trace(:,23:26));
else
    report.sense_electrode_peak_V = peaks(trace(:,18:19));
end
report.adc_utilization = report.adc_peak_V/(c.p.adc_span/2);
report.dac_utilization = report.dac_peak_V/(c.p.dac_span/2);
adcCodes = trace(:,5:6)/c.adcStep;
dacCodes = trace(:,7:8)/c.dacStep;
addCheck("转换器码格与范围",~isempty(t) && ...
    all(abs(adcCodes-round(adcCodes))<1e-7,'all') && ...
    all(abs(dacCodes-round(dacCodes))<1e-7,'all') && ...
    all(trace(:,5:6)>=c.adcMin & trace(:,5:6)<=c.adcMax,'all') && ...
    all(trace(:,7:8)>=c.dacMin & trace(:,7:8)<=c.dacMax,'all'), ...
    sprintf('ADC %d 位，DAC %d 位',c.p.adc_bits,c.p.dac_bits));
after = t>=opts.SettleTime_s;
report.observed_adc_clip_samples = nnz(trace(:,20));
report.observed_dac_clip_before_score = nnz(trace(~after,22));
report.observed_dac_clip_during_score = nnz(trace(after,22));
report.observed_tracking_lost_samples = nnz(trace(:,21));
faultCheck("ADC 过载",report.observed_adc_clip_samples,"全程");
faultCheck("跟踪丢失",report.observed_tracking_lost_samples,"全程");
faultCheck("评分窗 DAC 限幅",report.observed_dac_clip_during_score,"评分窗");
if report.observed_dac_clip_before_score>0
    addRow("评分前 DAC 限幅","WARN",sprintf('观察到 %d 拍，核对限幅恢复', ...
        report.observed_dac_clip_before_score));
else
    faultCheck("评分前 DAC 限幅",0,"评分前");
end

% 角度以同一有效帧为起点。振幅由已校准、已接受的 I/Q 分量计算。
report.first_valid_s = NaN;
if ~isempty(frames)
    report.first_valid_s = frames(1,1);
end
f = frames(frames(:,1)>=opts.SettleTime_s,:);
report.scored_frames = size(f,1);
report.angle_rms_rad = NaN;
report.angle_peak_rad = NaN;
report.angle_slope_rad_s = NaN;
report.amplitude_range = [NaN NaN];
scoreEnough = report.scored_frames>=max(2,opts.MinimumFrames);
if scoreEnough
    dt = f(:,1)-f(1,1);
    relativeAngle = f(:,15)-f(1,15);
    errorAngle = relativeAngle-c.omega*dt;
    amplitude = sqrt(sum(f(:,11:14).^2,2));
    report.angle_rms_rad = sqrt(mean(errorAngle.^2));
    report.angle_peak_rad = max(abs(errorAngle));
    if all(isfinite(dt)) && all(diff(dt)>0) && all(isfinite(relativeAngle))
        fit = polyfit(dt,relativeAngle,1);
        report.angle_slope_rad_s = fit(1);
    end
    report.amplitude_range = [min(amplitude) max(amplitude)];
    frameOK = all(f(:,16)==1) && all(diff(round(f(:,1)/c.Ts))==c.frame);
    % 最后一帧附近也应覆盖仿真终点，避免中途停止发布却通过。
    tail = c.duration-f(end,1);
    frameOK = frameOK && tail>=-c.Ts/2 && tail<=(c.frame+1)*c.Ts;
    addCheck("有效帧连续",frameOK,sprintf('%d 帧，末帧距终点 %.3g s',size(f,1),tail));
    addCheck("角增量 RMS",report.angle_rms_rad<opts.AngleRmsLimit_rad, ...
        sprintf('%.6g rad，限值 %.6g rad',report.angle_rms_rad,opts.AngleRmsLimit_rad));
    addCheck("归一化振幅",all(report.amplitude_range>opts.AmplitudeBounds(1)) && ...
        all(report.amplitude_range<opts.AmplitudeBounds(2)), ...
        sprintf('%.6g 至 %.6g，限值 %.3g 至 %.3g',report.amplitude_range,opts.AmplitudeBounds));
else
    addRow("全角、有效帧、振幅","SKIP",sprintf('评分帧 %d，至少需要 %d', ...
        size(f,1),max(2,opts.MinimumFrames)));
end

report.checks = array2table(checks,'VariableNames',{'Node','Result','Detail'});
if any(checks(:,2)=="FAIL")
    report.status = "FAIL";
elseif any(checks(:,2)=="SKIP")
    report.status = "INCOMPLETE";
elseif any(checks(:,2)=="WARN")
    report.status = "PASS_WITH_WARNING";
else
    report.status = "PASS";
end
report.passed = report.status=="PASS" || report.status=="PASS_WITH_WARNING";

    function addCheck(name,pass,detail)
        if pass
            addRow(name,"PASS",detail);
        else
            addRow(name,"FAIL",detail);
        end
    end

    function addRow(name,result,detail)
        checks(end+1,:) = [name,result,string(detail)];
    end

    function faultCheck(name,count,window)
        if count>0
            addCheck(name,false,sprintf('%s观察到 %d 拍',window,count));
        elseif ~report.full_rate_capture
            addRow(name,"SKIP",window+"抽取记录未观察到，未覆盖全部采样拍");
        elseif window=="评分窗" && ~any(after)
            addRow(name,"SKIP","仿真未覆盖评分窗");
        else
            addCheck(name,true,window+"未观察到");
        end
    end
end

function value = peaks(x)
% 空记录保留通道数，供计分板显示暂无数据。
if isempty(x)
    value = nan(1,size(x,2));
else
    value = max(abs(x),[],1);
end
end
