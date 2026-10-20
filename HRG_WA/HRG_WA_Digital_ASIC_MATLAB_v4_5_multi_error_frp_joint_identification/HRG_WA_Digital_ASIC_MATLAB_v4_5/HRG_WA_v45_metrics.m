function m = HRG_WA_v45_metrics(log, p) % 计算全角HRG数字ASIC的RUN有效窗口性能、故障安全性与分层通过判据。
runIndex = find(log.mode == 3, 1, 'first'); % 查找状态机首次进入RUN的控制拍。
faultIndex = find(log.mode == 6, 1, 'first'); % 查找状态机首次进入FAULT的控制拍。
runWasReached = ~isempty(runIndex); % 保存仿真期间是否真实进入过RUN，避免后续安全索引掩盖未锁定事实。
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
valid = log.mode == 3 & ~log.selftestActive; % 仅选择真正处于RUN且本拍没有注入SELFTEST载波的样本，自动排除启动、捕获、自检和故障。
valid = valid & log.t >= log.t(runIndex) + p.test.ignoreAfterLock; % 排除锁定后的滤波器和流水线稳定窗口。
for i = 1:numel(p.test.rateTransitionTimes) % 遍历所有外部角速度切换时刻。
    valid = valid & abs(log.t - p.test.rateTransitionTimes(i)) > p.test.ignoreAfterTransition; % 排除速率切换点附近的动态过渡样本。
end % 结束角速度切换窗口排除循环。
if ~any(valid) % 判断严格有效窗口是否仍有可评价样本。
    valid = log.mode == 3 & ~log.selftestActive; % 在短故障用例中退化为使用全部无SELFTEST注入的RUN样本以避免空统计量。
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
m.finalEnergy = log.E(end); % 记录仿真结束时数字解调能量用于未锁定根因定位。
m.finalQuad = log.Q(end); % 记录仿真结束时数字解调正交量用于未锁定根因定位。
m.finalPhaseError = log.phaseError(end); % 记录仿真结束时归一化相位误差用于未锁定根因定位。
m.energyLockConditionSeen = any(abs(log.E - p.res.energyTarget) <= p.ctrl.energyLockTolerance * p.res.energyTarget); % 检查整个仿真中能量是否曾进入锁定窗口。
m.quadLockConditionSeen = any(abs(log.Q) <= p.ctrl.quadLockTolerance); % 检查整个仿真中正交量是否曾进入锁定窗口。
m.phaseLockConditionSeen = any(log.phaseValid & abs(log.phaseError) <= p.pll.lockPhaseError); % 检查整个仿真中有效DPLL相位是否曾进入锁定窗口。
m.simultaneousLockConditionSeen = any(abs(log.E - p.res.energyTarget) <= p.ctrl.energyLockTolerance * p.res.energyTarget & abs(log.Q) <= p.ctrl.quadLockTolerance & log.phaseValid & abs(log.phaseError) <= p.pll.lockPhaseError); % 检查三个锁定条件是否曾在同一拍同时满足。
m.acquireSampleCount = sum(log.mode == 2); % 统计ACQUIRE状态拍数以识别捕获阶段长期滞留。
m.ncoFrequencyMinHz = min(log.ncoFrequencyHz); % 记录整个仿真期间NCO频率控制字最小值。
m.ncoFrequencyMaxHz = max(log.ncoFrequencyHz); % 记录整个仿真期间NCO频率控制字最大值。
m.adcSaturationCount = log.adcSatCount(end); % 记录累计ADC与AFE饱和次数。
m.dacSaturationCount = log.dacSatCount(end); % 记录累计DAC与驱动饱和次数。
m.fixedOverflowCount = log.fixedOverflowCount(end); % 记录累计真实定点数据通路溢出次数。
m.pllLimitCount = log.pllLimitCount(end); % 记录累计DPLL积分器与频率输出限幅次数。
m.pllFreezeCount = log.pllFreezeCount(end); % 记录累计DPLL因能量或方位矢量无效而冻结的控制拍数。
m.antiWindupCount = log.antiWindupCount(end); % 记录累计DPLL、能量PI与正交PI抗饱和动作次数。
m.piIntegratorLimitCount = log.piIntegratorLimitCount(end); % 记录累计能量与正交PI积分器限幅次数。
m.controlOutputLimitCount = log.controlOutputLimitCount(end); % 记录累计能量与正交控制输出限幅次数。
m.controlSlewLimitCount = log.controlSlewLimitCount(end); % 记录累计能量与正交控制字斜率限制动作次数。
m.actuatorTrackingCount = log.actuatorTrackingCount(end); % 记录累计执行器实际输出和斜率限制跟踪反算动作次数。
m.unwrapFaultCount = log.unwrapFaultCount(end); % 记录累计四倍角展开异常次数。
m.measurementInvalidCount = sum(log.measurementInvalidReason ~= 0); % 统计整个仿真期间幅值、量程、字长或有限数检查未通过的测量拍数。
m.measurementValidFraction = mean(double(log.phaseValid(valid))); % 计算有效RUN性能窗口内允许进入DPLL与Kalman更新的测量样本比例。
m.kalmanUpdateCount = log.kalmanUpdateCount(end); % 记录累计Kalman有效测量更新次数。
m.kalmanRejectCount = log.kalmanRejectCount(end); % 记录累计Kalman创新超限拒绝次数。
m.kalmanAngleVarianceFinal = log.kalmanP11(end); % 记录仿真结束时Kalman驻波角估计方差。
m.kalmanRateVarianceFinal = log.kalmanP22(end); % 记录仿真结束时Kalman驻波角速度估计方差。
m.kalmanFinite = all(isfinite([log.kalmanAngle; log.kalmanThetaRate; log.kalmanInnovation; log.kalmanP11; log.kalmanP22])) && all(log.kalmanP11 >= 0) && all(log.kalmanP22 >= 0); % 检查Kalman状态、创新与协方差是否有限且方差非负。
m.selftestExecuted = log.selftestDone(end); % 记录本次仿真是否完成真实检测链路SELFTEST。
m.selftestPassed = log.selftestPassed(end); % 记录SELFTEST是否通过增益和正交响应判据。
m.selftestFailed = log.selftestFailed(end); % 记录SELFTEST是否锁存失败。
m.selftestGainEstimate = log.selftestGainEstimate(end); % 记录SELFTEST检测链路归一化增益估计值。
m.selftestQuadratureRatio = log.selftestQuadratureRatio(end); % 记录SELFTEST正交残差相对同相响应比例。
m.calibEnabled = isfield(p, 'calib') && p.calib.enable; % 记录本用例是否启用V4.3在线标定。
m.calibActiveCount = 0; % 初始化在线标定活动拍数。
if isfield(log, 'calibActive') % 判断日志是否包含在线标定活动标志。
    m.calibActiveCount = sum(log.calibActive); % 统计在线标定活动拍数。
