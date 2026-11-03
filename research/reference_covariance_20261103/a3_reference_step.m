function [s,out]=a3_reference_step(state,frame,p,reanchor)
% 独立MATLAB状态机；全局原点不随局部重锚定改变。
% s: started,lost,last_angle,last_time,tracked,origin,anchor,offset,
%    anchor_time,count,segment,local_origin,reference_time。
s=state(:);frame=frame(:);t=frame(1);angle=frame(2);healthy=logical(frame(3));quality=frame(4);latency=logical(frame(5));
event=0;global_angle=NaN;local=NaN;
if healthy && t>=p.warmup_s
 if s(1)==0
  s=[1;0;angle;t;angle;angle;angle;0;t;1;0;angle;t];event=1;
 else
  dt=t-s(4);assert(dt>=0);radius=p.maximum_modal_direction_rate_rad_s*dt+p.phase_uncertainty_margin_rad;
  delta=.5*atan2(sin(2*(angle-s(3))),cos(2*(angle-s(3))));
  if radius>=pi/2 || abs(delta)>radius
   s(2)=1;s(11)=s(11)+1;s(5)=angle;s(12)=angle;
  else
   s(5)=s(5)+delta;
  end
  s(3)=angle;s(4)=t;
 end
 local=s(5)-s(12);
 if ~s(2)
  global_angle=s(8)+s(5)-s(7);
  if reanchor && t-s(9)>=p.reanchor_period_s-1e-12 && t-s(13)>=p.reference_holdoff_s
   s(8)=global_angle;s(7)=s(5);s(9)=t;s(10)=s(10)+1;event=1;
  end
  global_angle=s(8)+s(5)-s(7);
 end
end
ready=s(1) && ~s(2) && healthy && t-s(13)>=p.reference_holdoff_s-1e-12;
valid=ready && latency && isfinite(quality) && quality<=p.angle_budget_rad;
published=NaN;if valid,published=global_angle;end
out=[global_angle;published;double(valid);s(10);s(2);s(11);local;event;double(s(1)&&~s(2))];
end
