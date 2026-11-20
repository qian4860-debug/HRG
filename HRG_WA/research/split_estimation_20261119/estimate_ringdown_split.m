function reading = estimate_ringdown_split(time_s, iq)
% 单次激励后两路主轴复包络的因果频差估计。time_s 为已取得的样本时刻，
% iq 为 N×2（实部 I、虚部 Q）；量纲可归一化，但两路应共用载波与时钟。
% 两通道须已有独立的模态轴校准。本函数不接收输入频差、工况、噪声或转速真值。
reading = struct('split_est_mHz',NaN,'uncertainty_mHz',NaN, ...
    'valid',false,'reason',"invalid_input",'samples_used',0);
t = time_s(:);
if size(iq,2) ~= 2 || size(iq,1) ~= numel(t) || numel(t) < 10 || ...
        any(~isfinite(t)) || any(~isfinite(iq),'all') || any(diff(t) <= 0)
    return
end
dt = median(diff(t));
if any(abs(diff(t)-dt) > 1e-6*dt)
    reading.reason = "discontinuous_clock";
    return
end
% 对独立、近白、圆对称复噪声，二阶差分功率约为 6 倍复噪声功率。
% 差分模方服从指数分布，其总体中位数为均值的 ln(2) 倍。
amplitude_sq = abs(iq).^2;
noise_floor = max(realmin,eps*max(amplitude_sq,[],1));
noise_power = max(noise_floor,median(abs(diff(iq,2,1)).^2,1)/(6*log(2)));
usable = all(amplitude_sq > 36*noise_power,2);
% 使用从激励开始的高信噪比连续前缀，避免跨低幅值区间展开相位。
stop = find(~usable,1);
if ~isempty(stop)
    usable(stop:end) = false;
end
reading.samples_used = nnz(usable);
if reading.samples_used < 20 || t(find(usable,1,'last'))-t(1) < 0.2
    reading.reason = "weak_or_short";
    return
end
v = iq(usable,:);
phase = unwrap(angle(v(:,2).*conj(v(:,1))));
% 公共载波相位在差相位中抵消。高信噪比下角噪声方差约为 Pn/(2*|iq|²)。
variance = sum(noise_power./(2*abs(v).^2),2);
w = 1./variance;
t = t(usable);
centered_time = t-sum(w.*t)/sum(w);
centered_phase = phase-sum(w.*phase)/sum(w);
sxx = sum(w.*centered_time.^2);
slope = sum(w.*centered_time.*centered_phase)/sxx;
fit_residual = centered_phase-slope*centered_time;
reduced_chi2 = sum(w.*fit_residual.^2)/(numel(t)-2);
% 给出白噪声、小相位误差且主轴正确时的近似 95% 半宽。拟合残差过大
% 会扩宽半宽；稳定的系统误差可能逃逸这一检查，须另做轴混合反例。
unit = 1000/(2*pi);
reading.split_est_mHz = unit*abs(slope);
reading.uncertainty_mHz = 1.96*unit*sqrt(max(1,reduced_chi2)/sxx);
reading.valid = reading.uncertainty_mHz <= 0.71;
if reading.valid
    reading.reason = "conditional_precision";
else
    reading.reason = "uncertainty";
end
end