end % 结束在线标定活动统计。
m.calibUpdateCount = 0; % 初始化在线标定更新次数。
if isfield(log, 'calibUpdateCount') % 判断日志是否包含在线更新计数。
    m.calibUpdateCount = log.calibUpdateCount(end); % 记录最终在线标定更新次数。
end % 结束在线更新计数读取。
if isfield(log, 'calibDet11') % 判断日志是否包含检测矩阵估计。
    m.calibDetectionMatrixHat = [log.calibDet11(end) log.calibDet12(end); log.calibDet21(end) log.calibDet22(end)]; % 汇总最终检测矩阵估计值。
    m.calibDriveMatrixHat = [log.calibDrv11(end) log.calibDrv12(end); log.calibDrv21(end) log.calibDrv22(end)]; % 汇总最终驱动矩阵估计值。
    m.calibDetectionMatrixError = norm(m.calibDetectionMatrixHat - p.afe.crossMatrix, 'fro'); % 计算检测矩阵相对真实AFE矩阵的Frobenius误差。
    m.calibDriveMatrixError = norm(m.calibDriveMatrixHat - p.drive.crossMatrix, 'fro'); % 计算驱动矩阵估计相对真实能量/正交执行矩阵的Frobenius误差。
    m.calibDampingAnisotropyFinal = log.calibDampingAnisotropy(end); % 记录最终阻尼不均匀幅值估计。
    m.calibFrequencySplitFinalHz = log.calibFrequencySplitHz(end); % 记录最终频率裂解估计。
    m.calibDampingError = abs(m.calibDampingAnisotropyFinal - p.res.dampingAnisotropy); % 计算阻尼不均匀幅值估计误差。
    m.calibSplitErrorHz = abs(m.calibFrequencySplitFinalHz - p.res.frequencySplitHz); % 计算频率裂解估计误差。
    m.calibSafetyFactorFinal = log.calibSafetyFactor(end); % 记录最终在线安全系数。
    m.calibModeMatchFactorFinal = log.calibModeMatchFactor(end); % 记录最终模态匹配因子。
    if isfield(log, 'calibCompensationAlpha') % 判断日志是否包含V4.3.1补偿释放权重。
        m.calibCompensationAlphaFinal = log.calibCompensationAlpha(end); % 记录最终在线补偿释放权重。
    else % 兼容旧日志。
        m.calibCompensationAlphaFinal = 0; % 旧日志默认未释放在线补偿。
    end % 结束补偿释放权重读取。
    m.calibSyncEnergyGainFinal = log.calibSyncEnergyGain(end); % 记录最终能量通道正弦同步响应幅值。
    m.calibSyncQuadGainFinal = log.calibSyncQuadGain(end); % 记录最终正交通道正弦同步响应幅值。
