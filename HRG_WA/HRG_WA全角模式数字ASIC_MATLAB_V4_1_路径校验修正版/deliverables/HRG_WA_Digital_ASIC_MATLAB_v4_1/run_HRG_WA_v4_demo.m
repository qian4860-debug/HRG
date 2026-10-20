clear; % 清除工作区变量，避免旧参数污染本次仿真。
clc; % 清空命令窗口，便于查看本次指标输出。
close all; % 关闭旧图窗，避免曲线混淆。
user = HRG_WA_v4_user_config(); % 加载用户可编辑的物理量、接口、控制器和回归判据表头。
p = HRG_WA_v4_params(user); % 把用户表头转换为仿真器内部统一参数、单位和函数句柄。
fprintf('模型修订=%s\n', p.meta.revision); % 打印明确维护版本以便确认MATLAB没有调用旧路径文件。
[~, tuning] = HRG_WA_v4_autotune(p, false); % 计算当前物理量对应的控制器解析初值但不自动覆盖人工参数。
result = HRG_WA_v4_simulate(p); % 运行多速率闭环行为仿真。
m = result.metrics; % 取得性能指标结构体。
fprintf('功能通过=%d，性能回归通过=%d，锁定=%d，故障=%d，锁定时间=%.4f s\n', m.passFunctional, m.passPerformance, m.locked, m.faulted, m.lockTime); % 打印分层通过结论与闭环状态。
fprintf('角度RMS误差=%.6f deg，最终角度误差=%.6f deg\n', m.rmsAngleErrorDeg, m.finalAngleErrorDeg); % 打印角度误差指标。
fprintf('角速度RMS误差=%.6f deg/s，最大误差=%.6f deg/s\n', m.rmsRateErrorDps, m.maxRateErrorDps); % 打印角速度误差指标。
fprintf('能量均值=%.6f，Q均方根=%.6g，相位误差RMS=%.6g\n', m.energyMean, m.quadRms, m.phaseErrorRms); % 打印能量、正交和相位环指标。
fprintf('ADC饱和=%d，DAC饱和=%d，真实定点溢出=%d，展开异常=%d\n', m.adcSaturationCount, m.dacSaturationCount, m.fixedOverflowCount, m.unwrapFaultCount); % 打印模拟接口、真实定点数据通路和展开诊断计数。
fprintf('DPLL限幅=%d，PI积分限幅=%d，控制输出限幅=%d\n', m.pllLimitCount, m.piIntegratorLimitCount, m.controlOutputLimitCount); % 打印与真实定点溢出分离的正常控制限幅计数。
if m.faulted % 判断本次仿真是否进入FAULT状态。
    fprintf('首次故障时间=%.6f s，FAULT安全输出=%d\n', m.faultTime, m.faultOutputsSafe); % 打印故障进入时刻和三路数字控制字安全归零结论。
