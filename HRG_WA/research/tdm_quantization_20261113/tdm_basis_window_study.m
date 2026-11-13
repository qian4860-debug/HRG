function result = tdm_basis_window_study()
% 固定名义 AAF 模板候选，用独立 RC 生成端比较窗口、残差基阶数和角误差。
% 选择集与检验集使用独立种子和极点/阶数。此处不修改实际控制发布时间。
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here,'..','tdm_residual_20261112'));
prior = jsondecode(fileread(fullfile(here,'..','tdm_residual_20261112','tdm_residual_benchmark.json')));
fs = prior.fs_Hz;
f0 = prior.carrier_Hz;
n = round(fs/f0);
t = (0:2*n-1)'/fs;
phase = 2*pi*f0*(t+prior.physical_samples(1)/fs);
carrier = [cos(phase),sin(phase)];
z = 2*pi*prior.physical_aaf_pole_Hz*t;
basis = [exp(-t./prior.template_tau_s(:).'),exp(-z).*z.^(0:3)];
late = (0:2*n-1)'>=n;
weights = ones(2*n,1)/prior.weight_noise_std_V(1)^2;
weights(late) = 1/prior.weight_noise_std_V(2)^2;
cal = scenarios(carrier,t,prior,{20e3*[1 1 1 1],16e3*[1 1 1]},2801);
validation = scenarios(carrier,t,prior,{14e3*[1 1 1 1],26e3*[1 1 1 1], ...
    [14 14 14 35 26]*1e3},2802);
limit = prior.holdout_limit_V;
targetRms_rad = 1e-3;
targetCoverage = .95;
rows = [];
selected = [];
for cycles = [.7 1 1.15 1.3 1.5 2]
    use = 1:round(cycles*n);
    for order = 0:4
        % 正交化只使用预定物理模板；用训练集决定阶数并独立验证。
        template = orth(basis(:,1:2+order));
        d = tdm_residual_design(phase(use),template(use,:),late(use),Weights=weights(use));
        row = struct('cycles',cycles,'samples',numel(use),'aaf_basis_order',order, ...
            'carrier_info_fraction',d.carrier_info_fraction,'joint_design_ok',d.jointDesignOK, ...
            'late_design_ok',d.lateDesignOK,'calibration',score(cal,use,d,limit), ...
            'heldout',score(validation,use,d,limit));
        rows = [rows;row]; %#ok<AGROW>
        if isempty(selected) && row.calibration.joint_coverage>=targetCoverage && ...
                row.calibration.joint_angle_rms_rad<=targetRms_rad
            selected = row;
        end
    end
end
% 额外保存固定发布延迟在匀加速相对角上的精确解析对照。
delta = 74.5404411764706e-6;
time = linspace(0.06,0.18,204)';
acceleration = 2;
angle = @(t) .5*t+acceleration*t.^2/2;
rmsError = @(x) sqrt(mean(x.^2));
offset = (angle(time+delta)-angle(time(1)+delta))-(angle(time)-angle(time(1)));
expected = acceleration*delta*(time-time(1));
assert(max(abs(offset-expected))<1e-14);
result = struct('scope','Synthetic RC windows, frozen basis candidates and analytic timestamp check', ...
    'design_rms_limit_rad',targetRms_rad,'design_min_joint_coverage',targetCoverage, ...
    'selection_rule','Shortest window then lowest AAF order meeting calibration-only thresholds', ...
    'selected',selected,'rows',rows,'uniform_acceleration_rad_s2',acceleration, ...
    'publication_delay_s',delta,'relative_timestamp_error_rms_rad',rmsError(offset), ...
    'relative_timestamp_error_peak_rad',max(abs(offset)));
end

function data = scenarios(carrier,t,prior,cases,seed)
% 独立 RC 自然响应由矩阵指数生成。输出的解析载波 I/Q 与自然响应分开。
stream = RandStream('mt19937ar','Seed',seed);
n = numel(t);
count = 32*numel(cases);
y = zeros(n,2,count);
clip = false(n,count);
target = zeros(1,count);
stdev = repmat(prior.weight_noise_std_V(1),n,1);
stdev(n/2+1:end) = prior.weight_noise_std_V(2);
event = exp(-t./prior.template_tau_s(:).');
for k = 1:numel(cases)
    poles = 2*pi*cases{k};
    order = numel(poles);
    dynamics = -diag(poles)+diag(poles(2:end),-1);
    trans = expm(dynamics*(t(2)-t(1)));
    state = eye(order);
    response = zeros(n,order);
    for sample=1:n
        response(sample,:) = state(end,:);
        state = trans*state;
    end
    for frame=1:32
        idx = (k-1)*32+frame;
        beta = .65*sin(frame/7)+.2;
        commonPhase = .5*cos(frame/9);
        truth = .07*[cos(commonPhase);sin(commonPhase)]*[cos(2*beta),sin(2*beta)];
        input = carrier*truth+response*(.045*randn(stream,order,2)) ...
            +event*(.012*randn(stream,2,2))+stdev.*randn(stream,n,2);
        clip(:,idx) = any(input<prior.adc_min_V | input>prior.adc_max_V,2);
        y(:,:,idx) = min(prior.adc_max_V,max(prior.adc_min_V, ...
            prior.adc_step_V*round(input/prior.adc_step_V)));
        target(idx) = bearing(truth);
    end
end
data = struct('voltage',y,'clip',clip,'target',target);
end

function result = score(data,use,d,limit)
% 将联合、后窗与无效按实际输出计分。无输出时 RMS 不填数值。
count = numel(data.target);
status = strings(1,count);
error = nan(1,count);
for k = 1:count
    [iq,info] = tdm_residual_iq(data.voltage(use,:,k),d, ...
        Clipped=data.clip(use,k),HoldoutLimit_V=limit);
    status(k) = info.status;
    delta = bearing(iq)-data.target(k);
    error(k) = atan2(sin(4*delta),cos(4*delta))/4;
end
joint = status=="joint";
valid = status~="invalid";
result = struct('frames',count,'joint_coverage',mean(joint), ...
    'late_fallback_frames',nnz(status=="late_fallback"),'invalid_frames',nnz(~valid), ...
    'joint_angle_rms_rad',sqrt(mean(error(joint).^2)), ...
    'published_angle_rms_rad',sqrt(mean(error(valid).^2)));
end

function beta = bearing(iq)
% 载波平面 I/Q 对应四倍驻波方位，公共载波相位不影响角度。
energy = sum(iq.^2,1);
beta = atan2(2*dot(iq(:,1),iq(:,2)),energy(1)-energy(2))/4;
end
