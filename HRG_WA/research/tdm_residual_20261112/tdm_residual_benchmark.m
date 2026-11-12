function result = tdm_residual_benchmark(outPath)
% 6.8 kHz 五电极分时解调的离线对照。比较同一量化样本上的矩形全窗、
% 加权全窗、常规后窗与受保护联合估计。合成工况有独立 I/Q 真值；
% 模型回放只用五电极模拟前端作为输入，参考为未加扰动的后窗结果。
arguments
    outPath (1,:) char = fullfile(fileparts(mfilename('fullpath')),'tdm_residual_benchmark.json')
end
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here,'..','..','HRG_WA_simulink','piezo_v10','five_electrode_20261110'));
c = five_config('tdm_shared',.5,struct('duration',.04,'dac_divisor',25));
[~,~,~,monitor] = five_reference(c);
n = c.validEnd-c.senseStart;
ticks = (0:n-1)';
time = ticks*c.Ts;
late = ticks>=c.validStart-c.senseStart;
phase = c.w*(c.senseStart+ticks)*c.Ts;
carrier = [cos(phase),sin(phase)];

% 模板及噪声参数在评估前固定。训练随机数流独立，不读取评估帧的 I/Q 或残差振幅。
tau = [24 90]*1e-6;
templates = exp(-time./tau);
noiseStd = [.0016 .0005];
cal = RandStream('mt19937ar','Seed',6112);
noiseCalibration = randn(cal,40000,2).*noiseStd;
sigma2 = var(noiseCalibration,0,1)+(c.adcStep^2/12);
weights = ones(n,1)/sigma2(1);
weights(late) = 1/sigma2(2);
holdoutLimit = 1.3*sqrt(max(sigma2));
d = tdm_residual_design(phase,templates,late,Weights=weights);
assert(d.jointDesignOK && d.lateDesignOK);
% 四级同极点 AAF 在重连后的自然响应为 exp(-z) 乘 0 至 3 阶多项式。
% 使用模型预先配置的极点，不从评分帧学习模板，也不把载波列混入残差基。
assert(all(c.p.afe_bw==c.p.afe_bw(1)), '本研究对照使用两路相同的 AAF 极点。');
z = 2*pi*c.p.afe_bw(1)*time;
physicalTemplates = orth([templates,exp(-z).*z.^(0:c.p.aaf_order-1)]);
dPhysical = tdm_residual_design(phase,physicalTemplates,late,Weights=weights);
assert(dPhysical.jointDesignOK && dPhysical.lateDesignOK);
[q,r] = qr(carrier,0);
fullMap = r\q';
weightedCarrier = carrier.*sqrt(weights);
[q,r] = qr(weightedCarrier,0);
weightedMap = (r\q').*sqrt(weights)';
[q,r] = qr(carrier(late,:),0);
lateMap = r\q';

% 合成样本与模型样本分开报告。失配模板和过载场景均保留在回执中。
scenarios = {'synthetic_clean','synthetic_matched','synthetic_tau_mismatch', ...
    'synthetic_ringing','synthetic_clip','model_clean','model_added_residual'};
result = struct('release',version('-release'), ...
    'scope','Offline study using synthetic transients and existing behavioral analog monitor', ...
    'fs_Hz',1/c.Ts,'carrier_Hz',c.p.carrier_hz,'adc_bits',c.p.adc_bits, ...
    'adc_step_V',c.adcStep,'adc_min_V',c.adcMin,'adc_max_V',c.adcMax, ...
    'adc_pipeline_ticks',c.adcLatency, ...
    'physical_samples',[c.senseStart c.validStart c.validEnd], ...
    'full_samples',n,'late_samples',nnz(late),'calibration_rng_seed',6112, ...
    'evaluation_rng_seed_base',12000,'template_tau_s',tau, ...
    'physical_aaf_pole_Hz',c.p.afe_bw(1),'physical_aaf_order',c.p.aaf_order, ...
    'physical_template_rank',size(physicalTemplates,2), ...
    'weight_noise_std_V',sqrt(sigma2),'holdout_limit_V',holdoutLimit, ...
    'full_condition',d.condition,'full_carrier_info_fraction',d.carrier_info_fraction, ...
    'physical_condition',dPhysical.condition, ...
    'physical_carrier_info_fraction',dPhysical.carrier_info_fraction, ...
    'training_condition',d.training_condition, ...
    'training_carrier_info_fraction',d.training_carrier_info_fraction, ...
    'window_information',[],'cases',[],'checks',struct());
for cycles = [1/8 1/4 1/2 1 1.5 2]
    use = 1:round(c.n*cycles);
    partial = tdm_residual_design(phase(use),templates(use,:),late(use),Weights=weights(use));
    result.window_information = [result.window_information;struct('carrier_cycles',cycles, ...
        'samples',numel(use),'condition',partial.condition, ...
        'carrier_info_fraction',partial.carrier_info_fraction,'passes_guard',partial.jointDesignOK)];
end
for scenario = 1:numel(scenarios)
    label = scenarios{scenario};
    model = startsWith(label,'model');
    if model
        % 只取完整检测窗并跳过启动八帧，X/Y 信号源是量化前的模型观测。
        count = floor(size(monitor,1)/n);
        raw = reshape(monitor(1:n*count,3:4),[n,count,2]);
        clean = permute(raw(:,9:end,:),[1 3 2]);
        detector = c.detect;
    else
        clean = zeros(n,2,64);
        detector = eye(4);
    end
    count = size(clean,3);
    methods = {'full_ols','full_wls','late_ols','guarded_joint','guarded_joint_aaf'};
    errors = nan(count,numel(methods));
    iqErrors = nan(count,numel(methods));
    status = strings(count,1);
    reason = strings(count,1);
    statusPhysical = strings(count,1);
    reasonPhysical = strings(count,1);
    clipType = zeros(count,1);
    evalRng = RandStream('mt19937ar','Seed',12000+scenario);
    for k = 1:count
        if model
            target = lateMap*clean(late,:,k);
        else
            beta = .71*sin(k/17)+.27;
            u = [cos(2*beta),sin(2*beta)];
            v = [-u(2),u(1)];
            phi = .6*cos(k/13);
            target = .08*[cos(phi),sin(phi);-sin(phi),cos(phi)]*[u;.04*v];
            clean(:,:,k) = carrier*target;
        end
        y = clean(:,:,k);
        if ~ismember(label,{'synthetic_clean','model_clean'})
            actual = templates;
            if strcmp(label,'synthetic_tau_mismatch')
                actual = exp(-time./(tau.*[1.6 .65]));
            end
            amplitude = (2*rand(evalRng,2,2)-1).*[.024;.016];
            y = y+actual*amplitude;
            if strcmp(label,'synthetic_ringing')
                y = y+exp(-time/120e-6).*sin(2*pi*7200*time)*[.025,-.018];
            end
        end
        sigma = repmat(noiseStd(1),n,1);
        sigma(late) = noiseStd(2);
        y = y + randn(evalRng,n,2).*sigma;
        if strcmp(label,'synthetic_clip')
            % 前窗饱和验证回退，后窗饱和验证禁止输出。其余帧供共同样本评分。
            if mod(k,4)==1
                y(5,1) = 1.5*c.adcMax;
                clipType(k) = 1;
            elseif mod(k,4)==2
                y(find(late,1)+5,2) = 1.5*c.adcMin;
                clipType(k) = 2;
            end
        end
        clipped = any(y<c.adcMin | y>c.adcMax,2);
        y = min(c.adcMax,max(c.adcMin,c.adcStep*round(y/c.adcStep)));
        estimates = nan(2,2,numel(methods));
        if ~any(clipped)
            estimates(:,:,1) = fullMap*y;
            estimates(:,:,2) = weightedMap*y;
        end
        if ~any(clipped(late))
            estimates(:,:,3) = lateMap*y(late,:);
        end
        [estimates(:,:,4),info] = tdm_residual_iq(y,d,Clipped=clipped,HoldoutLimit_V=holdoutLimit);
        status(k) = info.status;
        reason(k) = info.reason;
        [estimates(:,:,5),info] = tdm_residual_iq(y,dPhysical,Clipped=clipped,HoldoutLimit_V=holdoutLimit);
        statusPhysical(k) = info.status;
        reasonPhysical(k) = info.reason;
        betaTrue = orientation(target,detector);
        for method = 1:numel(methods)
            estimate = estimates(:,:,method);
            iqErrors(k,method) = sqrt(mean((estimate-target).^2,'all'));
            delta = 4*(orientation(estimate,detector)-betaTrue);
            errors(k,method) = atan2(sin(delta),cos(delta))/4;
        end
    end
    common = all(isfinite(errors),2);
    stats = [];
    for method = 1:numel(methods)
        own = isfinite(errors(:,method));
        stats = [stats;struct('method',methods{method},'accepted_frames',nnz(own), ...
            'coverage',nnz(own)/count, ...
            'own_beta_rms_rad',rmsValue(errors(own,method)), ...
            'common_beta_rms_rad',rmsValue(errors(common,method)), ...
            'common_beta_p95_abs_rad',absP95(errors(common,method)), ...
            'common_iq_rms_V',rmsValue(iqErrors(common,method)))];
    end
    result.cases = [result.cases;struct('name',label,'frames',count,'common_frames',nnz(common), ...
        'truth_kind',stringTruth(model),'methods',stats,'joint_frames',nnz(status=="joint"), ...
        'fallback_frames',nnz(status=="late_fallback"),'invalid_frames',nnz(status=="invalid"), ...
        'mismatch_rejections',nnz(reason=="template_mismatch"), ...
        'aaf_joint_frames',nnz(statusPhysical=="joint"), ...
        'aaf_fallback_frames',nnz(statusPhysical=="late_fallback"), ...
        'aaf_invalid_frames',nnz(statusPhysical=="invalid"), ...
        'aaf_mismatch_rejections',nnz(reasonPhysical=="template_mismatch"), ...
        'early_clip_fallbacks',nnz(clipType==1 & status=="late_fallback"), ...
        'late_clip_invalids',nnz(clipType==2 & status=="invalid"))];
end

% 不依赖随机改善的硬断言，分别覆盖代数精度、秩退化、错模板和过载路径。
exactIQ = [.05 .01;-.01 .02];
exact = carrier*exactIQ+templates*[.01 -.02;-.02 .01];
[est,info] = tdm_residual_iq(exact,d,HoldoutLimit_V=1e-12);
assert(info.status=="joint" && max(abs(est-exactIQ),[],'all')<1e-12);
degenerate = tdm_residual_design(phase,[carrier(:,1),templates],late,Weights=weights);
[~,info] = tdm_residual_iq(exact,degenerate);
assert(info.status=="late_fallback" && info.reason=="identifiability");
[~,info] = tdm_residual_iq(exact+.04*sin(4*phase),d,HoldoutLimit_V=holdoutLimit);
assert(info.status=="late_fallback" && info.reason=="template_mismatch");
clip = result.cases(strcmp({result.cases.name},'synthetic_clip'));
assert(clip.early_clip_fallbacks==16 && clip.late_clip_invalids==16);
result.checks = struct('exact_recovery',true,'degenerate_basis_fallback',true, ...
    'holdout_rejection',true,'early_and_late_clip_gates',true);
fid = fopen(outPath,'w','n','UTF-8');
assert(fid>=0,'无法写入研究回执。');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid,'%s\n',jsonencode(result,'PrettyPrint',true));
end

function beta = orientation(iq,detector)
% 从校准的 X/Y 复载波计算 n=2 驻波角，范围为 ±π/4。
iq = detector*reshape(iq.',4,1);
i = iq(1:2);
q = iq(3:4);
p = i.^2+q.^2;
beta = atan2(2*(i(1)*i(2)+q(1)*q(2)),p(1)-p(2))/4;
end

function r = rmsValue(x)
% 同一组接受帧上的 RMS。没有共同样本时保留 NaN，JSON 中写 null。
r = sqrt(mean(x.^2));
end

function p = absP95(x)
% 绝对值 95% 分位采用近邻秩，避免额外工具箱依赖。
p = NaN;
if ~isempty(x)
    v = sort(abs(x));
    p = v(ceil(.95*numel(v)));
end
end

function source = stringTruth(isModel)
% 将合成真值与模型回放的后窗参照明确区分。
if isModel
    source = 'noise-free late-window monitor proxy';
else
    source = 'known synthetic carrier coefficients';
end
end