else % 兼容旧日志。
    m.calibDetectionMatrixHat = eye(2); % 旧日志默认检测矩阵估计为单位矩阵。
    m.calibDriveMatrixHat = eye(2); % 旧日志默认驱动矩阵估计为单位矩阵。
    m.calibDetectionMatrixError = NaN; % 旧日志不报告矩阵误差。
    m.calibDriveMatrixError = NaN; % 旧日志不报告矩阵误差。
    m.calibDampingAnisotropyFinal = NaN; % 旧日志不报告阻尼估计。
    m.calibFrequencySplitFinalHz = NaN; % 旧日志不报告裂解估计。
    m.calibDampingError = NaN; % 旧日志不报告阻尼误差。
    m.calibSplitErrorHz = NaN; % 旧日志不报告裂解误差。
    m.calibSafetyFactorFinal = NaN; % 旧日志不报告安全系数。
    m.calibModeMatchFactorFinal = NaN; % 旧日志不报告模态匹配因子。
    m.calibCompensationAlphaFinal = NaN; % 旧日志不报告补偿释放权重。
    m.calibSyncEnergyGainFinal = NaN; % 旧日志不报告同步解调响应。
    m.calibSyncQuadGainFinal = NaN; % 旧日志不报告同步解调响应。
end % 结束在线标定指标读取。
m.bitTrueEnabled = isfield(p.asic, 'bitTrueEnable') && p.asic.bitTrueEnable; % 记录本用例是否启用V4.4位真ASIC数据通路。
m.bitTrueCicValidCount = 0; % 初始化CIC有效输出计数。
m.bitTrueFirValidCount = 0; % 初始化FIR有效输出计数。
m.bitTrueCordicIterationCount = 0; % 初始化CORDIC迭代计数。
m.bitTrueNcoWrapCount = 0; % 初始化整数NCO回卷计数。
m.bitTruePipelineValidCount = 0; % 初始化流水线valid计数。
m.bitTrueCdcEventCount = 0; % 初始化CDC事务计数。
m.bitTrueCdcErrorCount = 0; % 初始化CDC错误计数。
m.bitTrueSpiTransactionCount = 0; % 初始化SPI事务计数。
m.bitTrueSpiErrorCount = 0; % 初始化SPI错误计数。
if isfield(log, 'bittrueCicValidCount') % 判断日志是否包含V4.4位真ASIC诊断字段。
    m.bitTrueCicValidCount = log.bittrueCicValidCount(end); % 读取CIC有效输出次数。
    m.bitTrueFirValidCount = log.bittrueFirValidCount(end); % 读取FIR有效输出次数。
    m.bitTrueCordicIterationCount = log.bittrueCordicIterationCount(end); % 读取CORDIC微旋次数。
    m.bitTrueNcoWrapCount = log.bittrueNcoWrapCount(end); % 读取整数NCO回卷次数。
    m.bitTruePipelineValidCount = log.bittruePipelineValidCount(end); % 读取流水线valid到达次数。
    m.bitTrueCdcEventCount = log.bittrueCdcEventCount(end); % 读取CDC同步事务次数。
    m.bitTrueCdcErrorCount = log.bittrueCdcErrorCount(end); % 读取CDC错误次数。
    m.bitTrueSpiTransactionCount = log.bittrueSpiTransactionCount(end); % 读取SPI事务次数。
    m.bitTrueSpiErrorCount = log.bittrueSpiErrorCount(end); % 读取SPI CRC错误次数。
