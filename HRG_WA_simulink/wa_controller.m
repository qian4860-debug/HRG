function y = wa_controller(u)
% u=[measurement(10); PI integrals(3); reference phase; virtual rate; p(41)]
d = u(1:2)+1i*u(3:4); E=u(5); Q=u(6); phi=u(10);
ints=u(11:13); psi=u(14); virtual=u(15); p=u(16:end);
errors = [p(26)-E;-Q/max(E,p(40));phi];
raw = [p(27);p(29);p(31)].*errors+ints;
limits = p(33:35);
ctrl = max(-limits,min(limits,raw));
di = [p(28);p(30);p(32)].*errors+p(36)*(ctrl-raw);
if E<p(40) || hypot(u(7),u(8))<p(41) || p(37)==0
    ctrl=zeros(3,1);di=zeros(3,1);
end
sigma2 = [0 -1i;1i 0]; J=[0 -1;1 0];
href = ctrl(1)*d+ctrl(2)*sigma2*d-2*p(7)*virtual*J*d;
% Reconstruct electrode-fixed force envelope; actuator mismatch is independent.
h = reshape(p(18:21),2,2)*href*exp(1i*psi);
y = [real(h);imag(h);di;2*pi*ctrl(3);ctrl];
end
