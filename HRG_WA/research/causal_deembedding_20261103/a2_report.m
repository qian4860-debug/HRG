function a2_report()
% 指标独立显示：发布率、噪声、时间戳、校准检查和相位预算，拒绝项保留。
root=fileparts(mfilename('fullpath'));s=jsondecode(fileread(fullfile(root,'evidence','scores.json')));
cfg=jsondecode(fileread(fullfile(root,'config.json')));e40=jsondecode(fileread(fullfile(root,'evidence','window_40','estimates.json')));
e240=jsondecode(fileread(fullfile(root,'evidence','window_240','estimates.json')));
f=figure('Visible','off','Position',[70 70 1550 1000]);tiledlayout(2,3);
nexttile;rates=[[e40.cases.post_warmup_valid_fraction]' [e240.cases.post_warmup_valid_fraction]'];bar(1:15,100*rates);grid on;
xlabel('工况编号');ylabel('稳态发布帧比例 [%]');title('保留拒绝与部分发布');legend('40点/级','240点/级','Location','best');ylim([0 110]);
nexttile;rows=s.cases;med=zeros(3,2);
for k=1:2
 p={e40,e240};med(:,k)=[p{k}.cases(4:6).median_absolute_angle_sigma_rad]';
end
bar(log10(med));xticklabels({'5 μV','500 μV','1 mV'});ylabel('log10(预测单帧角噪声σ [rad])');title('独立噪声探针 → 数字噪声核');grid on;legend('40点/级','240点/级','Location','best');
nexttile;values=[e40.cases(1).source_delay_s e240.cases(1).source_delay_s];bar(1000*values);yline(1000*cfg.additional_phase_budget_rad/(2*pi*cfg.reference_loop_bandwidth_Hz),'r--');
xticklabels({'40点/级','240点/级'});ylabel('源时间延迟 [ms]');title('5Hz/0.2rad预算为假定值，非实测相位裕量');grid on;
nexttile;short=rows([rows.window_samples]==40);long=rows([rows.window_samples]==240);
errors=1e3*[[short(1:3).available_timestamp_RMS_rad]' [short(1:3).correct_timestamp_RMS_rad]' [long(1:3).available_timestamp_RMS_rad]' [long(1:3).correct_timestamp_RMS_rad]'];
bar(errors,'BaseValue',1e-4);set(gca,'YScale','log');xticklabels({'0.7 rad/s','5 rad/s','0 rad/s'});ylabel('无噪角度RMS [mrad，对数轴]');title('动态3Hz调制：不能用发布时刻代替源时刻');grid on;
legend('短窗未扣延迟','短窗源时刻','长窗未扣延迟','长窗源时刻','Location','best');
nexttile;st=[e40.cases.calibration];semilogy(1:15,max([st.statistic],1e-10),'o-');hold on;yline(st(1).limit,'r--');grid on;
xlabel('工况编号');ylabel('有界误差外的校准残差统计量');title('独立AFE/导纳检查；8、9、10拒绝');
nexttile;fr=readmatrix(fullfile(root,'evidence','window_240','case_005_frames.csv'));fr=fr(fr(:,1)>=cfg.warmup_s,:);
plot(fr(:,4),fr(:,16));hold on;yline(cfg.angle_budget_rad,'r--');plot(fr(fr(:,8)==1,4),fr(fr(:,8)==1,16),'.');grid on;
xlabel('估计源中心时间 [s]');ylabel('3σ相对角上界 + 角点敏感度 [rad]');title('500 μV：仅预算满足的帧发布');legend('逐帧预算占用','调试预算','允许发布','Location','best');
sgtitle('A2 因果前端｜白噪声/独立电路校准/冻结W｜非真实表头或完整控制闭环');
exportgraphics(f,fullfile(root,'evidence','a2_dashboard.png'),'Resolution',140);close(f);
end
