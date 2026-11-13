function result = tdm_gain_selection(outDir)
% DSH29 P0。以冻结角锚点比较 10/16 位、模拟后级增益和初始驻波角。
% 短时名义、单次额外瞬态包络、30 s 数值诊断分别报告。
arguments
    outDir (1,:) char = fileparts(mfilename('fullpath'))
end
here = fileparts(mfilename('fullpath'));
root = fileparts(here);
addpath(fullfile(root,'five_adc_range_20261110'));
addpath(fullfile(root,'..','HRG_WA_simulink','piezo_v10','five_electrode_20261110'));
if ~isfolder(outDir), mkdir(outDir); end
evidence = tdm_gain_fast_verify;
duration = .18;
scoreStart = .06;
rates = [0,.01,.05,-.05,.1,.2,-.2,.5,1,4,-4];
betaAngles = [0,22.5,45,67.5];
gains = [1 6 8];
result = struct('release',version('-release'), ...
    'scope','Synthetic five-electrode TDM closed-loop quantization and linear recovery study', ...
    'nominal_duration_s',duration,'nominal_score_start_s',scoreStart,'adc_Hz',5440000, ...
    'dac_Hz',5440000,'rates_rad_s',rates,'physical_initial_beta_deg',betaAngles, ...
    'angle_limit_mrad',1,'abs_slope_limit_mrad_s',.25,'adc_recovery_limit_percent',80, ...
    'parity',evidence,'nominal',[],'transient',[],'zero_30s',[],'summary',[]);
for bits = [10,16]
    for gain = gains
        % 相同位宽/增益/时序的状态矩阵可跨机体速率和初角复用，角速率会改变
        % 机械状态矩阵，因此只在同一速率的四个初始角间共享映射。
        for rate = rates
            cfg = makeConfig(bits,gain,rate,betaAngles(1),duration);
            blocks = tdm_gain_blocks(cfg);
            for beta = betaAngles
                cfg = makeConfig(bits,gain,rate,beta,duration);
                [frames,info] = tdm_gain_fast(cfg,blocks);
                r = score(frames,info,cfg,scoreStart);
                r.initial_beta_deg = beta;
                r.adc_bits = bits;
                r.post_cv_gain = gain;
                result.nominal = [result.nominal;r]; %#ok<AGROW>
            end
        end
        writeReceipt(result,outDir);
        fprintf('P0 nominal %d-bit ×%d complete, %d rows\n',bits,gain,numel(result.nominal));
    end
end

% 合成双源事件（关断后四组残压、接通瞬间注入）与各工况名义峰值上界相加。
% 余量窗口分为 ADC 有效采样窗与完整检测接通窗，后者决定模拟饱和风险。
for gain = gains
    c = makeConfig(10,gain,.5,0,duration);
    row = recovery(c);
    a = result.nominal([result.nominal.post_cv_gain]==gain);
    row.post_cv_gain = gain;
    row.nominal_max_valid_V = max([a.adc_valid_peak_V]);
    row.nominal_max_sense_V = max([a.adc_sense_peak_V]);
    row.nominal_max_cv_V = max([a.cv_sense_peak_V]);
    row.upper_valid_percent_FS = 100*(row.nominal_max_valid_V+row.added_adc_valid_peak_V)/(c.p.adc_span/2);
    row.upper_sense_percent_FS = 100*(row.nominal_max_sense_V+row.added_adc_sense_peak_V)/(c.p.adc_span/2);
    row.upper_cv_V = row.nominal_max_cv_V+row.added_cv_peak_V;
    row.G3_valid_pass = row.upper_valid_percent_FS<=80;
    row.G3_full_sense_pass = row.upper_sense_percent_FS<=80;
    result.transient = [result.transient;row]; %#ok<AGROW>
end

% 30 s 运行用于零速码平台诊断，未加随机温漂/电路噪声，不拟合 BI。
for bits = [10 16]
    for gain = [6 8]
        c = makeConfig(bits,gain,0,22.5,30);
        [frames,info] = tdm_gain_fast(c);
        row = score(frames,info,c,scoreStart);
        row.adc_bits = bits;
        row.post_cv_gain = gain;
        row.initial_beta_deg = 22.5;
        row.G4_pass = ~info.tracking_lost && info.published_frames==info.expected_frames;
        [row.allan_tau_s,row.synthetic_allan_rad_s] = allanAngle(frames,c);
        result.zero_30s = [result.zero_30s;row]; %#ok<AGROW>
        writeReceipt(result,outDir);
        fprintf('P0 zero 30s %d-bit ×%d complete\n',bits,gain);
    end
end

for bits = [10 16]
    for gain = gains
        a = result.nominal([result.nominal.adc_bits]==bits & [result.nominal.post_cv_gain]==gain);
        [worstSlope,slopeIdx] = max([a.abs_slope_error_mrad_s]);
        [worstAngle,angleIdx] = max([a.fixed_anchor_rms_mrad]);
        result.summary = [result.summary;struct('adc_bits',bits,'gain',gain, ...
            'cases',numel(a),'G1_pass_count',nnz([a.G1_pass]),'G2_pass_count',nnz([a.G2_pass]), ...
            'both_pass_count',nnz([a.G1_pass] & [a.G2_pass]), ...
            'worst_slope_mrad_s',worstSlope,'worst_slope_rate_rad_s',a(slopeIdx).omega_rad_s, ...
            'worst_slope_beta_deg',a(slopeIdx).initial_beta_deg, ...
            'worst_angle_rms_mrad',worstAngle,'worst_angle_rate_rad_s',a(angleIdx).omega_rad_s, ...
            'worst_angle_beta_deg',a(angleIdx).initial_beta_deg)]; %#ok<AGROW>
    end
