function x=comp_state(action,arg)
% 控制状态的35维数值打包/解包，供Simulink DWork保存。
% 1相位；2角频率；3:4/5:6混频累加；7窗口点数；8:9 Fc；10:11 Fs。
% 12建幅积分；13:14 I；15:16 Q；17截幅累计；18拍号；19窗口起点；20时间和。
% 21:24窗口start/end/center/available；25能量；26线性度；27有效；28帧号。
% 29窗口ADC截幅；30上一帧ADC截幅；31已施加Cp；32窗口有限性。
% 33上一帧DAC截幅；34窗口DAC截幅；35模态方向估计率。
% 初始化IQ为零且无效，时间戳NaN；启动驱动沿固定X方向，不偷用真值方向。
% Numeric packing is shared by Simulink DWork and MATLAB replay, not physics.
switch action
case 'init'
 p=arg;x=[0;2*pi*p.f0;zeros(18,1);NaN(4,1);zeros(11,1)];
 % [phase freq sumI2 sumQ2 count Fc2 Fs2 integ I2 Q2 sat k start sumt
 %  frame_start frame_end frame_center frame_available E linearity valid id
 %  window_clip frame_clip cp_applied finite_window frame_dac_clip window_dac_clip heading_rate] (35).
 x(8:9)=0;x(10:11)=-2*(2*pi*p.f0)*p.gamma_intrinsic*p.charge_target*[1;0];
 if p.zero_start_force,x(8:11)=0;end
 x(32)=1;
case 'unpack'
 v=arg;x=struct('phase',v(1),'freq',v(2),'sumI',v(3:4),'sumQ',v(5:6),...
 'count',v(7),'Fc',v(8:9),'Fs',v(10:11),'integ',v(12),'I',v(13:14),'Q',v(15:16),...
 'sat',v(17),'k',v(18),'start',v(19),'sumt',v(20),'frame_start',v(21),...
 'frame_end',v(22),'center',v(23),'available',v(24),'energy',v(25),...
 'linearity',v(26),'valid',v(27),'id',v(28),'window_clip',v(29),...
 'frame_clip',v(30),'cp',v(31),'finite_window',v(32),'frame_dac_clip',v(33),'window_dac_clip',v(34),'heading_rate',v(35));
case 'pack'
 s=arg;x=[s.phase;s.freq;s.sumI;s.sumQ;s.count;s.Fc;s.Fs;s.integ;s.I;s.Q;...
 s.sat;s.k;s.start;s.sumt;s.frame_start;s.frame_end;s.center;s.available;s.energy;...
 s.linearity;s.valid;s.id;s.window_clip;s.frame_clip;s.cp;s.finite_window;s.frame_dac_clip;s.window_dac_clip;s.heading_rate];
otherwise,error('p101:state','Unknown action');
end
end
