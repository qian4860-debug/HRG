function [s,u,d]=p101_tick(s,adc,p,c)
% Outputs precede state update. The completed window publishes next sample.
if isempty(s),s=p101_state('unpack',p101_state('init',p));end
t=s.k*p.Ts;F=s.Fc-1i*s.Fs;
if p.calibrate_drive,phasor=c.drive\F;else,phasor=F/p.b;end
raw=real(phasor*exp(1i*s.phase));[u,~,dacclip]=p101_quantize(raw,p.dac_span,p.dac_bits,p.vmax);
age=t-s.available;valid=s.valid && s.id>0 && age>=-p.Ts*1e-6 && age<=p.max_frame_age;
% Diagnostic contract: IQ4,freq,E,linearity,valid,frame_id,start,end,center,
% available,DAC clip count,ADC clip,actual commanded Cp,age,frame DAC clip.
d=[s.I;s.Q;s.freq;s.energy;s.linearity;double(valid);s.id;s.frame_start;...
 s.frame_end;s.center;s.available;s.sat;s.frame_clip;s.cp;age;s.frame_dac_clip];
s.sat=s.sat+any(dacclip);s.window_dac_clip=s.window_dac_clip||any(dacclip);
if s.count==0,s.start=t;s.sumt=0;s.finite_window=1;s.window_clip=0;end
y=adc(1:2);finite=all(isfinite(y));s.finite_window=s.finite_window&&finite;
s.window_clip=s.window_clip||any(adc(3:4)~=0);if ~finite,y(:)=0;end
s.sumI=s.sumI+2*y*cos(s.phase);s.sumQ=s.sumQ+2*y*sin(s.phase);
s.sumt=s.sumt+t;s.count=s.count+1;
if s.count==round(p.Tc/p.Ts)
 z=(s.sumI-1i*s.sumQ)/s.count;
 if p.calibrate_detection,z=c.detect\z;condition=cond(c.detect);else,z=z/c.nominal_detect;condition=1;end
 s.I=real(z);s.Q=-imag(z);q=p101_validity(s.I,s.Q,p,s.window_clip||s.window_dac_clip||~s.finite_window,condition);
 s.frame_start=s.start;s.frame_end=t;s.center=s.sumt/s.count;s.available=t+p.Ts;
 s.energy=q.energy;s.linearity=q.linearity;s.valid=q.valid;s.id=s.id+1;s.frame_clip=s.window_clip;s.frame_dac_clip=s.window_dac_clip;
 if q.valid
  aa=sqrt(q.energy);e=s.I/max(norm(s.I),p.charge_target*1e-6);err=p.charge_target-aa;
  w=2*pi*p.f0;wn=2*pi*p.agc_bw;kp=2*w*(1.6*wn-p.gamma_intrinsic);ki=2*w*wn^2;
  ff=2*w*p.gamma_intrinsic*p.charge_target;rawf=ff+kp*err+ki*s.integ;
  lim=.6*p.b*p.vmax;
  if abs(rawf)<lim||sign(err)~=sign(rawf),s.integ=s.integ+p.Tc*err;end
  fr=max(-lim,min(lim,ff+kp*err+ki*s.integ));
  s.cp=p.virtual_rate;s.Fs=-fr*e-2*w*aa*s.cp*[-e(2);e(1)];
  s.Fc=-2*w*2*pi*p.quad_bw*(s.Q-e*(e'*s.Q));
  detector=s.I'*s.Q/max(q.energy,p.charge_target^2*1e-4);
  s.freq=w+max(-p.max_detune,min(p.max_detune,-p.pll_gain*detector));
 else
  % Freeze integrator and disable force after a genuinely invalid full frame.
  s.Fc(:)=0;s.Fs(:)=0;s.cp=0;
 end
 s.count=0;s.sumI(:)=0;s.sumQ(:)=0;s.window_dac_clip=0;
end
s.phase=mod(s.phase+s.freq*p.Ts,2*pi);s.k=s.k+1;
end