end % 结束V4.4位真诊断读取。
m.frpEnabled = isfield(p, 'frp') && p.frp.enable; % 记录本用例是否启用V4.5正反转FRP联合辨识。
m.frpActiveCount = sum(log.frpActive); % 统计FRP有限序列活动控制拍数。
m.frpStableCount = sum(log.frpStable); % 统计FRP正向与反向稳定平台控制拍数。
m.frpUpdateCount = log.frpUpdateCount(end); % 记录FRP联合RLS最终更新次数。
m.frpForwardCount = log.frpForwardCount(end); % 记录FRP正向稳定平台有效样本总数。
m.frpReverseCount = log.frpReverseCount(end); % 记录FRP反向稳定平台有效样本总数。
m.frpTransitionCount = log.frpTransitionCount(end); % 记录FRP平滑换向门控样本总数。
m.frpCoverageFraction = log.frpCoverageFraction(end); % 记录驻波角圆周最终覆盖比例。
m.frpConditionNumber = log.frpConditionNumber(end); % 记录联合参数协方差最终条件数。
m.frpConfidence = log.frpConfidence(end); % 记录FRP联合辨识最终综合可信度。
m.frpCompensationAlpha = log.frpCompensationAlpha(end); % 记录FRP联合补偿最终安全释放权重。
m.frpResidualRmsDps = log.frpResidualRmsDps(end); % 记录FRP联合辨识最终残差RMS，单位为度每秒。
m.frpCorrectionMaxDps = max(abs(log.frpCorrectionDps)); % 记录FRP联合补偿全程最大绝对值，单位为度每秒。
m.frpParameterHatDps = [log.frpBiasHatDps(end); log.frpSin4HatDps(end); log.frpCos4HatDps(end); log.frpSin8HatDps(end); log.frpCos8HatDps(end); log.frpDirectionHatDps(end)]; % 汇总零偏、四八次和方向不对称联合参数估计值。
m.frpTemperatureHatDpsPerC = log.frpTemperatureHatDpsPerC(end); % 记录FRP一阶温度误差估计值，单位为度每秒每摄氏度。
m.frpFinite = all(isfinite([log.frpResidualRmsDps; log.frpCorrectionDps; log.frpBiasHatDps; log.frpSin4HatDps; log.frpCos4HatDps; log.frpSin8HatDps; log.frpCos8HatDps; log.frpTemperatureHatDpsPerC; log.frpDirectionHatDps])) && all(isfinite(log.frpConditionNumber(log.frpUpdateCount > 0))); % 检查FRP联合参数、残差、补偿和有效更新后的条件数是否全部有限。
m.frpChecks.activity = ~m.frpEnabled || m.frpActiveCount > 0; % 检查FRP使能后是否确实执行了有限正反转序列。
m.frpChecks.bidirectional = ~m.frpEnabled || (m.frpForwardCount > 0 && m.frpReverseCount > 0); % 检查正向与反向平台是否都获得有效样本。
m.frpChecks.updates = ~m.frpEnabled || m.frpUpdateCount >= p.test.minimumFrpUpdates; % 检查联合RLS更新次数是否达到专用回归门限。
m.frpChecks.coverage = ~m.frpEnabled || m.frpCoverageFraction >= p.test.minimumFrpCoverage; % 检查驻波角覆盖比例是否达到专用回归门限。
m.frpChecks.condition = ~m.frpEnabled || m.frpConditionNumber <= p.frp.maxConditionNumber; % 检查联合回归数值条件是否处于安全范围。
m.frpChecks.confidence = ~m.frpEnabled || m.frpConfidence >= p.test.minimumFrpConfidence; % 检查综合辨识可信度是否达到专用回归门限。
m.frpChecks.residual = ~m.frpEnabled || m.frpResidualRmsDps <= p.test.maximumFrpResidualRmsDps; % 检查联合辨识创新残差RMS是否处于允许范围。
m.frpChecks.correctionBounded = ~m.frpEnabled || m.frpCorrectionMaxDps <= p.frp.maxCorrectionDps + 1e-9; % 检查FRP联合补偿是否始终服从独立安全限幅。
m.frpChecks.finite = ~m.frpEnabled || m.frpFinite; % 检查FRP联合辨识数值是否保持有限。
m.allFinite = all(isfinite([log.E; log.Q; log.angleOutput; log.rateOutput; log.rawRate; log.compensatedRate; log.ncoFrequencyHz])) && (~p.test.requireFiniteKalman || m.kalmanFinite) && (~m.frpEnabled || m.frpFinite); % 检查关键闭环状态、输出、Kalman与按配置启用的FRP联合辨识状态是否全部有限。
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
m.performanceChecks.kalmanFinite = ~p.test.requireFiniteKalman || m.kalmanFinite; % 根据配置检查Kalman状态和协方差数值可信度。
m.performanceChecks.kalmanReject = ~p.kalman.enable || m.kalmanRejectCount <= p.test.maximumKalmanRejectCount; % 检查标称用例Kalman创新拒绝次数是否处于允许范围。
m.performanceChecks.measurementValidity = m.measurementValidFraction >= p.test.minimumMeasurementValidFraction; % 检查标称有效RUN窗口测量可信样本比例是否满足配置门限。
if ~runWasReached % 判断是否需要把无RUN窗口下的退化误差统计显式标记为无效。
    m.rmsAngleErrorDeg = NaN; % 未进入RUN时不报告伪装成精度结果的角度RMS。
    m.finalAngleErrorDeg = NaN; % 未进入RUN时不报告没有统一清零参考的最终角度误差。
    m.rmsRateErrorDps = NaN; % 未进入RUN时不报告退化单点或ACQUIRE数据的速率RMS。
    m.maxRateErrorDps = NaN; % 未进入RUN时不报告退化窗口最大速率误差。
    m.meanRateErrorDps = NaN; % 未进入RUN时不报告退化窗口平均速率误差。
