function y=wl_control_tick(u,c)
% Measured invariants(10), previous state(6), known virtual command, p(41).
d=u(1:2)+1i*u(3:4);E=u(5);Q=u(6);state=u(11:16);virtual=u(17);p=u(18:end);
err=[p(26)-E;-Q/max(E,p(40));u(10)];kp=[p(27);p(29);p(31)];ki=[p(28);p(30);p(32)];
out=zeros(3,1);integ=state(1:3);
valid=p(37)>0&&E>p(40)&&hypot(u(7),u(8))>p(41)&&all(isfinite(u(1:10)));
for j=1:3
 if valid
  [out(j),integ(j)]=wl_legacy('pi',err(j),integ(j),kp(j),ki(j),5,p(32+j),p(36),true,p(38));
 end
end
if c.controlFractionBits>0,out=round(out*2^c.controlFractionBits)/2^c.controlFractionBits;end
J=[0 -1;1 0];sig=1i*J;
h=out(1)*d+out(2)*sig*d-2*p(7)*virtual*c.virtualGainCalibration*J*d;
y=[integ;out;real(h);imag(h);out(3);out]; % state6, envelope4, NCO Hz1, diagnostics3
end
