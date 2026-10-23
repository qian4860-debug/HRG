function y=w8_env_sense(u,c)
% Third-order ELECTRODE fundamental before linear AFE; excludes RF harmonics.
z=u(1:2)+1i*u(3:4);psi=u(5);s=2i*pi*c.head.f0;
d=c.head.detect*z;
if c.circuitEnable
 d=d.*(1+.75*(c.displacementM/c.gapM)^2*abs(d).^2);
 H=(s*c.rfOhm*c.cfF)/(1+s*c.rfOhm*c.cfF);
 H=H/(1+s/(2*pi*c.cvBandwidthHz))/(1+s/(2*pi*c.pgaBandwidthHz))/(1+s/(2*pi*c.antiAliasHz));
else,H=1;end
H=H*exp(-s*c.adcDelay/c.fsAdc);
d=diag(c.adcGain)*d*H*exp(-1i*psi);y=[real(d);imag(d)];
end
