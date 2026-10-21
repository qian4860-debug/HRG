function y=wl_env_drive(u,c)
h=u(1:2)+1i*u(3:4);psi=u(5);s=1i*2*pi*c.head.f0;
forceGain=c.driveNPerV/(c.massKg*c.displacementM);hToV=2*imag(s)/forceGain;
v=[real(h);imag(h)]*hToV;
v=wl_quantize(v,c.dacBits,c.dacFsV,c.dacInlCubic);
h=(v(1:2)+1i*v(3:4))/hToV;
a=pi*c.head.f0/c.fsAdc;
H=sin(a)/a*exp(-s*(c.dacDelay+.5)/c.fsAdc);
if c.circuitEnable,H=H/(1+s/(2*pi*c.driverBandwidthHz));end
h=diag(c.driverGain)*c.head.drive*h*H*exp(1i*psi);
y=[real(h);imag(h)];
end
