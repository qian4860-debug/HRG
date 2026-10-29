function [s,u,diag]=p10_tick(s,y,p,H)
% Outputs first, then state update: no instantaneous control feedthrough.
if isempty(s)
 s=struct('phase',0,'freq',2*pi*p.f0,'sumI',zeros(2,1),'sumQ',zeros(2,1),...
 'count',0,'Fc',zeros(2,1),'Fs',zeros(2,1),'integ',0,'I',[p.initial_amp;0],...
 'Q',zeros(2,1),'sat',0);
end
% Compensate common driver phase with carrier rotation (not a truth angle).
pd=atan(2*pi*p.f0*p.driver_tau);
u=(s.Fc*cos(s.phase+pd)+s.Fs*sin(s.phase+pd))/p.theta_d;
if p.compensate_drive,u(2)=u(2)/p.drive_y;end
s.sat=s.sat+any(abs(u)>p.vmax);
u=max(-p.vmax,min(p.vmax,u));lsb=p.dac_span/2^p.dac_bits;u=round(u/lsb)*lsb;
diag=[s.I;s.Q;s.freq;norm(s.I);s.sat];
s.sumI=s.sumI+2*y*cos(s.phase);s.sumQ=s.sumQ+2*y*sin(s.phase);s.count=s.count+1;
if s.count==round(p.Tc/p.Ts)
 z=(s.sumI-1i*s.sumQ)/s.count;
 if p.calibrate,z=z./[H;H*p.gain_y];else,z=z/H;end
 s.I=real(z);s.Q=-imag(z);aa=sqrt(s.I'*s.I+s.Q'*s.Q);
 e=s.I/max(norm(s.I),p.amp*1e-5);err=p.amp-aa;
 wn=2*pi*p.agc_bw;gam=pi*p.f0/p.Q;
 kp=2*p.mass*2*pi*p.f0*(2*.8*wn-gam);ki=2*p.mass*2*pi*p.f0*wn^2;
 ff=2*p.mass*2*pi*p.f0*gam*p.amp;
 raw=ff+kp*err+ki*s.integ;limit=p.theta_d*p.vmax*.7;
 % Conditional integration includes the force limiter, not just DAC clipping.
 if abs(raw)<limit || sign(err)~=sign(raw),s.integ=s.integ+p.Tc*err;end
 fr=max(-limit,min(limit,ff+kp*err+ki*s.integ));
 s.Fs=-fr*e;
 s.Fc=-2*p.mass*2*pi*p.f0*(2*pi*p.quad_bw)*(s.Q-e*(e'*s.Q));
 detector=(s.I'*s.Q)/max(aa^2,p.amp^2*1e-4);
 s.freq=2*pi*p.f0+max(-p.max_detune,min(p.max_detune,-p.pll_gain*detector));
 s.sumI(:)=0;s.sumQ(:)=0;s.count=0;
end
s.phase=mod(s.phase+s.freq*p.Ts,2*pi);
end