end
writeReceipt(result,outDir);
end

function c = makeConfig(bits,gain,rate,beta,duration)
% p.theta0 是模态空间相位，n=2 驻波的物理初角为 theta0/2。
overrides = struct('adc_bits',bits,'theta0',deg2rad(2*beta),'duration',duration);
c = five_adc_study_config(rate,2,gain,[.5 1],overrides);
end

function row = score(frames,info,c,scoreStart)
% 采用已登记的 60 ms 起点。首个发布帧丢失时拒绝打分，防止静默重锚。
publishPhase = c.validEnd+c.adcLatency;
expected = (publishPhase+(0:info.expected_frames-1)'*c.frame)*c.Ts;
expected = expected(expected>=scoreStart);
f = frames(frames(:,1)>=scoreStart,:);
valid = numel(expected)==size(f,1) && all(abs(f(:,1)-expected)<c.Ts/100);
metrics = nan(1,6);
if valid && size(f,1)>=2
    t = f(:,1)-f(1,1);
    angle = f(:,2)-f(1,2);
    err = angle-c.omega*t;
    p = polyfit(t,angle,1);
    metrics = [p(1),1e3*sqrt(mean(err.^2)),1e3*std(err,1), ...
        1e3*sqrt(mean((angle-polyval(p,t)).^2)),1e3*max(abs(err)),1e3*err(end)];
end
relative = NaN;
if abs(c.omega)>=.5, relative = 100*(metrics(1)-c.omega)/abs(c.omega); end
slopeError = 1e3*(metrics(1)-c.omega);
row = struct('omega_rad_s',c.omega,'duration_s',c.duration,'estimated_rate_rad_s',metrics(1), ...
    'signed_slope_error_mrad_s',slopeError,'abs_slope_error_mrad_s',abs(slopeError), ...
    'rated_relative_slope_error_percent',relative,'fixed_anchor_rms_mrad',metrics(2), ...
    'centered_rms_mrad',metrics(3),'detrended_rms_mrad',metrics(4),'peak_error_mrad',metrics(5), ...
    'last_error_mrad',metrics(6),'G1_pass',metrics(2)<=1,'G2_pass',abs(slopeError)<=.25, ...
    'expected_frames',info.expected_frames,'published_frames',info.published_frames, ...
    'scored_expected_frames',numel(expected),'scored_published_frames',size(f,1), ...
    'frame_loss',info.expected_frames-info.published_frames,'tracking_lost',info.tracking_lost, ...
    'adc_clip_ticks',info.adc_clip_ticks,'dac_clip_ticks',info.dac_clip_ticks, ...
    'adc_valid_peak_V',info.adc_valid_peak_V,'adc_sense_peak_V',info.adc_sense_peak_V, ...
    'adc_valid_utilization_percent',100*info.adc_valid_peak_V/(c.p.adc_span/2), ...
    'cv_sense_peak_V',info.cv_sense_peak_V);
end

function row = recovery(c)
% 从组端电压状态叠加独立的有界事件。泄放段传播残压，注入由 C⁻¹Q
% 转成接通瞬时电压。用每一观测的绝对值和界定所有符号组合。
release_V = 10;
inject_C = 1e-15;
terminal = c.groupVoltage(:,7:10);
release = zeros(c.stateCount,4);
release(7:10,:) = terminal\(release_V*eye(4));
inject = zeros(c.stateCount,4);
inject(7:10,:) = terminal\(c.portCapacitance_F\(inject_C*eye(4)));
state = [(c.Af^(c.senseStart-c.driveEnd))*release,inject];
adc = zeros(c.validEnd-c.senseStart,2);
cv = zeros(size(adc,1),4);
for k = 1:size(adc,1)
    adc(k,:) = sum(abs(c.pickoff*state),2)';
    cv(k,:) = sum(abs(c.portCV*state),2)';
    state = c.As*state;
end
valid = c.validStart-c.senseStart+1:size(adc,1);
row = struct('release_V_per_group',release_V,'injection_fC_per_group',1, ...
    'added_adc_sense_peak_V',max(adc,[],'all'), ...
    'added_adc_valid_peak_V',max(adc(valid,:),[],'all'), ...
    'added_cv_peak_V',max(cv,[],'all'),'cv_rail_verified',false);
end

function [tau,adev] = allanAngle(frames,c)
% 对等间隔角增量的二阶差分计算重叠 Allan 偏差，单位 rad/s。
period = c.frame*c.Ts;
steps = round([.01 .05 .1 .5 1 2 5 10]/period);
tau = steps*period;
adev = nan(size(tau));
if size(frames,1)<3 || any(abs(diff(frames(:,1))-period)>c.Ts/100)
    return
end
angle = frames(:,2);
for k = 1:numel(steps)
    m = steps(k);
    if 2*m<numel(angle)
        delta = angle(1+2*m:end)-2*angle(1+m:end-m)+angle(1:end-2*m);
        adev(k) = sqrt(mean(delta.^2)/2)/tau(k);
    end
end
end

function writeReceipt(result,outDir)
% 每个完成的位宽/增益分组及长窗工况保存已验证记录。
target = fullfile(outDir,'gain_selection.json');
temporary = [target '.tmp'];
fid = fopen(temporary,'w','n','UTF-8');
assert(fid>=0,'无法写入 P0 回执。');
fprintf(fid,'%s\n',jsonencode(result,'PrettyPrint',true));
fclose(fid);
movefile(temporary,target,'f');
writetable(struct2table(result.nominal),fullfile(outDir,'gain_selection_table.csv'));
end
