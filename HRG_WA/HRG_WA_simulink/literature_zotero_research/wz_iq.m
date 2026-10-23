function y=wz_iq(u,c)
% Same frozen inverse as V8, with a proved small-cubic iteration gate.
if ~c.v8.enabled || ~any(c.v8.cubicCoefficient~=0)
 y=w8_iq(u,c);return;
end
d=c.v8.senseInverse*((u(1:2)+1i*u(3:4))*c.v7.senseCalibration);
b=c.v8.cubicCoefficient(:);magnitude=abs(d);
if any(b.*magnitude.^2>.05)
 y=w8_iq(u,c);return; % Original seven-step and out-of-range behavior.
end
assert(all(b>=0)&&norm(c.v8.senseInverse-diag(diag(c.v8.senseInverse)),'fro')<1e-12);
a=magnitude;
for k=1:3,a=a-(a+b.*a.^3-magnitude)./(1+3*b.*a.^2);end
if any(abs(a-c.v8.maximumCalibratedAmplitude)<64*eps(max(1,c.v8.maximumCalibratedAmplitude)))
 y=w8_iq(u,c);return; % Preserve the exact old decision at a range boundary.
end
valid=a<=c.v8.maximumCalibratedAmplitude;ratio=ones(2,1);
use=valid&magnitude>1e-12;ratio(use)=a(use)./magnitude(use);d=d.*ratio;
y=[real(d);imag(d)];
if c.iqFractionBits>0
 y=max(-8,min(8-2^-c.iqFractionBits,round(y*2^c.iqFractionBits)/2^c.iqFractionBits));
end
end
