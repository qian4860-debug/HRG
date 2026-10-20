function m = HRG_WA_v3_metrics(log, p) % 计算全角HRG数字ASIC行为模型的闭环性能与接口诊断指标。
runIndex = find(log.mode == 3, 1, 'first'); % 查找状态机首次进入RUN的采样点。
if isempty(runIndex) % 判断仿真期间是否完成闭环锁定。
    runIndex = numel(log.t); % 未锁定时仅用最后一个采样点构造安全统计区间。
    m.lockTime = NaN; % 用非数值标记锁定时间无效。
else % 处理正常进入RUN的情况。
    m.lockTime = log.t(runIndex); % 记录闭环首次进入RUN的时间。
end % 结束锁定时间判断。
valid = false(size(log.t)); % 初始化性能统计有效掩码。
valid(runIndex:end) = true; % 默认只评价进入RUN后的数据。
for i = 1:numel(p.test.rateTransitionTimes) % 遍历所有输入角速度切换时刻。
    valid = valid & abs(log.t - p.test.rateTransitionTimes(i)) > p.test.ignoreAfterTransition; % 排除切换点附近的滤波过渡样本。
end % 结束切换点排除循环。
if ~any(valid) % 判断是否存在足够的有效性能样本。
    valid(end) = true; % 至少保留最后一个样本避免空数组统计。
end % 结束有效性能样本检查。
angleReference = log.inputAngle - log.inputAngle(runIndex); % 以进入RUN时刻为零点构造参考输入角度。
angleError = log.angleOutput - angleReference; % 计算数字输出角度误差。
rateError = log.rateOutput - log.inputRate; % 计算数字输出角速度误差。
m.locked = any(log.mode == 3); % 标记仿真期间是否进入过RUN状态。
m.faulted = any(log.mode == 6); % 标记仿真期间是否进入过FAULT状态。
m.rmsAngleErrorDeg = sqrt(mean(angleError(valid) .^ 2)) * 180 / pi; % 计算有效区间的角度均方根误差，单位为度。
m.finalAngleErrorDeg = angleError(end) * 180 / pi; % 计算仿真结束时的角度误差，单位为度。
m.rmsRateErrorDps = sqrt(mean(rateError(valid) .^ 2)) * 180 / pi; % 计算有效区间的角速度均方根误差，单位为度每秒。
m.maxRateErrorDps = max(abs(rateError(valid))) * 180 / pi; % 计算有效区间的最大角速度误差，单位为度每秒。
m.energyMean = mean(log.E(valid)); % 计算有效区间的数字解调能量均值。
m.energyStd = std(log.E(valid)); % 计算有效区间的数字解调能量标准差。
m.quadRms = sqrt(mean(log.Q(valid) .^ 2)); % 计算有效区间的正交量均方根值。
m.phaseErrorRms = sqrt(mean(log.phaseError(valid) .^ 2)); % 计算有效区间的归一化相位误差均方根值。
m.ncoFrequencyMinHz = min(log.ncoFrequencyHz); % 记录仿真中NCO频率控制字最小值。
m.ncoFrequencyMaxHz = max(log.ncoFrequencyHz); % 记录仿真中NCO频率控制字最大值。
m.adcSaturationCount = log.adcSatCount(end); % 记录累计ADC与AFE饱和次数。
m.dacSaturationCount = log.dacSatCount(end); % 记录累计DAC与驱动饱和次数。
m.fixedSaturationCount = log.fixedSatCount(end); % 记录累计定点饱和与控制限幅次数。
m.unwrapFaultCount = log.unwrapFaultCount(end); % 记录累计四倍角展开异常次数。
m.allFinite = all(isfinite([log.E; log.Q; log.angleOutput; log.rateOutput; log.ncoFrequencyHz])); % 检查关键数值是否全部有限。
m.passFunctional = m.locked && m.allFinite && m.unwrapFaultCount == 0; % 给出标称功能通过判据。
end % 结束性能指标函数。

