function m = HRG_WA_v4_metrics(log, p) % 计算全角HRG数字ASIC的RUN有效窗口性能、故障安全性与分层通过判据。
runIndex = find(log.mode == 3, 1, 'first'); % 查找状态机首次进入RUN的控制拍。
faultIndex = find(log.mode == 6, 1, 'first'); % 查找状态机首次进入FAULT的控制拍。
if isempty(runIndex) % 判断仿真期间是否完成闭环锁定。
    runIndex = numel(log.t); % 未锁定时使用最后一个样本构造安全参考点。
    m.lockTime = NaN; % 用非数值标记锁定时间无效。
else % 处理正常进入RUN的情况。
    m.lockTime = log.t(runIndex); % 记录首次进入RUN的时间。
end % 结束锁定时间判断。
if isempty(faultIndex) % 判断仿真期间是否进入故障态。
    m.faultTime = NaN; % 未发生故障时用非数值标记故障时间无效。
else % 处理已经进入故障态的情况。
    m.faultTime = log.t(faultIndex); % 记录首次进入FAULT的时间。
end % 结束故障时间判断。
valid = log.mode == 3; % 仅选择真正处于RUN状态的样本，自动排除STARTUP、ACQUIRE和FAULT。
valid = valid & log.t >= log.t(runIndex) + p.test.ignoreAfterLock; % 排除锁定后的滤波器和流水线稳定窗口。
for i = 1:numel(p.test.rateTransitionTimes) % 遍历所有外部角速度切换时刻。
    valid = valid & abs(log.t - p.test.rateTransitionTimes(i)) > p.test.ignoreAfterTransition; % 排除速率切换点附近的动态过渡样本。
end % 结束角速度切换窗口排除循环。
if ~any(valid) % 判断严格有效窗口是否仍有可评价样本。
    valid = log.mode == 3; % 在短故障用例中退化为使用全部RUN样本以避免空统计量。
end % 结束有效窗口退化处理。
if ~any(valid) % 判断仿真是否完全没有RUN样本。
    valid(end) = true; % 至少保留最后一个样本以使诊断统计保持有限。
end % 结束无RUN样本保护。
angleReference = log.inputAngle - log.inputAngle(runIndex); % 以进入RUN时刻为零点构造参考输入角度。
angleError = log.angleOutput - angleReference; % 计算数字导航角与参考输入角的误差。
rateError = log.rateOutput - log.inputRate; % 计算低通导航角速度与外部输入角速度的误差。
validIndices = find(valid); % 取得有效性能窗口的样本索引。
m.locked = any(log.mode == 3); % 标记仿真期间是否进入过RUN。
m.faulted = any(log.mode == 6); % 标记仿真期间是否进入过FAULT。
m.validSampleCount = numel(validIndices); % 记录性能统计采用的有效样本数。
m.evaluationStartTime = log.t(validIndices(1)); % 记录有效性能统计窗口起点。
m.evaluationEndTime = log.t(validIndices(end)); % 记录有效性能统计窗口终点。
m.rmsAngleErrorDeg = sqrt(mean(angleError(valid) .^ 2)) * 180 / pi; % 计算有效RUN窗口角度均方根误差，单位为度。
m.finalAngleErrorDeg = angleError(validIndices(end)) * 180 / pi; % 计算有效RUN窗口最后一个样本的角度误差，单位为度。
m.rmsRateErrorDps = sqrt(mean(rateError(valid) .^ 2)) * 180 / pi; % 计算有效RUN窗口角速度均方根误差，单位为度每秒。
m.maxRateErrorDps = max(abs(rateError(valid))) * 180 / pi; % 计算有效RUN窗口最大角速度误差，单位为度每秒。
m.meanRateErrorDps = mean(rateError(valid)) * 180 / pi; % 计算有效RUN窗口角速度平均误差，单位为度每秒。
m.energyMean = mean(log.E(valid)); % 计算有效RUN窗口数字解调能量均值。
m.energyStd = std(log.E(valid)); % 计算有效RUN窗口数字解调能量标准差。
m.energyRelativeError = (m.energyMean - p.res.energyTarget) / max(abs(p.res.energyTarget), eps); % 计算能量均值相对目标值的偏差。
m.quadRms = sqrt(mean(log.Q(valid) .^ 2)); % 计算有效RUN窗口正交量均方根值。
m.phaseErrorRms = sqrt(mean(log.phaseError(valid) .^ 2)); % 计算有效RUN窗口归一化相位误差均方根值。
m.ncoFrequencyMinHz = min(log.ncoFrequencyHz); % 记录整个仿真期间NCO频率控制字最小值。
m.ncoFrequencyMaxHz = max(log.ncoFrequencyHz); % 记录整个仿真期间NCO频率控制字最大值。
m.adcSaturationCount = log.adcSatCount(end); % 记录累计ADC与AFE饱和次数。
m.dacSaturationCount = log.dacSatCount(end); % 记录累计DAC与驱动饱和次数。
m.fixedOverflowCount = log.fixedOverflowCount(end); % 记录累计真实定点数据通路溢出次数。
m.pllLimitCount = log.pllLimitCount(end); % 记录累计DPLL积分器与频率输出限幅次数。
m.piIntegratorLimitCount = log.piIntegratorLimitCount(end); % 记录累计能量与正交PI积分器限幅次数。
m.controlOutputLimitCount = log.controlOutputLimitCount(end); % 记录累计能量与正交控制输出限幅次数。
m.unwrapFaultCount = log.unwrapFaultCount(end); % 记录累计四倍角展开异常次数。
m.allFinite = all(isfinite([log.E; log.Q; log.angleOutput; log.rateOutput; log.rawRate; log.compensatedRate; log.ncoFrequencyHz])); % 检查关键状态和输出是否全部为有限数值。
if isempty(faultIndex) % 判断是否需要检查FAULT状态的安全控制字。
    m.faultOutputsSafe = true; % 未进入FAULT时把安全输出检查标记为不适用但通过。
