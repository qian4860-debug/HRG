function result = three_mode_split_study(selectedModes, profile)
% 五电极三版同参实验。输入可限定模式和工况组，输出可直接编码为 JSON。
% 机械角 beta 与模态坐标角的关系为 theta0=2*beta，角速率采用 rad/s。
arguments
    selectedModes (1,:) string = ["continuous","tdm_separate","tdm_shared"]
    profile (1,1) string {mustBeMember(profile,["full","zero","signed","adc10","adc16","smoke"])} = "full"
end
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here,'..','..','HRG_WA_simulink','piezo_v10','five_electrode_20261110'));
addpath(fullfile(here,'..','tdm_gain_20261113'));
result = struct('release',version('-release'),'profile',profile);
result.setup = struct('f0_Hz',6800,'Q',30000,'parasitic_F',600e-12, ...
    'adc_bits',16,'adc_span_Vpp',2,'dac_bits',14,'gain',8,'adc_latency_ticks',5, ...
    'adc_dac_Hz',5440000,'dac_divisor',1,'rate_gate_mrad_s',.25, ...
    'angle_rms_gate_mrad',1,'adc_peak_gate_V',.8, ...
    'zero_input_duration_s',30,'zero_score_s',[.06 29.99], ...
    'zero_tail_score_s',[15 29.99],'signed_input_duration_s',3, ...
    'signed_score_s',[.06 2.99]);
splits = [0 .025 .05];
betas = [0 22.5];
rates = [0 .05 -.05 .2 -.2];
switch profile
    case "zero"
        rates = 0;
    case "signed"
        rates = rates(2:end);
    case {"adc10","adc16"}
        % 用相同端点、增益和 DAC 单独改变 ADC 码格；保留正负低速对。
        if profile == "adc10"
            result.setup.adc_bits = 10;
        end
        result.setup.zero_input_duration_s = 3;
        result.setup.zero_score_s = result.setup.signed_score_s;
        splits = [0 .05];
        rates = [0 .05 -.05];
    case "smoke"
        splits = .05;
        betas = 22.5;
        rates = [0 .05 -.05];
end
rows = struct([]);
pairs = struct([]);
for mode = selectedModes
    for split = splits
        for beta = betas
            % 同一初始方向和频差下先跑零速，再按同一速率幅值成对翻转。
            cases = struct([]);
            for rate = rates
                duration = result.setup.signed_input_duration_s;
                scoreInterval = result.setup.signed_score_s;
                if rate == 0
                    duration = result.setup.zero_input_duration_s;
                    scoreInterval = result.setup.zero_score_s;
                end
                if profile == "smoke"
                    duration = .08;
                    scoreInterval = [.03 .079];
                end
                c = three_mode_split_config(mode,rate,split,beta,duration,result.setup.adc_bits);
                [frames,info] = tdm_gain_fast(c);
                row = score_run(c,mode,rate,split,beta,frames,info,scoreInterval,result.setup);
                cases = [cases;row]; %#ok<AGROW>
                fprintf('%s split=%g mHz beta=%g rate=%+.3g rad/s: slope=%+.6f mrad/s, ADC peak=%.6f V\n', ...
                    mode,split*1000,beta,rate,row.fit_rate_mrad_s,info.adc_valid_peak_V);
            end
            rows = [rows;cases]; %#ok<AGROW>
            for positive = cases([cases.rate_rad_s]>0).'
                negative = cases([cases.rate_rad_s]==-positive.rate_rad_s);
                pairs = [pairs;score_pair(positive,negative)]; %#ok<AGROW>
            end
        end
    end
end
result.cases = rows;
result.signed_pairs = pairs;
end

function row = score_run(c,mode,rate,split,beta,frames,info,interval,s)
% 以各帧有效采样中心对齐时间。ADC 管线延迟保留在模型反馈路径中。
publishToCenter = (c.validEnd+c.adcLatency-(c.validStart+c.validEnd-1)/2)*c.Ts;
center = frames(:,1)-publishToCenter;
healthy = ~info.tracking_lost && info.published_frames==info.expected_frames && ...
    size(frames,1)>=2 && center(1)<=interval(1) && center(end)>=interval(2) && ...
    all(isfinite(frames(:,1:2)),'all') && all(diff(center)>0);
