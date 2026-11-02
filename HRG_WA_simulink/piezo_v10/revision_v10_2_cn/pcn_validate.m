function pcn_validate(p,c)
% 配置合同：检查时间、正值物理参数、整数窗口和被动阻尼。
% B未知仅允许静态测试；虚拟进动请求不得超过已验证范围。
% 带标定时还检查Ts一致；不把配置错误静默修正为可运行数字。
assert(p.Ts>0&&p.Tc>=p.Ts&&p.duration>0,'p101:time','Positive sample/window/duration required');
assert(all([p.Cs p.Cf p.Rs p.Rf p.b p.kappa p.charge_target]>0),'p101:units','Positive charge-domain port parameters required');
assert(abs(p.Tc/p.Ts-round(p.Tc/p.Ts))<1e-10,'p101:window','Noninteger demodulation window');
assert(abs(p.virtual_rate)<=p.virtual_validated_limit,'p101:virtualrate',...
 'Requested virtual rate exceeds the demonstrated fast-carrier validity range');
assert(p.Omega==0||(~isempty(p.B)&&p.B>0),'p101:unknownB','Unknown Bryan factor permits stationary tests only');
assert(p.gamma_intrinsic>abs(p.damping_half_difference),'p101:passivity','Damping tensor must be positive definite');
if nargin>1
 assert(isfield(c,'sample_period_s')&&abs(c.sample_period_s-p.Ts)<1e-14,'p101:calibrationtime',...
  'Drive calibration includes ZOH: changing Ts requires new calibration');
end
end
