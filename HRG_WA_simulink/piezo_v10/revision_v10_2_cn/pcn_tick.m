function [s,u,d]=pcn_tick(s,adc,p,c)
% 数字闭环每拍状态机：先输出旧状态对应的u/d，再消费本拍ADC。
% adc=[X电压;Y电压;X截幅;Y截幅]，电压为V。
% 相位为rad，freq字段实际为角频率rad/s，IQ为解嵌后的运动电荷C。
% Fc/Fs为电荷加速度的余弦/正弦系数；复数约定F=Fc-j*Fs。
% 40点窗口完整后才更新IQ与控制；center为输入采样时刻均值。
% available=end+Ts；本拍完成的新结果到下一拍Outputs才发布。
% 算法不读取真值；heading预测只使用相邻有效测量。
% 诊断18列依次为Ix,Iy,Qx,Qy,角频率,E,线性度,有效,id,start,end,center,available,DAC截幅累计,ADC截幅,Cp,帧龄,帧DAC截幅。
% Outputs precede state update. The completed window publishes next sample.
if isempty(s),s=pcn_state('unpack',pcn_state('init',p));end
% 【中文步骤】第一阶段：从旧控制状态生成本拍DAC；不使用尚未解调的新ADC。
t=s.k*p.Ts;F=s.Fc-1i*s.Fs;
if p.predict_heading && s.valid && isfinite(s.center) && t>=p.virtual_start_min_s && abs(sqrt(s.energy)/p.charge_target-1)<p.virtual_settle_fraction
 h=s.heading_rate*max(0,t-s.center);R=[cos(h) -sin(h);sin(h) cos(h)];F=R*F;
end
if p.calibrate_drive,phasor=c.drive\F;else,phasor=F/p.b;end
raw=real(phasor*exp(1i*s.phase));[u,~,dacclip]=pcn_quantize(raw,p.dac_span,p.dac_bits,p.vmax);
% 【中文步骤】判断上一测量帧是否已发布且未过期；valid不等价于算法已达到硬件精度。
age=t-s.available;valid=s.valid && s.id>0 && age>=-p.Ts*1e-6 && age<=p.max_frame_age;
% Diagnostic contract: IQ4,freq,E,linearity,valid,frame_id,start,end,center,
% available,DAC clip count,ADC clip,actual commanded Cp,age,frame DAC clip.
d=[s.I;s.Q;s.freq;s.energy;s.linearity;double(valid);s.id;s.frame_start;...
 s.frame_end;s.center;s.available;s.sat;s.frame_clip;s.cp;age;s.frame_dac_clip];
s.sat=s.sat+any(dacclip);s.window_dac_clip=s.window_dac_clip||any(dacclip);
% 【中文步骤】第二阶段：完整窗口到达，统一更新解调、有效性与慢速控制。
if s.count==0,s.start=t;s.sumt=0;s.finite_window=1;s.window_clip=0;end
y=adc(1:2);finite=all(isfinite(y));s.finite_window=s.finite_window&&finite;
s.window_clip=s.window_clip||any(adc(3:4)~=0);if ~finite,y(:)=0;end
% 【中文步骤】同步混频：乘cos和sin并累加；系数2补偿正弦平均的1/2。
s.sumI=s.sumI+2*y*cos(s.phase);s.sumQ=s.sumQ+2*y*sin(s.phase);
s.sumt=s.sumt+t;s.count=s.count+1;
% 【中文步骤】第二阶段：完整窗口到达，统一更新解调、有效性与慢速控制。
if s.count==round(p.Tc/p.Ts)
% 【中文步骤】z=I-jQ的复相量约定；通过检测矩阵解嵌得到运动电荷。
 z=(s.sumI-1i*s.sumQ)/s.count;
 if p.calibrate_detection,z=c.detect\z;condition=cond(c.detect);else,z=z/c.nominal_detect;condition=1;end
 old=pcn_validity(s.I,s.Q,p,~s.valid,condition);oldcenter=s.center;oldcp=s.cp;
 s.I=real(z);s.Q=-imag(z);q=pcn_validity(s.I,s.Q,p,s.window_clip||s.window_dac_clip||~s.finite_window,condition);
% 【中文步骤】三个时间不能混用：采样末点、窗口中心、下一拍可用时间。
 s.frame_start=s.start;s.frame_end=t;s.center=s.sumt/s.count;s.available=t+p.Ts;
 s.energy=q.energy;s.linearity=q.linearity;s.valid=q.valid;s.id=s.id+1;s.frame_clip=s.window_clip;s.frame_dac_clip=s.window_dac_clip;
 if q.valid
  s.heading_rate=0;
  if old.valid&&s.center>oldcenter
   delta=2*(q.pattern_angle-old.pattern_angle);
   s.heading_rate=atan2(sin(2*delta),cos(2*delta))/2/(s.center-oldcenter);
   s.heading_rate=max(-p.max_heading_rate,min(p.max_heading_rate,s.heading_rate));
  end
% 【中文步骤】建幅PI：用目标电荷减当前幅值，加入本征损耗前馈。
  aa=sqrt(q.energy);e=s.I/max(norm(s.I),p.charge_target*1e-6);err=p.charge_target-aa;
  w=2*pi*p.f0;wn=2*pi*p.agc_bw;kp=2*w*(1.6*wn-p.gamma_intrinsic);ki=2*w*wn^2;
  ff=2*w*p.gamma_intrinsic*p.charge_target;rawf=ff+kp*err+ki*s.integ;
  lim=.6*p.b*p.vmax;
% 【中文步骤】条件积分抗饱和：饱和时仅允许能把控制量拉回范围的积分方向。
  if abs(rawf)<lim||sign(err)~=sign(rawf),s.integ=s.integ+p.Tc*err;end
  fr=max(-lim,min(lim,ff+kp*err+ki*s.integ));
  % Starting a virtual rotation during amplitude acquisition makes commanded
  % Cp differ from achieved Cp because the amplitude estimate is delayed.
  % Gate at a declared settling condition; retain this actual command history.
% 【中文步骤】虚拟进动门控：建幅阶段不施加；保留实际命令供导航扣除。
  s.cp=0;
  if s.center>=p.virtual_start_min_s && abs(aa/p.charge_target-1)<p.virtual_settle_fraction,s.cp=p.virtual_rate;end
  s.heading_rate=s.heading_rate+s.cp-oldcp;
% 【中文步骤】正弦力分量补能并施加切向虚拟进动；余弦分量抑制横向正交。
  s.Fs=-fr*e-2*w*aa*s.cp*[-e(2);e(1)];
  s.Fc=-2*w*2*pi*p.quad_bw*(s.Q-e*(e'*s.Q));
% 【中文步骤】归一化相位检测器驱动角频率修正，并限制最大失谐。
  detector=s.I'*s.Q/max(q.energy,p.charge_target^2*1e-4);
  s.freq=w+max(-p.max_detune,min(p.max_detune,-p.pll_gain*detector));
% 【中文步骤】无效帧时冻结积分、撤去控制力，避免把不可观角当真值继续闭环。
 else
  % Freeze integrator and disable force after a genuinely invalid full frame.
  s.Fc(:)=0;s.Fs(:)=0;s.cp=0;s.heading_rate=0;
 end
 s.count=0;s.sumI(:)=0;s.sumQ(:)=0;s.window_dac_clip=0;
end
% 【中文步骤】最后推进本振和拍号；即使窗口未完成也逐拍推进。
s.phase=mod(s.phase+s.freq*p.Ts,2*pi);s.k=s.k+1;
end