row = struct('mode',char(mode),'split_mHz',split*1000,'initial_beta_deg',beta, ...
    'rate_rad_s',rate,'duration_s',c.duration,'score_s',interval,'frame_ticks',c.frame, ...
    'drive_ticks',c.driveEnd,'valid_ticks',c.validEnd-c.validStart, ...
    'publish_to_center_s',publishToCenter, ...
    'fit_rate_mrad_s',NaN,'rate_error_mrad_s',NaN,'endpoint_error_mrad',NaN, ...
    'peak_error_mrad',NaN,'rms_error_mrad',NaN,'detrended_rms_mrad',NaN, ...
    'zero_checkpoint_s',[],'zero_checkpoint_error_mrad',[], ...
    'tail_fit_rate_mrad_s',NaN,'score_available',healthy, ...
    'rate_gate_pass',false,'angle_rms_gate_pass',false, ...
    'adc_peak_gate_pass',info.adc_sense_peak_V<=s.adc_peak_gate_V, ...
    'expected_frames',info.expected_frames, ...
    'published_frames',info.published_frames,'tracking_lost',info.tracking_lost, ...
    'adc_clip_ticks',info.adc_clip_ticks,'dac_clip_ticks',info.dac_clip_ticks, ...
    'adc_valid_peak_V',info.adc_valid_peak_V,'adc_sense_peak_V',info.adc_sense_peak_V, ...
    'cv_sense_peak_V',info.cv_sense_peak_V);
if ~healthy
    return
end
% 固定 1700 Hz 分析网格及端点，使两种发布节拍采用相同统计权重。
inside = ceil(interval(1)*1700):floor(interval(2)*1700);
time = unique([interval(1),inside/1700,interval(2)])';
angle = interp1(center,frames(:,2),time);
elapsed = time-time(1);
error = 1000*(angle-angle(1)-rate*elapsed);
row.rate_error_mrad_s = fit_slope(elapsed,error);
row.fit_rate_mrad_s = 1000*rate+row.rate_error_mrad_s;
row.endpoint_error_mrad = error(end);
row.peak_error_mrad = max(abs(error));
row.rms_error_mrad = sqrt(mean(error.^2));
residual = error-mean(error)-row.rate_error_mrad_s*(elapsed-mean(elapsed));
row.detrended_rms_mrad = sqrt(mean(residual.^2));
row.rate_gate_pass = abs(row.rate_error_mrad_s)<=s.rate_gate_mrad_s;
row.angle_rms_gate_pass = row.rms_error_mrad<=s.angle_rms_gate_mrad;
if rate==0 && interval(2)>=s.zero_tail_score_s(2)
    row.zero_checkpoint_s = [interval(1) 1 3 5 10 15 20 25 interval(2)];
    row.zero_checkpoint_error_mrad = ...
        1000*(interp1(center,frames(:,2),row.zero_checkpoint_s)-angle(1));
    tail = (ceil(s.zero_tail_score_s(1)*1700):floor(s.zero_tail_score_s(2)*1700))'/1700;
    tail = unique([s.zero_tail_score_s(1);tail;s.zero_tail_score_s(2)]);
    row.tail_fit_rate_mrad_s = fit_slope(tail,1000*interp1(center,frames(:,2),tail));
end
end

function slope = fit_slope(time,value)
% 有截距的最小二乘斜率，单位为 mrad/s。
centered = time-mean(time);
slope = dot(centered,value-mean(value))/dot(centered,centered);
end

function pair = score_pair(positive,negative)
% 对称速率实验的偶项与奇项只表征本工况，不视为可全局扣除的校准系数。
p = positive.fit_rate_mrad_s;
n = negative.fit_rate_mrad_s;
pair = struct('mode',positive.mode,'split_mHz',positive.split_mHz, ...
    'initial_beta_deg',positive.initial_beta_deg,'abs_rate_rad_s',positive.rate_rad_s, ...
    'positive_fit_mrad_s',p,'negative_fit_mrad_s',n,'even_mrad_s',(p+n)/2, ...
    'odd_scale_error_pct',100*((p-n)/(2000*positive.rate_rad_s)-1), ...
    'both_rate_gates_pass',positive.rate_gate_pass && negative.rate_gate_pass);
end
