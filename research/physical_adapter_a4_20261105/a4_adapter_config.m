function a=a4_adapter_config(p,c)
% 合成物理适配：F0为C/s²，VFS为V；不从机械真值取方向或校准。
assert(~p.predict_heading&&~p.enable_tensor_ff&&p.virtual_rate==0,'A4:Unsupported','首轮基线关闭预测/张量/虚拟进动');
assert(abs(c.sample_period_s-p.Ts)<1e-15,'A4:SamplePeriod','采样周期变化必须重新标定');
assert(abs(c.frequency_Hz-p.f0)<1e-10,'A4:Carrier','载波频率变化必须重新标定');
assert(all(isfinite(c.drive(:)))&&cond(c.drive)<100,'A4:Calibration','无效驱动标定');
a.VFS=p.dac_span/2;a.F0=p.b*a.VFS;
assert(a.VFS>0&&a.F0>0&&p.dac_bits==18&&p.vmax==a.VFS,'A4:Scale','需18位双极DAC且vmax=VFS');
a.M=a.F0*(c.drive\eye(2))/a.VFS;
coeff=[reshape(real(a.M)',1,4),reshape(imag(a.M)',1,4)];a.matrix_codes=round(coeff*65536);
assert(all(a.matrix_codes>=-524288&a.matrix_codes<=524287),'A4:MatrixRange','标定矩阵超出D0格式，不得回绕');
a.profile='synthetic_independent_reference_only';a.phase_epoch='s.phase before this sample update';
end
