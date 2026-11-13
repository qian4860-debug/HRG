function result = tdm_quantization_study(outPath, opts)
% 五电极 D1 研究。冻结表头、驱检、角锚点和评分帧，比较量化、抖动与真实采样网格。
% 抖动为两路非减法均匀注入，数值单位为 ADC 码宽的 RMS。
arguments
    outPath (1,:) char = ''
    opts.Profile (1,1) string {mustBeMember(opts.Profile,["full","quick"])} = "full"
end
here = fileparts(mfilename('fullpath'));
if isempty(outPath)
    if opts.Profile=="quick"
        outPath = fullfile(here,'quick_verification.json');
    else
        outPath = fullfile(here,'verification.json');
    end
end
addpath(fullfile(here,'..','..','HRG_WA_simulink','piezo_v10','five_electrode_20261110'));
addpath(fullfile(here,'..','five_adc_range_20261110'));
duration = .18;
scoreStart = .06;
rates = [0,.5,-.5,-4];
levels = [0,.10,.20,.30,.50,.75];
seeds = [1103515245 2246822519; 374761393 668265263; 3266489917 2654435761];
if opts.Profile=="quick"
    % 快速入口只回答 +0.5 rad/s 的两档抖动和量程增益，保持完整评分窗。
    rates = .5;
    levels = [0,.30,.50];
end
result = struct('release',version('-release'), ...
    'profile',opts.Profile, ...
    'scope','Five-electrode behavioral closed-loop D1; uniform non-subtractive prequantizer dither', ...
    'duration_s',duration,'score_start_s',scoreStart,'rates_rad_s',rates, ...
    'dither_levels_LSB_rms',levels,'seeds',seeds, ...
    'relative_slope_screen_pct',.1,'primary_adc_and_dac_Hz',5440000, ...
    'primary',[],'levels',[],'grid',[],'gain_control',[],'long_window',[],'nco_only',[],'checks',[]);

% 主对照用报告 34 的 5.44 MSPS ADC/DAC 设置。16 位无抖动只作量化参考。
for rate = rates
    for bits = [10,16]
        result.primary = [result.primary;runCase(rate,bits,0,seeds(1,:),800,1,duration,scoreStart)]; %#ok<AGROW>
    end
    for level = levels(2:end)
        for k = 1:size(seeds,1)
            result.primary = [result.primary;runCase(rate,10,level,seeds(k,:),800,1,duration,scoreStart)]; %#ok<AGROW>
        end
    end
    fprintf('D1 primary %.3g rad/s complete, %d cases\n',rate,numel(result.primary));
end
nominal = result.primary([result.primary.omega_rad_s]==.5 & ...
    [result.primary.adc_bits]==10 & [result.primary.dither_LSB_rms]==0);
assert(abs(nominal.angle_fixed_anchor_rms_rad-.00340527)<1e-8 && ...
    abs(nominal.slope_rad_s-.51117)<1e-5,'10 位名义基线未复现报告 34。');
assert(all([result.primary.missed_scoring_frames]==0));
for level = levels
    a = result.primary([result.primary.adc_bits]==10 & [result.primary.dither_LSB_rms]==level);
    nz = a([a.omega_rad_s]~=0);
    half = a(abs([a.omega_rad_s])==.5);
    stationary = a([a.omega_rad_s]==0);
    stationaryWorst = NaN;
    if ~isempty(stationary), stationaryWorst = max([stationary.angle_centered_rms_rad]); end
    result.levels = [result.levels;struct('dither_LSB_rms',level, ...
        'scored_cases',numel(a),'moving_cases',numel(nz), ...
        'moving_cases_under_0p1_pct',nnz(abs([nz.slope_relative_error_pct])<=.1), ...
        'worst_abs_moving_slope_relative_error_pct',max(abs([nz.slope_relative_error_pct])), ...
        'worst_abs_half_rad_s_slope_relative_error_pct',max(abs([half.slope_relative_error_pct])), ...
        'worst_stationary_angle_centered_rms_rad',stationaryWorst, ...
        'worst_fixed_anchor_angle_rms_rad',max([a.angle_fixed_anchor_rms_rad]), ...
        'worst_centered_angle_rms_rad',max([a.angle_centered_rms_rad]), ...
        'worst_detrended_angle_rms_rad',max([a.angle_detrended_rms_rad]), ...
        'all_moving_rates_and_seeds_meet_slope_screen',all(abs([nz.slope_relative_error_pct])<=.1))]; %#ok<AGROW>