end % 结束未锁定性能统计无效化处理。
checkValues = struct2cell(m.performanceChecks); % 把各项性能检查结果转换为逻辑值列表。
m.passFunctional = m.locked && m.allFinite && m.unwrapFaultCount == 0; % 定义与性能无关的基础功能通过判据。
m.passPerformance = m.passFunctional && ~m.faulted && all(cellfun(@(x) logical(x), checkValues)); % 定义无故障标称用例的性能回归通过判据。
m.passFaultSafety = m.locked && m.faulted && m.allFinite && m.faultOutputsSafe; % 定义故障注入用例的安全路径通过判据。
m.passSelftest = m.locked && m.selftestExecuted && m.selftestPassed && ~m.selftestFailed && ~m.faulted && m.allFinite; % 定义真实检测链路SELFTEST通过并返回正常运行的判据。
m.passSelftestFailureSafety = m.locked && m.selftestExecuted && m.selftestFailed && m.faulted && m.faultOutputsSafe && m.allFinite; % 定义SELFTEST检测异常后进入FAULT并安全归零的判据。
m.passOnlineCalibration = ~m.calibEnabled || (m.passFunctional && ~m.faulted && m.calibUpdateCount >= p.calib.requireUpdateCount && m.calibDetectionMatrixError <= p.calib.maxMatrixError && m.calibDriveMatrixError <= p.calib.maxMatrixError && m.calibDampingError <= p.calib.maxDampingError && m.calibSplitErrorHz <= p.calib.maxSplitErrorHz && m.calibSafetyFactorFinal >= p.calib.safetyMin && m.kalmanRejectCount <= p.calib.maximumKalmanReject); % 定义V4.3在线标定用例通过判据。
bittrueActivityOk = ~m.bitTrueEnabled || (~isfield(p.test, 'requireBitTrueActivity') || ~p.test.requireBitTrueActivity || (m.bitTrueCicValidCount > 0 && m.bitTrueFirValidCount > 0 && m.bitTrueCordicIterationCount >= p.asic.cordicIterations && m.bitTrueNcoWrapCount > 0 && m.bitTruePipelineValidCount > 0 && m.bitTrueCdcEventCount > 0 && m.bitTrueSpiTransactionCount > 0)); % 检查V4.4位真ASIC链路是否确实产生活动。
m.passBitTrueAsic = ~m.bitTrueEnabled || (m.passFunctional && ~m.faulted && bittrueActivityOk && m.bitTrueCdcErrorCount == 0 && m.bitTrueSpiErrorCount == 0 && m.fixedOverflowCount == 0); % 定义V4.4位真ASIC链路通过判据。
frpCheckValues = struct2cell(m.frpChecks); % 把FRP各项专用检查转换为逻辑值列表。
m.passFrpJointIdentification = ~m.frpEnabled || (m.passFunctional && ~m.faulted && all(cellfun(@(x) logical(x), frpCheckValues))); % 定义V4.5多误差FRP联合辨识的分层通过判据。
end % 结束性能、诊断与分层通过判据计算函数。
