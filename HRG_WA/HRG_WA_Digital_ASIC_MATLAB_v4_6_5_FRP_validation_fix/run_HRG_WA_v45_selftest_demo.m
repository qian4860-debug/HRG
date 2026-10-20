function result = run_HRG_WA_v45_selftest_demo(forceFailure) % 演示真实检测链路SELFTEST通过或检测不到测试载波时的安全失败路径。
if nargin < 1 % 判断调用者是否指定强制失败演示选项。
    forceFailure = false; % 默认执行正常测试载波注入和SELFTEST通过演示。
end % 结束SELFTEST演示选项判断。
user = HRG_WA_v45_user_config(); % 加载V4.2集中式用户参数表头。
user.sim.duration = 5.0; % 设置足够覆盖锁定、SELFTEST和返回RUN或FAULT的演示时长。
user.input.rateTransitionTimesSec = []; % 清除动态角速度切换时刻以提高同步相关可观测性。
user.input.rateLevelsDps = 0; % 把外部真实角速度设置为零。
user.selftest.enable = true; % 使能运行中真实检测链路SELFTEST。
user.selftest.startTime = 3.0; % 在完成闭环锁定后触发SELFTEST。
user.selftest.injectionScale = double(~forceFailure); % 正常演示使用完整受限注入，失败演示阻断测试载波但不直接篡改结果位。
p = HRG_WA_v45_params(user); % 把SELFTEST演示表头转换为完整内部参数结构体。
result = HRG_WA_v45_simulate(p); % 运行包含STARTUP、ACQUIRE、RUN、SELFTEST和返回或FAULT的闭环仿真。
m = result.metrics; % 读取SELFTEST演示的分层性能和安全指标。
fprintf('SELFTEST完成=%d，通过=%d，失败=%d，故障=%d，增益=%.6g，正交残差比例=%.6g\n', m.selftestExecuted, m.selftestPassed, m.selftestFailed, m.faulted, m.selftestGainEstimate, m.selftestQuadratureRatio); % 打印真实检测链路SELFTEST判定摘要。
if forceFailure % 判断当前是否执行检测不到测试载波的失败演示。
    assert(m.passSelftestFailureSafety, 'SELFTEST失败演示未能进入FAULT并安全归零。'); % 要求失败路径锁存故障且三路控制输出安全归零。
else % 处理正常测试载波注入演示。
    assert(m.passSelftest, 'SELFTEST正常演示未通过增益或正交响应判据。'); % 要求SELFTEST完成、判定通过并返回RUN。
end % 结束SELFTEST演示结果断言选择。
save('HRG_WA_v45_selftest_result.mat', 'result', 'forceFailure'); % 保存SELFTEST完整日志、参数和演示选项。
figure('Color', 'w', 'Position', [140 140 1050 650]); % 创建白色背景的SELFTEST三联诊断图。
subplot(3, 1, 1); % 选择状态机与SELFTEST标志子图。
stairs(result.log.t, result.log.mode, 'LineWidth', 1.1); % 绘制状态机编码随时间的变化。
hold on; % 保持当前坐标轴以叠加SELFTEST活动标志。
plot(result.log.t, 4 + double(result.log.selftestActive), 'LineWidth', 1.0); % 在状态机图中叠加SELFTEST活动标志。
grid on; % 打开状态机子图网格。
ylabel('状态/自检'); % 设置状态机子图纵轴标签。
legend('mode', '4+selftestActive', 'Location', 'best'); % 添加状态机与SELFTEST活动图例。
subplot(3, 1, 2); % 选择两路同相解调量子图。
plot(result.log.t, result.log.Cx, result.log.t, result.log.Cy, 'LineWidth', 1.0); % 绘制测试载波经过AFE、ADC和NCO解调后的Cx与Cy响应。
grid on; % 打开解调响应子图网格。
ylabel('解调量'); % 设置解调响应子图纵轴标签。
legend('Cx', 'Cy', 'Location', 'best'); % 添加两路解调响应图例。
subplot(3, 1, 3); % 选择SELFTEST结果子图。
plot(result.log.t, result.log.selftestGainEstimate, result.log.t, result.log.selftestQuadratureRatio, 'LineWidth', 1.0); % 绘制SELFTEST完成后锁存的估计增益和正交残差比例。
grid on; % 打开SELFTEST结果子图网格。
xlabel('时间 / s'); % 设置SELFTEST结果子图横轴标签。
ylabel('归一化结果'); % 设置SELFTEST结果子图纵轴标签。
legend('估计增益', '正交残差比例', 'Location', 'best'); % 添加SELFTEST结果图例。
exportgraphics(gcf, 'HRG_WA_v45_selftest_summary.png', 'Resolution', 160); % 把SELFTEST三联诊断图导出为PNG文件。
end % 结束真实检测链路SELFTEST演示函数。