end
for k = 1:numel(result.levels)
    a = result.levels(k);
    fprintf('D1 %.2f LSB RMS: slope screen %d/%d, worst %.5g%%\n', ...
        a.dither_LSB_rms,a.moving_cases_under_0p1_pct,a.moving_cases, ...
        a.worst_abs_moving_slope_relative_error_pct);
end
[~,candidate] = min([result.levels(2:end).worst_abs_moving_slope_relative_error_pct]);
candidate = candidate+1;
selected = levels(candidate);
result.selected_level_LSB_rms = selected;
result.selection_rule = 'Minimum worst absolute slope error over nonzero rates and all three seeds';

% C/V 合成后加增益，标定矩阵按反比例更新。保留 ADC 电压范围与 DAC 配置。
for rate = rates
    for gain = [6,8]
        row = runCase(rate,10,0,seeds(1,:),800,1,duration,scoreStart,gain);
        result.gain_control = [result.gain_control;row]; %#ok<AGROW>
    end
end

% 改变物理状态离散步长、ADC 采样点和 DAC 计时分频。保持 DAC 217.6 kS/s，
% 驱动/泄放/建立/检测时间和控制帧率相同。五个 ADC 流水拍对应的秒数会变。
if opts.Profile=="full"
    for n = [800,832,960]
        for level = [0,selected]
            for k = 1:size(seeds,1)
                if level==0 && k>1, continue; end
                result.grid = [result.grid;runCase(.5,10,level,seeds(k,:),n,n/32,duration,scoreStart)]; %#ok<AGROW>
            end
        end
    end
    % 延长单一工况检查斜率估计对观测长度的影响。锚点仍为 60 ms。
    for level = [0,selected]
        for k = 1:size(seeds,1)
            if level==0 && k>1, continue; end
            result.long_window = [result.long_window;runCase(.5,10,level,seeds(k,:),800,1,.54,scoreStart)]; %#ok<AGROW>
        end
    end
end
result.nco_only = digitalBasisCheck();
result.checks = compatibilityChecks(seeds);

if ~isempty(outPath)
    fid = fopen(outPath,'w','n','UTF-8');
    assert(fid>=0,'无法写入 D1 回执。');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid,'%s\n',jsonencode(result,'PrettyPrint',true));
end
end

function row = runCase(rate,bits,level,seeds,n,divisor,duration,start,gain)
% 记录每个物理拍的限幅。发布帧按帧序号配对，使用相同检测中心真值和锚点。
arguments
    rate
    bits
    level
    seeds
    n
    divisor
    duration
    start
    gain = 1
end
overrides = struct('fs',6800*n,'adc_bits',bits, ...
    'adc_dither_lsb_rms',level,'adc_dither_seeds',seeds, ...
    'dac_divisor',divisor,'duration',duration,'log_decimation',1);
