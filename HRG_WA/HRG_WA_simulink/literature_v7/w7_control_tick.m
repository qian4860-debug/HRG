function y=w7_control_tick(u,c)
% Input invariant10, state17, public virtual rate1. No head truth input.
v=c.v7;Ts=c.head.Ts;d=u(1:2)+1i*u(3:4);E=u(5);st=u(11:27);virtual=u(28);
st(16)=st(16)+1;t=st(16)*Ts;
valid=c.head.loopEnable>0&&E>c.head.energyThreshold&&hypot(u(7),u(8))>c.head.angleThreshold&&all(isfinite(u(1:10)));
phi=atan2(u(8),u(7));
if valid&&st(15)>0
 delta=atan2(sin(phi-st(13)),cos(phi-st(13)));
 if abs(delta)<.8*pi
  target=min(v.resonantMaximumRadS,abs(delta)/Ts);
  st(14)=st(14)+(1-exp(-Ts/v.frequencyEstimateTauS))*(target-st(14));
 end
end
if valid,st(13)=phi;end
st(15)=double(valid);mode=st(17);
if mode==0
 if ~v.startupEnable||E>=v.startupSwitchEnergy,mode=1;
 elseif t>=v.startupTimeoutS,mode=2;end
end
err=[c.head.energyTarget-E;-u(6)/max(E,c.head.energyThreshold);u(10)];
kp=[c.head.energyKp;c.head.quadKp;c.head.pllKp];ki=[c.head.energyKi;c.head.quadKi;c.head.pllKi];
lim=[c.head.energyLimit;c.head.quadLimit;c.head.pllLimitHz];
out=zeros(3,1);raw=out;res=out;
pir=strcmp(v.controlMode,'PIR')&&st(14)>=v.resonantMinimumRadS&&valid&&mode==1;
lambda=-v.resonantLeakRadS+1i*st(14);A=exp(lambda*Ts);B=expm1(lambda*Ts)/lambda;
if mode==1&&valid
 if st(17)==0
  % Do not carry startup force into the steady-state integrator. Start near
  % nominal maintenance and let PI acquire amplitude with limited overshoot.
  st(1)=c.head.gamma-kp(1)*err(1);
 end
 for j=1:3
  k=6+2*j-1;r=st(k)+1i*st(k+1);
  old=r;
  if pir,r=A*r+B*err(j);else,r=exp(-Ts*v.resonantLeakRadS)*r;end
  if pir,res(j)=v.resonantGain(j)*real(r);end
  raw(j)=kp(j)*err(j)+st(j)+res(j);
  clipped=max(-lim(j),min(lim(j),raw(j)));
  slew=v.slewPerS(j)*Ts;out(j)=max(st(3+j)-slew,min(st(3+j)+slew,clipped));
  if c.controlFractionBits>0,out(j)=round(out(j)*2^c.controlFractionBits)/2^c.controlFractionBits;end
  % Freeze resonator input under limiting; leak it down without storing windup.
  if abs(raw(j)-out(j))>1e-10,r=exp(-Ts*v.resonantLeakRadS)*old;end
  st(k)=real(r);st(k+1)=imag(r);
  st(j)=st(j)+Ts*(ki(j)*err(j)+c.head.antiWindup*(out(j)-raw(j)));
 end
 h=out(1)*d+out(2)*1i*[0 -1;1 0]*d-2*c.head.bryan*virtual*[0 -1;1 0]*d;
elseif mode==0&&c.head.loopEnable>0
 h=v.startupAmplitudePerS*[cos(2*v.startupDirectionRad);sin(2*v.startupDirectionRad)];
else
 h=zeros(2,1); % Timeout or invalid feedback cannot silently continue excitation.
end
st(4:6)=out;st(17)=mode;
h=h*c.v7.driveCalibration;
y=[st;real(h);imag(h);out(3);out;mode;double(pir);st(14);res;max(abs(raw-out));double(valid)];
end
