function [s,y]=wz_navigation_tick(t,iq,valid,virtual,s,c)
% Direct geometric angle, separate display-rate smoothing. No plant truth.
% A gap after anchoring loses continuity; restart establishes a NEW relative zero.
if isempty(s),s=zeros(10,1);s(7)=-1;end
valid=logical(valid)&&all(isfinite(iq));inv=wl_invariants(iq);
valid=valid&&inv(5)>c.head.energyThreshold&&hypot(inv(7),inv(8))>c.head.angleThreshold;
phi=atan2(inv(8),inv(7));
if ~valid
 if s(1)>0,s(8)=1;end
elseif s(8)==0
 if s(1)==0
  s(1)=1;s(2)=phi;s(3)=phi/4;s(4)=s(3);s(7)=t;s(9)=virtual;
 else
  delta=atan2(sin(phi-s(2)),cos(phi-s(2)));dt=t-s(7);
  if abs(delta)>=.8*pi || dt>1.5*c.head.Ts || dt<=0
   s(8)=1;
  else
   s(3)=s(3)+delta/4;s(5)=s(5)+s(9)*dt;
   raw=-delta/(4*c.head.bryan*dt)-s(9);
   s(6)=s(6)+(1-exp(-dt/c.head.rateTau))*(raw-s(6));
   s(2)=phi;s(7)=t;s(9)=virtual;s(10)=s(10)+1;
  end
 end
end
valid=valid&&s(1)>0&&s(8)==0;
y=[-(s(3)-s(4))/c.head.bryan-s(5);s(6);double(valid);s(3)];
end
