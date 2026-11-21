function gate = split_observation_guard(reading,fit,probe,t_now,latched)
% 输入均已在 t_now 获得。fit 是该激励段解相位的有限前缀；probe 保存最近
% 一次两轴带标签的独立单模观测。latched 在新激励触发时由调用方清零。
% 门控不修改频差估值。IQ 单支路放行指标单列，以便量化独立见证的贡献。
score = hinge_score(fit);
latched = latched || score>4.5;
iq_valid = reading.valid && ~latched;
axis = axis_check(probe,t_now);
gate = struct('iq_valid',iq_valid,'valid',iq_valid && axis.ok,'latched',latched, ...
    'hinge_z',score,'axis_bound_deg',axis.bound_deg,'axis_ok',axis.ok, ...
    'reason',reading.reason);
if reading.valid && ~axis.ok, gate.reason = "axis_witness"; end
if reading.valid && latched, gate.reason = "phase_change"; end
end

function value = hinge_score(fit)
% 固定折点检验。在稳态差相位直线上加入斜率突变项，仅拟合过去的样本。
% 用加权投影消除原直线。4.5 是冻结的诊断阈值，多窗最大值不作单次概率解释。
t = fit.time_s; value = 0;
if isempty(t) || t(end)-t(1)<0.5, return, end
t = t-t(1); w = fit.inverse_variance;
base = [ones(size(t)),t].*sqrt(w); [q,~] = qr(base,0);
y = fit.phase_rad.*sqrt(w); resid = y-q*(q'*y);
cuts = 0.25:0.125:t(end)-0.25;
for cut = cuts
    hook = max(0,t-cut).*sqrt(w);
    h = hook-q*(q'*hook);
    value = max(value,abs(h'*resid)/max(norm(h),eps));
end
end

function axis = axis_check(probe,t)
% 每次轴检定对 X/Y 两个独立选择的单模振动各测两路复包络；四倍角跨界前用
% 二倍方向角消除两个振动轴各自的整体符号。角度阈值为本轮假设，未作机电标定。
axis = struct('ok',false,'bound_deg',NaN);
if ~isfinite(probe.at_s) || probe.at_s>t || t-probe.at_s>=4.25
    return
end
z = probe.iq;
if ~isequal(size(z),[32 2 2]) || any(~isfinite(z),'all'), return, end
bounds = zeros(1,2);
for j = 1:2
    x = z(:,1,j); y = z(:,2,j);
    % 按八个观测区块推算轴向与测量离散；没有独立单模激励时应停用该检查。
    q = mean(reshape(abs(x).^2-abs(y).^2,4,8),1);
    u = 2*mean(reshape(real(conj(x).*y),4,8),1);
    e = mean(reshape(abs(x).^2+abs(y).^2,4,8),1);
    if any(e<=0) || any(hypot(q,u)<0.98*e), return, end
    direction = atan2d((3-2*j)*u,(3-2*j)*q)/2;
    bounds(j) = abs(mean(direction))+3*std(direction)/sqrt(numel(direction));
end
axis.bound_deg = max(bounds);
axis.ok = axis.bound_deg<=0.30;
end
