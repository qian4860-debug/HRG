function a3_report()
root=fileparts(mfilename('fullpath'));scores=jsondecode(fileread(fullfile(root,'evidence','scores.json')));
mc=jsondecode(fileread(fullfile(root,'evidence','matlab_noise_scoreboard.json')));
f=figure('Visible','off','Position',[50 50 1550 1000]);tiledlayout(2,3);
rows=scores.cases;long=rows([rows.window_samples]==240);
nexttile;bar(100*[[long.cauchy_valid_fraction]' [long.joint_valid_fraction]']);grid on;ylim([0 110]);
xlabel('工况编号');ylabel('含固定等待的稳态发布比例 [%]');title('同一滤波/延迟/原点，减少保守拒绝');legend('Cauchy标准差和','联合协方差','Location','best');
nexttile;a=readmatrix(fullfile(root,'evidence','window_240','case_005_frames.csv'));a=a(a(:,1)>=.27,:);
plot(a(:,2),a(:,12),a(:,2),a(:,11));hold on;yline(.003,'r--');grid on;
xlabel('源中心时间 [s]');ylabel('3σ + 角点敏感度 [rad]');title('500 μV：预算改变，角度样本未额外降噪');legend('标准差和','联合协方差','调试预算','Location','best');
nexttile;b=readmatrix(fullfile(root,'evidence','window_240','case_016_frames.csv'));c=readmatrix(fullfile(root,'evidence','window_240','case_017_frames.csv'));
stairs(b(:,1),b(:,6));hold on;stairs(c(:,1),c(:,6));stairs(c(:,1),c(:,19));grid on;ylim([-.1 1.2]);
xlabel('发布时间 [s]');title('短缺测恢复；长缺测需外部参考');legend('短缺测发布','长缺测发布','长缺测锁存失效','Location','best');
nexttile;plot(b(:,2),b(:,4),c(:,2),c(:,4),c(:,2),c(:,20),'--');grid on;
xlabel('源中心时间 [s]');ylabel('角度增量 [rad]');title('新局部段不能冒充全局连续角');legend('短缺测全局角','长缺测全局角','长缺测局部诊断','Location','best');
nexttile;lags=[1 6 20 100 200];
semilogx(lags,mc.cases(1).relative_variance_observed_to_predicted,'o-',lags,mc.cases(2).relative_variance_observed_to_predicted,'s-');hold on;yline(1,'--');grid on;ylim([.8 1.2]);
xlabel('距原始参考的时间 [ms]');ylabel('实测方差 / 预测方差');title('独立MATLAB白噪声线性试验，512次');legend('40点/级','240点/级','理论1','Location','best');
nexttile;selected=long([long.noise_RMS_V]==500e-6 & ismember({long.fault_kind},{'none','fresh_noise_seed'}));
values=[[selected.all_observable_candidate_RMS_rad]' [selected.published_RMS_rad]'];bar(1000*values);hold on;yline(3,'r--');grid on;
xlabel('500 μV的五个噪声种子');ylabel('角度误差RMS [mrad]');title('全候选与已发布都报告；非硬件精度');legend('全部可观测候选','已发布','调试预算','Location','best');
sgtitle('A3 共同原点协方差与参考管理｜白噪/冻结W/声明运动界｜未接完整控制闭环');
exportgraphics(f,fullfile(root,'evidence','a3_dashboard.png'),'Resolution',140);close(f);
end
