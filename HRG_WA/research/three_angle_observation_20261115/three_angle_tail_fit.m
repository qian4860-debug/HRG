function fit = three_angle_tail_fit(t,v,clipped)
% 独立电气衰减拟合：时间 s、电压 V、逐拍过载标记；不读取机械角或注入标签。
% 拟合 v=b+a*exp(-t/tau)，偏置和有符号幅度由线性最小二乘消去。
% quality_pass 只允许进入配阻试验，不能作为导航角精度合格标志。
arguments
    t (:,1) double
    v (:,1) double
    clipped (:,1) logical
end
fit = struct('tau_s',NaN,'amplitude_V',NaN,'offset_V',NaN, ...
    'normalized_rms',NaN,'window_change_fraction',NaN, ...
    'quality_pass',false,'reasons',{{}});
if numel(t)~=numel(v) || numel(t)~=numel(clipped) || numel(t)<32 || ...
        any(~isfinite(t)) || any(~isfinite(v)) || any(diff(t)<=0)
    fit.reasons = {'invalid_or_insufficient_samples'}; return
end
if any(clipped)
    fit.reasons = {'clipping'}; return
end
t=t-t(1); dt=median(diff(t));
if max(abs(diff(t)-dt))>1e-3*dt
    fit.reasons = {'nonuniform_or_missing_samples'}; return
end
% 硬边界以采样间隔和总时长定义；最优解贴边也必须拒绝。
lo=2*dt; hi=2*t(end);
[tau,a,b,residual]=estimate(t,v,lo,hi);
ix=(floor(numel(t)*.1)+1):numel(t);
[later,~,~,~]=estimate(t(ix)-t(ix(1)),v(ix),lo,hi);
normalized=sqrt(mean(residual.^2))/max(abs(a),eps);
change=abs(later/tau-1);
reasons={};
if abs(a)<1e-3 || normalized>.01, reasons{end+1}='low_signal_or_model_residual'; end
if dt>tau/8, reasons{end+1}='undersampled_tail'; end
if t(end)<3*tau, reasons{end+1}='short_tail'; end
if change>.05, reasons{end+1}='window_sensitive_or_multiple_poles'; end
if tau<1.01*lo || tau>.99*hi, reasons{end+1}='fit_at_bound'; end
fit=struct('tau_s',tau,'amplitude_V',a,'offset_V',b, ...
    'normalized_rms',normalized,'window_change_fraction',change, ...
    'quality_pass',isempty(reasons),'reasons',{reasons});
end

function [tau,a,b,residual]=estimate(t,v,lo,hi)
% 在 log(tau) 域搜索保证正值；此处无需优化工具箱。
z=fminbnd(@(x) objective(exp(x),t,v),log(lo),log(hi), ...
    optimset('TolX',1e-10,'Display','off'));
tau=exp(z); X=[exp(-t/tau),ones(size(t))]; ab=X\v;
a=ab(1); b=ab(2); residual=v-X*ab;
end

function score=objective(tau,t,v)
X=[exp(-t/tau),ones(size(t))]; r=v-X*(X\v); score=sum(r.^2);
end
