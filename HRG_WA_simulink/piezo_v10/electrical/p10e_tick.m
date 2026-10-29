function [s,u,d]=p10e_tick(s,y,p,H)
if isempty(s)
 s=struct('phase',0,'freq',2*pi*p.f0,'sumI',zeros(2,1),'sumQ',zeros(2,1),'count',0,...
 'Vc',zeros(2,1),'Vs',zeros(2,1),'integ',0,'I',[.3*p.charge_target_C;0],'Q',zeros(2,1),'sat',0);
end
pd=atan(2*pi*p.f0*p.driver_tau);raw=s.Vc*cos(s.phase+pd)+s.Vs*sin(s.phase+pd);
s.sat=s.sat+any(abs(raw)>p.vmax);lsb=p.dac_span/2^p.dac_bits;
u=round(max(-p.vmax,min(p.vmax,raw))/lsb)*lsb;d=[s.I;s.Q;s.freq;norm(s.I);s.sat];
s.sumI=s.sumI+2*y*cos(s.phase);s.sumQ=s.sumQ+2*y*sin(s.phase);s.count=s.count+1;
if s.count==round(p.Tc/p.Ts)
 z=(s.sumI-1i*s.sumQ)/s.count/H;if p.calibrate,z(2)=z(2)/p.gain_y;end
 s.I=real(z);s.Q=-imag(z);amp=sqrt(s.I'*s.I+s.Q'*s.Q);err=p.charge_target_C-amp;
 e=s.I/max(norm(s.I),p.charge_target_C*1e-5);wn=2*pi*p.agc_bw;scale=2*(2*pi*p.f0)/p.b;
 kp=scale*(1.6*wn-p.gamma);ki=scale*wn^2;ff=scale*p.gamma*p.charge_target_C;
 v=ff+kp*err+ki*s.integ;lim=.7*p.vmax;
 if abs(v)<lim||sign(v)~=sign(err),s.integ=s.integ+p.Tc*err;end
 s.Vs=-max(-lim,min(lim,ff+kp*err+ki*s.integ))*e;
 s.Vc=-scale*2*pi*p.quad_bw*(s.Q-e*(e'*s.Q));
 phaseError=s.I'*s.Q/max(amp^2,p.charge_target_C^2*1e-4);
 s.freq=2*pi*p.f0+max(-p.max_detune,min(p.max_detune,-p.pll_gain*phaseError));
 s.sumI(:)=0;s.sumQ(:)=0;s.count=0;
end
s.phase=mod(s.phase+s.freq*p.Ts,2*pi);
end
