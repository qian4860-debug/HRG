function y=wl_env_sense(u,c)
% Narrow-band equivalent only. Never use this path to claim ADC/SDM SINAD.
z=u(1:2)+1i*u(3:4);psi=u(5);s=1i*2*pi*c.head.f0;
H=1;
if c.circuitEnable
 H=(s*c.rfOhm*c.cfF)/(1+s*c.rfOhm*c.cfF);
 H=H/(1+s/(2*pi*c.cvBandwidthHz))/(1+s/(2*pi*c.pgaBandwidthHz))/(1+s/(2*pi*c.antiAliasHz));
end
H=H*exp(-s*c.adcDelay/c.fsAdc);
d=c.head.detect*z*H*exp(-1i*psi);
if c.circuitEnable,d=d.*(1+.75*(c.displacementM/c.gapM)^2*abs(d).^2);end
y=[real(d);imag(d)];
end