else % 处理已经进入FAULT的情况。
    faultMask = log.mode == 6; % 选取全部FAULT状态样本。
    safeTolerance = 2 ^ (-p.asic.controlFractionLength); % 使用一个控制字LSB作为零输出判断容差。
    m.faultOutputsSafe = all(abs(log.energyCmd(faultMask)) <= safeTolerance) && all(abs(log.quadCmd(faultMask)) <= safeTolerance) && all(abs(log.virtualCmd(faultMask)) <= safeTolerance); % 检查FAULT状态三路数字控制字是否全部安全归零。
end % 结束FAULT安全输出检查。
m.performanceChecks.lockTime = m.locked && m.lockTime <= p.test.maxLockTime; % 检查锁定时间是否满足回归门限。
m.performanceChecks.angleRms = m.rmsAngleErrorDeg <= p.test.maxAngleRmsDeg; % 检查角度均方根误差是否满足回归门限。
m.performanceChecks.rateRms = m.rmsRateErrorDps <= p.test.maxRateRmsDps; % 检查角速度均方根误差是否满足回归门限。
m.performanceChecks.rateMax = m.maxRateErrorDps <= p.test.maxRateErrorDps; % 检查最大角速度误差是否满足回归门限。
m.performanceChecks.energy = abs(m.energyRelativeError) <= p.test.energyMeanTolerance; % 检查能量均值是否位于允许窗口。
m.performanceChecks.quad = m.quadRms <= p.test.quadRmsMax; % 检查正交量均方根是否满足回归门限。
m.performanceChecks.phase = m.phaseErrorRms <= p.test.phaseErrorRmsMax; % 检查相位误差均方根是否满足回归门限。
m.performanceChecks.adc = ~p.test.requireNoAdcSaturation || m.adcSaturationCount == 0; % 根据配置检查ADC饱和次数。
m.performanceChecks.dac = ~p.test.requireNoDacSaturation || m.dacSaturationCount == 0; % 根据配置检查DAC饱和次数。
m.performanceChecks.fixed = ~p.test.requireNoFixedOverflow || m.fixedOverflowCount == 0; % 根据配置检查真实定点溢出次数。
checkValues = struct2cell(m.performanceChecks); % 把各项性能检查结果转换为逻辑值列表。
m.passFunctional = m.locked && m.allFinite && m.unwrapFaultCount == 0; % 定义与性能无关的基础功能通过判据。
m.passPerformance = m.passFunctional && ~m.faulted && all(cellfun(@(x) logical(x), checkValues)); % 定义无故障标称用例的性能回归通过判据。
m.passFaultSafety = m.locked && m.faulted && m.allFinite && m.faultOutputsSafe; % 定义故障注入用例的安全路径通过判据。
end % 结束性能、诊断与分层通过判据计算函数。
