function y=w8_iq(u,c)
% Frozen calibration precedes BOTH navigation invariants and feedback forces.
d=(u(1:2)+1i*u(3:4))*c.v7.senseCalibration;
if c.v8.enabled
 d=c.v8.senseInverse*d;b=c.v8.cubicCoefficient(:);
 if any(b~=0)
  assert(norm(c.v8.senseInverse-diag(diag(c.v8.senseInverse)),'fro')<1e-12, ...
   'Cubic calibration is validated only for diagonal channels');
  magnitude=abs(d);a=magnitude;
  for k=1:7,a=a-(a+b.*a.^3-magnitude)./(1+3*b.*a.^2);end
  % Outside the certified amplitude range no extrapolated correction is applied.
  valid=a<=c.v8.maximumCalibratedAmplitude;
  ratio=ones(2,1);use=valid&magnitude>1e-12;
  ratio(use)=a(use)./magnitude(use);d=d.*ratio;
 end
end
y=[real(d);imag(d)];
if c.iqFractionBits>0
 y=max(-8,min(8-2^-c.iqFractionBits,round(y*2^c.iqFractionBits)/2^c.iqFractionBits));
end
end
