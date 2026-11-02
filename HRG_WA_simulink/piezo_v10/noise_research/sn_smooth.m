function [s,z]=sn_smooth(s,z,p,condition,clipped)
% 因果端点线性回归：只用当前和过去完整帧，估计当前源中心的IQ。
% 与简单均值不同：sum(h)=1，sum(h*lag)=0，保留匀速一阶变化。
raw=pcn_validity(real(z),-imag(z),p,clipped,condition);s.raw_valid=double(raw.valid);
if ~raw.valid
 s.iq_history(:)=0;s.history_count=0;return
end
s.iq_history(:,2:end)=s.iq_history(:,1:end-1);s.iq_history(:,1)=[real(z);-imag(z)];s.history_count=min(32,s.history_count+1);
if ~p.enable_iq_estimator,return;end
% 快速建幅不满足局部线性假设；只在已声明最短时间且幅值接近目标后使用。
% 历史仍持续收集，无未来样本；门控只读原始可观性和幅值。
if s.k*p.Ts<.25 || abs(sqrt(raw.energy)/p.charge_target-1)>.05,return;end
n=s.history_count;if n<3,return;end
t=-(0:n-1);X=[ones(n,1),t'];h=[1 0]*((X'*X)\X');v=s.iq_history(:,1:n)*h';z=v(1:2)-1i*v(3:4);
end
