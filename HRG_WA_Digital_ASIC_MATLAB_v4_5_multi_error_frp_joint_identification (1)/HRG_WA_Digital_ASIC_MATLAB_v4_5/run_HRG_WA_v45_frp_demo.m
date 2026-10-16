clear; % 清除工作区变量以避免旧版FRP参数污染演示。
clc; % 清空命令窗口便于阅读联合辨识诊断。
close all; % 关闭旧图窗避免曲线混淆。
u = HRG_WA_v45_user_config(); % 加载V4.5集中式用户参数表头。
u.sim.duration = 28.0; % 设置足以完成正向与反向各一周扫描的仿真时长。
u.input.rateTransitionTimesSec = []; % 清除外部角速度切换时刻。
u.input.rateLevelsDps = 0; % 设置FRP标定期间外部真实角速度为零。
u.env.temperatureStartC = 25; % 设置FRP温扫起始温度。
u.env.temperatureEndC = 37; % 设置FRP温扫结束温度。
u.env.temperatureRampStartSec = 2.0; % 设置FRP温扫开始时刻。
u.frp.enable = true; % 使能V4.5正反转FRP联合辨识。
u.frp.startTime = 2.20; % 在闭环进入RUN后启动FRP序列。
u.frp.forwardDps = 30; % 设置正向FRP平台角速度为每秒三十度。
u.frp.reverseDps = -30; % 设置反向FRP平台角速度为每秒负三十度。
u.frp.dwellSec = 12.0; % 设置每个方向驻留十二秒以覆盖完整圆周。
u.frp.transitionSec = 0.25; % 设置四分之一秒余弦平滑换向时间。
u.frp.cycleCount = 1; % 设置一次正向与一次反向完整循环。
u.frp.rlsLambda = 0.9999; % 延长联合RLS记忆以同时利用正向和反向整周数据。
u.afe.crossMatrix = [1.012 0.008; -0.006 0.988]; % 注入检测增益不一致和串扰。
u.afe.assemblyAngleDeg = 0.35; % 注入检测电极装配角误差。
u.afe.phaseDelayDeg = [0.25; -0.18]; % 注入两检测通道独立相位延迟。
u.afe.gainTempCoeff = [100; -80] * 1e-6; % 注入检测增益温度系数。
u.afe.phaseTempCoeffRad = [25; -20] * 1e-6; % 注入检测相位温度系数。
u.afe.quadraticNonlinearity = [0.0010; -0.0008]; % 注入检测二次非线性。
u.afe.cubicNonlinearity = [0.0005; -0.0004]; % 注入检测三次非线性。
u.drive.crossMatrix = [1.006 0.004; -0.003 0.994]; % 注入驱动增益不一致和串扰。
u.drive.assemblyAngleDeg = 0.20; % 注入驱动电极装配角误差。
u.drive.phaseDelayDeg = 0.25; % 注入驱动等效相位延迟。
u.drive.gainTempCoeff = [60; -50] * 1e-6; % 注入驱动增益温度系数。
u.drive.phaseTempCoeffRad = 15e-6; % 注入驱动相位温度系数。
p = HRG_WA_v45_params(u); % 完成单位转换、递归覆盖和参数一致性检查。
p.frp.confidenceThreshold = 0.20; % 为有限二十八秒演示设置可达的补偿释放可信门限。
p.test.minimumFrpConfidence = 0.15; % 为有限记录设置FRP专用回归可信门限。
p.test.maxAngleRmsDeg = 12.0; % 放宽标定过程角度RMS显示包络。
p.test.maxRateRmsDps = 10.0; % 放宽标定过程角速度RMS显示包络。
p.test.maxRateErrorDps = 50.0; % 放宽平滑换向附近最大角速度误差包络。
result = HRG_WA_v45_simulate(p); % 运行V4.5多误差FRP联合辨识行为仿真。
m = result.metrics; % 读取联合辨识与闭环性能指标。
fprintf('V4.5 FRP通过=%d，功能=%d，性能=%d，锁定=%.4fs，故障=%d\n', m.passFrpJointIdentification, m.passFunctional, m.passPerformance, m.lockTime, m.faulted); % 打印分层通过结论。
fprintf('更新=%d，正向=%d，反向=%d，换向门控=%d，覆盖率=%.6f，条件数=%.6g，可信度=%.6f\n', m.frpUpdateCount, m.frpForwardCount, m.frpReverseCount, m.frpTransitionCount, m.frpCoverageFraction, m.frpConditionNumber, m.frpConfidence); % 打印方向、覆盖、数值条件和可信度。
fprintf('残差RMS=%.6g deg/s，换向峰值=%.6g deg/s，可信后样本=%d，补偿已释放=%d，补偿权重=%.6f，最大补偿=%.6g deg/s\n', m.frpResidualRmsDps, m.frpTransitionPeakDps, m.frpTrustedSampleCount, m.frpCompensationReleased, m.frpCompensationAlpha, m.frpCorrectionMaxDps); % 打印残差、独立换向瞬态与补偿安全释放结果。
fprintf('联合参数[bias s4 c4 s8 c8 dir]=[%s] deg/s，温度=%.6g deg/s/C\n', sprintf(' %.6g', m.frpParameterHatDps), m.frpTemperatureHatDpsPerC); % 打印四八次、方向不对称和温度联合估计参数。
save('HRG_WA_v45_frp_result.mat', 'result'); % 保存完整FRP联合辨识结果用于离线复盘。
figure('Color', 'w', 'Position', [80 80 1200 820]); % 创建FRP联合辨识六子图诊断窗口。
subplot(3, 2, 1); % 选择FRP命令与方向子图。
plot(result.log.t, result.log.virtualCmd * 180 / pi, result.log.t, 30 * result.log.frpDirection, '--', 'LineWidth', 1.0); % 绘制FRP虚拟进动命令和稳定平台方向编码。
grid on; % 打开FRP命令子图网格。
xlabel('时间 / s'); % 设置FRP命令子图横轴。
ylabel('FRP / (deg/s)'); % 设置FRP命令子图纵轴。
legend('平滑命令', '稳定方向', 'Location', 'best'); % 添加FRP命令子图图例。
subplot(3, 2, 2); % 选择驻波角覆盖子图。
plot(result.log.t, mod(result.log.thetaEstimate * 180 / pi, 360), 'LineWidth', 1.0); % 绘制零至三百六十度范围的驻波角扫描轨迹。
grid on; % 打开驻波角子图网格。
xlabel('时间 / s'); % 设置驻波角子图横轴。
ylabel('驻波角 / deg'); % 设置驻波角子图纵轴。
subplot(3, 2, 3); % 选择覆盖率与可信度子图。
plot(result.log.t, result.log.frpCoverageFraction, result.log.t, result.log.frpConfidence, 'LineWidth', 1.0); % 绘制覆盖率和综合可信度随时间变化。
grid on; % 打开覆盖率子图网格。
xlabel('时间 / s'); % 设置覆盖率子图横轴。
ylabel('比例'); % 设置覆盖率子图纵轴。
legend('覆盖率', '可信度', 'Location', 'best'); % 添加覆盖率与可信度图例。
subplot(3, 2, 4); % 选择残差与补偿子图。
plot(result.log.t, result.log.frpResidualRmsDps, result.log.t, result.log.frpCorrectionDps, 'LineWidth', 1.0); % 绘制联合辨识残差RMS和受限补偿量。
grid on; % 打开残差与补偿子图网格。
xlabel('时间 / s'); % 设置残差与补偿子图横轴。
ylabel('角速度 / (deg/s)'); % 设置残差与补偿子图纵轴。
legend('残差RMS', '联合补偿', 'Location', 'best'); % 添加残差与补偿图例。
subplot(3, 2, 5); % 选择四八次谐波参数子图。
plot(result.log.t, [result.log.frpSin4HatDps result.log.frpCos4HatDps result.log.frpSin8HatDps result.log.frpCos8HatDps], 'LineWidth', 1.0); % 绘制四次与八次正余弦联合估计系数。
grid on; % 打开谐波参数子图网格。
xlabel('时间 / s'); % 设置谐波参数子图横轴。
ylabel('估计系数 / (deg/s)'); % 设置谐波参数子图纵轴。
legend('sin4', 'cos4', 'sin8', 'cos8', 'Location', 'best'); % 添加谐波参数图例。
subplot(3, 2, 6); % 选择补偿释放权重与条件数子图。
yyaxis left; % 激活左侧补偿权重纵轴。
plot(result.log.t, result.log.frpCompensationAlpha, 'LineWidth', 1.0); % 绘制FRP补偿安全释放权重。
ylabel('补偿权重'); % 设置左侧补偿权重标签。
yyaxis right; % 激活右侧条件数纵轴。
semilogy(result.log.t, max(result.log.frpConditionNumber, 1), 'LineWidth', 1.0); % 以对数纵轴绘制联合参数协方差条件数。
ylabel('条件数'); % 设置右侧条件数标签。
grid on; % 打开补偿权重与条件数子图网格。
xlabel('时间 / s'); % 设置补偿权重与条件数子图横轴。
exportgraphics(gcf, 'HRG_WA_v45_frp_summary.png', 'Resolution', 160); % 导出FRP联合辨识汇总图。