end % 结束故障诊断输出判断。
fprintf('建议增益：PLL Kp=%.5g Ki=%.5g，E环 Kp=%.5g Ki=%.5g，Q环 Kp=%.5g Ki=%.5g\n', tuning.pllKpHz, tuning.pllKiHz, tuning.energyKp, tuning.energyKi, tuning.quadKp, tuning.quadKi); % 打印由当前物理量和目标自然频率推导的控制器初值。
save('HRG_WA_v4_result.mat', 'result'); % 保存完整MATLAB行为级结果。
HRG_WA_v4_export_vectors(result, 'HRG_WA_v4_vectors.csv'); % 导出面向RTL逐拍对比的CSV向量。
if p.sim.makePlots % 判断是否需要生成演示图。
    runIndex = find(result.log.mode == 3, 1, 'first'); % 查找首次进入RUN的样本以统一导航角和参考角的零点。
    if isempty(runIndex) % 判断本次仿真是否未能进入RUN。
        runIndex = 1; % 未锁定时保留原始输入积分角作为诊断参考。
    end % 结束绘图参考零点判断。
    angleReferencePlot = result.log.inputAngle - result.log.inputAngle(runIndex); % 构造与RUN清零动作一致的参考输入角曲线。
    figure('Color', 'w', 'Position', [80 80 1200 820]); % 创建白色背景的汇总图窗。
    subplot(3, 2, 1); % 选择角度对比子图。
    plot(result.log.t, angleReferencePlot * 180 / pi, '--', result.log.t, result.log.angleOutput * 180 / pi, 'LineWidth', 1.0); % 绘制采用相同RUN零点的参考角度与ASIC输出角度。
    grid on; % 打开角度子图网格。
    xlabel('时间 / s'); % 设置角度子图横轴标签。
    ylabel('角度 / deg'); % 设置角度子图纵轴标签。
    legend('输入积分角', 'ASIC输出角', 'Location', 'best'); % 添加角度子图图例。
    subplot(3, 2, 2); % 选择角速度对比子图。
    plot(result.log.t, result.log.inputRate * 180 / pi, '--', result.log.t, result.log.rateOutput * 180 / pi, 'LineWidth', 1.0); % 绘制输入角速度与ASIC输出角速度。
    grid on; % 打开角速度子图网格。
    xlabel('时间 / s'); % 设置角速度子图横轴标签。
    ylabel('角速度 / (deg/s)'); % 设置角速度子图纵轴标签。
    legend('输入角速度', 'ASIC输出角速度', 'Location', 'best'); % 添加角速度子图图例。
    subplot(3, 2, 3); % 选择能量与正交子图。
    plot(result.log.t, result.log.E, result.log.t, result.log.Q, 'LineWidth', 1.0); % 绘制数字解调能量与正交量。
    grid on; % 打开能量与正交子图网格。
    xlabel('时间 / s'); % 设置能量与正交子图横轴标签。
    ylabel('归一化不变量'); % 设置能量与正交子图纵轴标签。
    legend('E', 'Q', 'Location', 'best'); % 添加能量与正交子图图例。
    subplot(3, 2, 4); % 选择频率相位环子图。
    yyaxis left; % 激活左侧纵轴。
    plot(result.log.t, result.log.phaseError, 'LineWidth', 1.0); % 绘制归一化频率相位误差。
    ylabel('相位误差'); % 设置左侧纵轴标签。
    yyaxis right; % 激活右侧纵轴。
    plot(result.log.t, result.log.ncoFrequencyHz, 'LineWidth', 1.0); % 绘制NCO频率控制字。
    ylabel('NCO频率 / Hz'); % 设置右侧纵轴标签。
    grid on; % 打开频率相位环子图网格。
    xlabel('时间 / s'); % 设置频率相位环子图横轴标签。
    subplot(3, 2, 5); % 选择控制命令子图。
    plot(result.log.t, result.log.energyCmd, result.log.t, result.log.quadCmd, 'LineWidth', 1.0); % 绘制能量与正交数字控制字。
    grid on; % 打开控制命令子图网格。
    xlabel('时间 / s'); % 设置控制命令子图横轴标签。
    ylabel('控制字等效值'); % 设置控制命令子图纵轴标签。
    legend('能量控制', '正交控制', 'Location', 'best'); % 添加控制命令子图图例。
    subplot(3, 2, 6); % 选择状态机与温度子图。
    yyaxis left; % 激活状态机左侧纵轴。
    stairs(result.log.t, result.log.mode, 'LineWidth', 1.0); % 绘制状态机随时间的变化。
    ylabel('状态机编码'); % 设置状态机纵轴标签。
    yyaxis right; % 激活温度右侧纵轴。
    plot(result.log.t, result.log.temperature, 'LineWidth', 1.0); % 绘制环境温度曲线。
    ylabel('温度 / ℃'); % 设置温度纵轴标签。
    grid on; % 打开状态与温度子图网格。
    xlabel('时间 / s'); % 设置状态与温度子图横轴标签。
    exportgraphics(gcf, 'HRG_WA_v4_summary.png', 'Resolution', 160); % 将汇总图导出为PNG文件。
end % 结束绘图判断。
