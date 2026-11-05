function d=a4_observe(s,p)
% 只读旧状态，不更新控制器；列定义沿用sn_tick。
t=s.k*p.Ts;age=t-s.available;valid=s.valid&&s.id>0&&age>=-p.Ts*1e-6&&age<=p.max_frame_age;
d=[s.I;s.Q;s.freq;s.energy;s.linearity;double(valid);s.id;s.frame_start;s.frame_end;s.center;s.available;...
 s.sat;s.frame_clip;s.cp;age;s.frame_dac_clip;s.iq_history(:,1);s.raw_valid];
end