c = five_adc_study_config(rate,2,gain,[.5 1],overrides);
[~,trace,frames] = five_reference(c);
phase = c.validEnd+c.adcLatency;
published = round(frames(:,1)/c.Ts);
expectedFrame = ((0:floor((duration/c.Ts-phase)/c.frame))'*c.frame+phase);
expected = expectedFrame(expectedFrame*c.Ts>=start);
[fPresent,at] = ismember(expected,published);
valid = false(size(at));
valid(fPresent) = frames(at(fPresent),16)>0;
assert(~any(valid) || all(fPresent(valid)));
lastRms = NaN;
centeredRms = NaN;
detrendedRms = NaN;
peak = NaN;
slope = NaN;
finalError = NaN;
if numel(valid)>=2 && all(valid)
    f = frames(at,:);
    % 检测中心和发布时间相差固定量。在每个 Fs 用中心时刻对齐参考。
    time = (expected- phase+(c.validStart+c.validEnd-1)/2)*c.Ts;
    time = time-time(1);
    angle = f(:,15)-f(1,15);
    error = angle-rate*time;
    fit = polyfit(time,angle,1);
    lastRms = sqrt(mean(error.^2));
    centeredRms = std(error,1);
    detrendedRms = sqrt(mean((angle-polyval(fit,time)).^2));
    peak = max(abs(error));
    slope = fit(1);
    finalError = error(end);
end
slopeRelative = NaN;
if rate~=0, slopeRelative = 100*(slope-rate)/abs(rate); end
row = struct('omega_rad_s',rate,'adc_bits',bits,'adc_Hz',1/c.Ts, ...
    'dac_Hz',1/(c.Ts*divisor),'adc_pipeline_delay_us',1e6*c.adcLatency*c.Ts, ...
    'post_cv_gain',gain,'adc_peak_utilization',max(abs(trace(:,5:6)),[],'all')/(c.p.adc_span/2), ...
    'dither_LSB_rms',level,'dither_mV_rms',1e3*level*c.adcStep,'dither_seeds',seeds, ...
    'duration_s',duration,'expected_scoring_frames',numel(expected), ...
    'missed_scoring_frames',nnz(~valid),'scoring_frames',nnz(valid), ...
    'adc_clip_ticks',nnz(trace(:,20)),'dac_clip_ticks',nnz(trace(:,22)), ...
    'tracking_lost_ticks',nnz(trace(:,21)), ...
    'angle_fixed_anchor_rms_rad',lastRms,'angle_centered_rms_rad',centeredRms, ...
    'angle_detrended_rms_rad',detrendedRms,'angle_peak_rad',peak,'final_error_rad',finalError, ...
    'slope_rad_s',slope,'slope_error_rad_s',slope-rate,'slope_relative_error_pct',slopeRelative);
end

function row = digitalBasisCheck()
% 只改变数字解调参考相位时，既有 ADC 码不变。I/Q 同时旋转，
% Stokes 方位由内积构造，也不随同相/正交基旋转而变。
c = five_config('tdm_shared',.5,struct('duration',.003));
[~,~,~,monitor] = five_reference(c);
take = monitor(:,1)>=2*c.frame+c.validStart & monitor(:,1)<2*c.frame+c.validEnd;
codes = monitor(take,7:8);
phase = c.w*monitor(take,1)*c.Ts;
base = [cos(phase),sin(phase)]'*codes;
reference = stokesAngle(base);
offsets = deg2rad([17,45,90,137]);
errors = zeros(size(offsets));
for k = 1:numel(offsets)
    changed = [cos(phase+offsets(k)),sin(phase+offsets(k))]'*codes;
    delta = 4*(stokesAngle(changed)-reference);
    errors(k) = abs(atan2(sin(delta),cos(delta))/4);
end
assert(max(errors)<1e-12);
row = struct('offset_deg',rad2deg(offsets),'samples',nnz(take), ...
    'adc_codes_fixed',true,'max_orientation_change_rad',max(errors));
end

function angle = stokesAngle(iq)
% 共同旋转载波正交基时，每轴能量和跨轴内积保持不变。
energy = sum(iq.^2,1);
angle = atan2(2*dot(iq(:,1),iq(:,2)),energy(1)-energy(2))/4;
end

function checks = compatibilityChecks(seeds)
% 重跑验证默认值、不同种子和两路随机状态。预量化数据读自现有监测列。
c = five_config('tdm_shared',.5,struct('duration',.006,'log_decimation',1));
[t,a,f] = five_reference(c);
c.p = rmfield(c.p,{'adc_dither_lsb_rms','adc_dither_seeds'});
[t2,b,f2] = five_reference(c);
assert(isequal(t,t2) && isequal(a,b) && isequal(f,f2));
c.p.adc_dither_lsb_rms = .3;
c.p.adc_dither_seeds = seeds(1,:)';
[~,first,~,monitor] = five_reference(c);
[~,again,~,repeat] = five_reference(c);
assert(isequal(first,again) && isequal(monitor,repeat));
d = monitor(:,5:6)-monitor(:,3:4);
c.p.adc_dither_seeds = seeds(2,:)';
[~,other] = five_reference(c);
assert(~isequal(first(:,5:6),other(:,5:6)));
assert(all(abs(d)<=sqrt(3)*.3*c.adcStep+eps,'all'));
assert(max(abs(mean(d,1)))<.01*c.adcStep && ...
    all(abs(std(d,1,1)/c.adcStep-.3)<.01));
r = corrcoef(d);
assert(abs(r(1,2))<.05);
checks = struct('default_matches_legacy_config',true,'identical_seed_reproducible',true, ...
    'different_seed_changes_quantized_codes',true, ...
    'measured_dither_RMS_LSB',std(d,1,1)/c.adcStep,'channel_pearson',r(1,2));
end
