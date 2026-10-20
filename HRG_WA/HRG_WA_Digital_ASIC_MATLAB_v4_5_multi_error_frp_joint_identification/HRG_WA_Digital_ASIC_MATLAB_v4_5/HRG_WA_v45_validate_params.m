function report = HRG_WA_v45_validate_params(p, issueMessages) % 检查物理参数、数字时基、动态范围、控制器带宽和测试窗口的一致性。
if nargin < 2 % 判断调用者是否要求立即输出错误与警告。
    issueMessages = false; % 默认仅返回检查报告而不打断批量参数扫描。
end % 结束消息输出选项判断。
report.errors = {}; % 初始化致命参数错误列表。
report.warnings = {}; % 初始化需要工程复核的参数警告列表。
if p.sim.fsAdc <= 0 || p.sim.fsCtrl <= 0 || p.res.f0 <= 0 || p.res.Q <= 0 % 检查所有核心频率和品质因数是否为正数。
    report.errors{end + 1} = 'fsAdc、fsCtrl、f0和Q必须全部大于零。'; % 记录核心物理量非法错误。
end % 结束核心物理量正值检查。
rateRatio = p.sim.fsAdc / p.sim.fsCtrl; % 计算ADC采样率与控制率之比。
if abs(rateRatio - round(rateRatio)) > 1e-12 % 检查抽取比是否为整数。
    report.errors{end + 1} = 'fsAdc/fsCtrl必须为整数，才能形成确定的硬件抽取拍。'; % 记录采样率比例非法错误。
end % 结束采样率整数比检查。
if p.sim.samplesPerCtrl < 4 % 检查每控制拍是否具有足够的正交解调样本。
    report.errors{end + 1} = '每个控制周期至少需要四个ADC样本。'; % 记录正交解调样本不足错误。
end % 结束每控制拍样本数检查。
samplesPerCarrier = p.sim.fsAdc / p.res.f0; % 计算每个谐振载波周期的ADC采样点数。
if samplesPerCarrier < 8 % 检查载波正交解调的推荐过采样条件。
    report.warnings{end + 1} = '每载波周期ADC采样点少于8，需重新验证解调增益、镜像抑制和相位噪声。'; % 记录载波过采样不足警告。
end % 结束载波采样点数检查。
if p.sim.fsAdc <= 2 * (p.res.f0 + p.pll.frequencyLimitHz) % 检查最高NCO频率是否满足奈奎斯特条件。
    report.errors{end + 1} = 'ADC采样率不足以覆盖标称谐振频率与DPLL最大频偏之和。'; % 记录NCO混叠风险错误。
end % 结束最高NCO频率检查。
if p.afe.enable && p.afe.bandwidthHz <= p.res.f0 + p.pll.frequencyLimitHz % 检查AFE带宽是否覆盖DPLL允许的最高载波频率。
    report.warnings{end + 1} = 'AFE带宽没有覆盖标称谐振频率与DPLL最大正频偏之和。'; % 记录模拟前端带宽不足警告。
end % 结束AFE带宽检查。
estimatedSignalPeak = sqrt(max([p.res.energyTarget, p.res.energyInitial, p.protect.energyMax])); % 用归一化能量上限估算单通道最不利载波峰值量级。
if estimatedSignalPeak > 0.80 * min(p.afe.fullScale, p.adc.fullScale) % 检查估算峰值是否保留至少百分之二十模拟量程裕量。
    report.warnings{end + 1} = '估算检测载波峰值已超过AFE或ADC满量程的80%，需进行角位置和Q扰动压力仿真。'; % 记录模拟输入量程裕量不足警告。
end % 结束检测载波峰值量程检查。
if isfield(p.input, 'rateTransitionTimesSec') && isfield(p.input, 'rateLevelsDps') % 判断用户是否使用分段速率表。
    if numel(p.input.rateLevelsDps) ~= numel(p.input.rateTransitionTimesSec) + 1 % 检查分段速率值个数是否正确。
        report.errors{end + 1} = 'rateLevelsDps元素数必须等于rateTransitionTimesSec元素数加一。'; % 记录分段速率表尺寸错误。
    end % 结束分段速率表尺寸检查。
    if any(diff(p.input.rateTransitionTimesSec) <= 0) || any(p.input.rateTransitionTimesSec < 0) || any(p.input.rateTransitionTimesSec > p.sim.duration) % 检查切换时刻是否严格递增且处于仿真区间。
        report.errors{end + 1} = '角速度切换时刻必须严格递增并位于零到仿真结束时刻之间。'; % 记录分段速率切换时刻错误。
    end % 结束分段速率时刻检查。
end % 结束分段速率表检查。
if ~isfield(p, 'drive') || ~isfield(p.drive, 'crossMatrix') || ~isequal(size(p.drive.crossMatrix), [2 2]) || any(~isfinite(p.drive.crossMatrix(:))) % 检查V4.3驱动矩阵是否存在且尺寸正确。
    report.errors{end + 1} = 'drive.crossMatrix必须为有限二乘二矩阵。'; % 记录驱动矩阵尺寸或数值错误。
end % 结束驱动矩阵检查。
if ~isequal(size(p.afe.crossMatrix), [2 2]) || numel(p.afe.phaseDelayRad) ~= 2 || numel(p.afe.gainTempCoeff) ~= 2 || numel(p.afe.phaseTempCoeffRad) ~= 2 || numel(p.afe.quadraticNonlinearity) ~= 2 || numel(p.afe.cubicNonlinearity) ~= 2 % 检查V4.5检测多误差参数尺寸。
    report.errors{end + 1} = 'V4.5检测矩阵必须为二乘二，检测相位、温度增益、温度相位及二三次非线性必须各含两个元素。'; % 记录检测多误差参数尺寸错误。
end % 结束V4.5检测多误差参数尺寸检查。
if numel(p.drive.gainTempCoeff) ~= 2 || numel(p.drive.quadraticNonlinearity) ~= 2 || numel(p.drive.cubicNonlinearity) ~= 2 % 检查V4.5驱动多误差向量尺寸。
    report.errors{end + 1} = 'V4.5驱动温度增益及二三次非线性参数必须各含两个元素。'; % 记录驱动多误差参数尺寸错误。
end % 结束V4.5驱动多误差参数尺寸检查。
if p.ctrl.energyLimit > p.dac.fullScale(1) || p.ctrl.quadLimit > p.dac.fullScale(2) % 检查PI数字限幅是否超过实际DAC物理量程。
    report.errors{end + 1} = '能量或正交数字控制限幅超过对应DAC满量程。'; % 记录数字控制范围与DAC不匹配错误。
end % 结束PI限幅与DAC范围检查。
if p.virtual.amplitudeDps * pi / 180 > p.dac.fullScale(3) % 检查虚拟进动命令是否超过执行通道范围。
    report.errors{end + 1} = '虚拟进动峰值超过第三路DAC满量程。'; % 记录虚拟进动通道范围错误。
end % 结束虚拟进动范围检查。
if p.frp.enable && max(abs([p.frp.forwardDps p.frp.reverseDps])) * pi / 180 > p.dac.fullScale(3) % 检查FRP正反转命令是否超过第三路执行通道范围。
    report.errors{end + 1} = 'FRP正向或反向平台速度超过第三路DAC满量程。'; % 记录FRP执行范围错误。
end % 结束FRP执行范围检查。
invariantMaximum = 2 ^ (p.asic.invariantWordLength - p.asic.invariantFractionLength - 1) - 2 ^ (-p.asic.invariantFractionLength); % 计算不变量有符号Q格式最大可表示值。
if p.protect.energyMax > invariantMaximum % 检查能量保护上限是否超出不变量定点范围。
    report.errors{end + 1} = 'energyMax超过不变量Q格式最大可表示值。'; % 记录不变量定点范围不足错误。
end % 结束不变量定点范围检查。
controlMaximum = 2 ^ (p.asic.controlWordLength - p.asic.controlFractionLength - 1) - 2 ^ (-p.asic.controlFractionLength); % 计算控制字有符号Q格式最大可表示值。
if max([p.ctrl.energyLimit, p.ctrl.quadLimit, p.dac.fullScale(3)]) > controlMaximum % 检查三路控制量是否超出控制字定点范围。
    report.errors{end + 1} = '至少一路控制量或执行量程超过控制字Q格式最大可表示值。'; % 记录控制字定点范围不足错误。
end % 结束控制字定点范围检查。
[~, suggestion] = HRG_WA_v45_autotune(p, false); % 计算当前物理量对应的控制器范围和动态裕量建议。
if p.ctrl.energyLimit < suggestion.minimumEnergyLimit % 检查能量控制范围是否覆盖起振和稳态阻尼需要。
    report.warnings{end + 1} = 'energyLimit低于解析估算下限，可能导致起振慢或长期顶到输出限幅。'; % 记录能量执行范围不足警告。
end % 结束能量限幅检查。
if p.ctrl.quadLimit < suggestion.minimumQuadLimit % 检查正交控制范围是否覆盖频率裂解扰动。
    report.warnings{end + 1} = 'quadLimit低于频率裂解最不利扰动的带裕量估算值。'; % 记录正交执行范围不足警告。
end % 结束正交限幅检查。
if p.pll.frequencyLimitHz < suggestion.minimumPllFrequencyLimitHz % 检查DPLL范围是否覆盖温漂和非线性频移。
    report.warnings{end + 1} = 'DPLL频率限幅不足以覆盖温漂、Duffing频移和频率裂解的保守包络。'; % 记录DPLL捕获范围不足警告。
end % 结束DPLL频率范围检查。
if max([p.tune.pllNaturalHz, p.tune.energyNaturalHz, p.tune.quadNaturalHz]) > suggestion.maximumNaturalHzFromDelay % 检查数字流水线延迟造成的相位裕量约束。
    report.warnings{end + 1} = '至少一个目标自然频率超过流水线延迟相位预算给出的建议上限。'; % 记录控制器延迟裕量警告。
end % 结束控制器延迟检查。
if p.tune.pllNaturalHz >= p.sim.fsCtrl / 20 || p.tune.energyNaturalHz >= p.sim.fsCtrl / 20 || p.tune.quadNaturalHz >= p.sim.fsCtrl / 20 % 检查连续域增益映射是否远低于控制采样率。
    report.warnings{end + 1} = '控制环目标自然频率接近数字控制率，连续域解析初值可能失效。'; % 记录离散化有效性警告。
end % 结束控制器相对采样率检查。
if p.ctrl.rateLpfHz <= 0 || p.ctrl.rateLpfHz >= p.sim.fsCtrl / 2 % 检查角速度低通截止频率的离散实现范围。
    report.errors{end + 1} = 'rateLpfHz必须大于零且小于控制率的一半。'; % 记录速率低通频率错误。
end % 结束角速度低通频率检查。
if p.pll.energyValidThreshold <= 0 || p.pll.energyValidThreshold >= p.res.energyTarget % 检查DPLL有效性能量门限是否具有合理层级。
    report.errors{end + 1} = 'DPLL energyValidThreshold必须大于零且小于energyTarget。'; % 记录DPLL有效性能量门限错误。
end % 结束DPLL有效性能量门限检查。
if p.pll.backCalculationGain < 0 || p.ctrl.energyBackCalculationGain < 0 || p.ctrl.quadBackCalculationGain < 0 || p.ctrl.actuatorTrackingGain < 0 || p.ctrl.slewTrackingGain < 0 % 检查输出限幅、执行器跟踪和斜率跟踪反算增益是否非负。
    report.errors{end + 1} = 'DPLL、双PI、执行器跟踪和斜率跟踪反算增益必须为非负数。'; % 记录完整反算抗饱和增益非法错误。
end % 结束反算抗饱和增益检查。
if p.ctrl.energySlewPerSec <= 0 || p.ctrl.quadSlewPerSec <= 0 % 检查两路控制字斜率限制是否为正数。
    report.errors{end + 1} = 'energySlewPerSec和quadSlewPerSec必须大于零。'; % 记录控制字斜率限制非法错误。
end % 结束控制字斜率限制检查。
if p.kalman.measurementNoiseDeg <= 0 || p.kalman.accelerationNoiseDps2 <= 0 || p.kalman.initialAngleStdDeg <= 0 || p.kalman.initialRateStdDps <= 0 % 检查Kalman噪声和初始不确定度是否全部为正。
    report.errors{end + 1} = 'Kalman测量噪声、过程噪声和初始标准差必须全部大于零。'; % 记录Kalman参数非法错误。
end % 结束Kalman噪声参数检查。
if p.kalman.maxInnovationDeg <= 0 || p.kalman.covarianceFloor <= 0 % 检查Kalman创新门限与协方差下限是否为正。
    report.errors{end + 1} = 'Kalman创新门限和协方差数值下限必须大于零。'; % 记录Kalman数值保护参数错误。
end % 结束Kalman数值保护参数检查。

if isfield(p.asic, 'bitTrueEnable') && p.asic.bitTrueEnable % 判断是否启用V4.4位真ASIC链路并检查逐级数字配置。
    if p.asic.ncoPhaseBits < 16 || p.asic.ncoPhaseBits ~= round(p.asic.ncoPhaseBits) % 检查整数NCO相位累加器位宽是否具有足够分辨率。
        report.errors{end + 1} = '位真ASIC整数NCO相位位宽必须为不小于16的整数。'; % 记录整数NCO相位位宽错误。
    end % 结束整数NCO相位位宽检查。
    if p.asic.ncoAmplitudeBits < 8 || p.asic.ncoAmplitudeBits ~= round(p.asic.ncoAmplitudeBits) % 检查NCO查表幅值位宽是否具有足够正弦余弦分辨率。
        report.errors{end + 1} = '位真ASIC整数NCO幅值位宽必须为不小于8的整数。'; % 记录NCO幅值位宽错误。
    end % 结束NCO幅值位宽检查。
    if p.asic.mixerWordLength <= p.asic.mixerFractionLength + 2 % 检查混频乘法器Q格式是否保留符号位和整数裕量。
        report.errors{end + 1} = '位真ASIC混频器Q格式整数位不足。'; % 记录混频Q格式错误。
    end % 结束混频器Q格式检查。
    if p.asic.cicStages < 1 || p.asic.cicStages ~= round(p.asic.cicStages) || p.asic.cicDifferentialDelay < 1 || p.asic.cicDifferentialDelay ~= round(p.asic.cicDifferentialDelay) % 检查CIC阶数和微分延迟是否为正整数。
        report.errors{end + 1} = '位真ASIC CIC阶数和微分延迟必须为正整数。'; % 记录CIC结构参数错误。
    end % 结束CIC结构参数检查。
    cicGainBits = ceil(p.asic.cicStages * log2(max(1, p.sim.samplesPerCtrl * p.asic.cicDifferentialDelay))); % 估计CIC抽取增益所需保护位。
    if p.asic.cicWordLength <= p.asic.mixerWordLength + cicGainBits % 检查CIC累加器是否覆盖抽取增益和长期积分裕量。
        report.warnings{end + 1} = '位真ASIC CIC累加器位宽接近抽取增益下限，长时间仿真可能出现饱和。'; % 记录CIC位宽裕量警告。
    end % 结束CIC位宽裕量检查。
    if isempty(p.asic.firCoefficients) || any(~isfinite(p.asic.firCoefficients(:))) || abs(sum(p.asic.firCoefficients)) < eps % 检查FIR系数是否存在且直流增益非零。
        report.errors{end + 1} = '位真ASIC FIR系数必须有限且直流增益非零。'; % 记录FIR系数错误。
    end % 结束FIR系数检查。
    if p.asic.firWordLength <= p.asic.firFractionLength + 2 || p.asic.cordicWordLength <= p.asic.cordicFractionLength + 2 % 检查FIR和CORDIC Q格式是否保留整数裕量。
        report.errors{end + 1} = '位真ASIC FIR或CORDIC Q格式整数位不足。'; % 记录FIR/CORDIC Q格式错误。
    end % 结束FIR/CORDIC Q格式检查。
    if p.asic.cordicIterations < 4 || p.asic.cordicIterations ~= round(p.asic.cordicIterations) % 检查迭代CORDIC步数是否为足够大的整数。
        report.errors{end + 1} = '位真ASIC CORDIC迭代次数必须为不小于4的整数。'; % 记录CORDIC迭代次数错误。
    end % 结束CORDIC迭代次数检查。
    if p.asic.validPipelineDepth < 1 || p.asic.validPipelineDepth ~= round(p.asic.validPipelineDepth) % 检查有效信号流水线深度是否为正整数。
        report.errors{end + 1} = '位真ASIC有效信号流水线深度必须为正整数。'; % 记录valid流水线参数错误。
    end % 结束valid流水线深度检查。
    if p.asic.cdcEnable && (p.asic.cdcSyncStages < 2 || p.asic.cdcSyncStages ~= round(p.asic.cdcSyncStages)) % 检查CDC同步触发器级数是否满足双触发器同步基本要求。
        report.errors{end + 1} = '启用CDC模型时cdcSyncStages必须为不小于2的整数。'; % 记录CDC同步级数错误。
    end % 结束CDC同步级数检查。
    if p.asic.spiEnable && (p.asic.spiClockHz <= 0 || p.asic.spiTransactionPeriodCtrl < 1 || p.asic.spiTransactionPeriodCtrl ~= round(p.asic.spiTransactionPeriodCtrl) || p.asic.spiAddressBits <= 0 || p.asic.spiDataBits <= 0 || p.asic.spiCrcBits <= 0) % 检查SPI事务模型的时钟、周期和帧字段是否有效。
        report.errors{end + 1} = '启用SPI模型时SPI时钟、事务周期、地址位、数据位和CRC位必须为正值。'; % 记录SPI事务参数错误。
    end % 结束SPI参数检查。
end % 结束V4.4位真ASIC参数检查。
if p.test.minimumMeasurementValidFraction < 0 || p.test.minimumMeasurementValidFraction > 1 % 检查标称测量有效率门限是否合法。
    report.errors{end + 1} = 'minimumMeasurementValidFraction必须位于零到一之间。'; % 记录测量有效率门限非法错误。
end % 结束测量有效率门限检查。
if p.frp.enable % 判断是否启用V4.5正反转FRP联合辨识并执行专用参数检查。
    if p.frp.startTime <= 0 || p.frp.startTime >= p.sim.duration % 检查FRP启动时刻是否位于仿真区间。
        report.errors{end + 1} = '启用FRP时startTime必须位于零与仿真结束时刻之间。'; % 记录FRP启动时刻错误。
    end % 结束FRP启动时刻检查。
    if p.frp.forwardDps <= 0 || p.frp.reverseDps >= 0 || p.frp.dwellSec <= 0 || p.frp.transitionSec <= 0 || p.frp.cycleCount < 1 % 检查正反转方向、驻留、换向和循环参数。
        report.errors{end + 1} = 'FRP必须配置正的forwardDps、负的reverseDps以及正的驻留、换向和循环次数。'; % 记录FRP序列参数错误。
    end % 结束FRP序列参数检查。
    if p.frp.updateDecimation < 1 || p.frp.updateDecimation ~= round(p.frp.updateDecimation) || p.frp.rlsLambda <= 0 || p.frp.rlsLambda > 1 || p.frp.rlsDelta <= 0 % 检查FRP联合RLS基本数值参数。
        report.errors{end + 1} = 'FRP更新抽取比必须为正整数，RLS遗忘因子必须位于(0,1]且初始协方差必须为正。'; % 记录FRP联合RLS参数错误。
    end % 结束FRP联合RLS参数检查。
    if p.frp.coverageBins < 8 || p.frp.coverageBins ~= round(p.frp.coverageBins) || p.frp.minimumCoverageFraction <= 0 || p.frp.minimumCoverageFraction > 1 % 检查驻波角覆盖统计配置。
        report.errors{end + 1} = 'FRP覆盖分箱必须为不小于8的整数且最低覆盖比例必须位于(0,1]。'; % 记录FRP覆盖统计参数错误。
    end % 结束FRP覆盖参数检查。
    if p.frp.minimumSamples < 1 || p.frp.compensationStartSamples < 0 || p.frp.compensationRampSamples < 1 || p.frp.maxCompensationAlpha < 0 || p.frp.maxCompensationAlpha > 1 || p.frp.maxCorrectionDps <= 0 % 检查FRP补偿安全释放参数。
        report.errors{end + 1} = 'FRP样本数、补偿释放、最大权重或补偿限幅配置非法。'; % 记录FRP补偿安全释放参数错误。
    end % 结束FRP补偿释放参数检查。
    if p.frp.maxConditionNumber <= 1 || p.frp.confidenceThreshold < 0 || p.frp.confidenceThreshold > 1 || p.frp.residualBlend <= 0 || p.frp.residualBlend > 1 % 检查FRP可信度和残差滤波参数。
        report.errors{end + 1} = 'FRP最大条件数、可信度门限或残差滤波系数配置非法。'; % 记录FRP可信度参数错误。
    end % 结束FRP可信度参数检查。
    requiredDuration = p.frp.startTime + max(round(p.frp.cycleCount), 1) * 2 * (p.frp.dwellSec + p.frp.transitionSec); % 计算完成全部正反转FRP循环所需仿真时长。
    if p.sim.duration < requiredDuration % 判断仿真时长是否不足以完成配置的FRP循环。
        report.warnings{end + 1} = '仿真时长不足以完成全部FRP正反转循环，覆盖度和可信度可能无法达到门限。'; % 记录FRP序列截断警告。
    end % 结束FRP总时长检查。
end % 结束V4.5 FRP参数检查。
if isfield(p, 'calib') && p.calib.enable % 判断是否启用V4.3在线标定并检查其时序与数值范围。
    if p.calib.startTime <= 0 || p.calib.startTime >= p.sim.duration % 检查在线标定启动时刻是否处于仿真范围内。
        report.errors{end + 1} = '启用在线标定时startTime必须位于零与仿真结束时刻之间。'; % 记录在线标定启动时刻错误。
    end % 结束在线标定启动时刻检查。
    if p.calib.updateDecimation < 1 || p.calib.updateDecimation ~= round(p.calib.updateDecimation) % 检查在线标定更新抽取比是否为正整数。
        report.errors{end + 1} = '在线标定updateDecimation必须为正整数。'; % 记录在线标定抽取比错误。
    end % 结束在线标定抽取比检查。
    if p.calib.excitationAmplitude < 0 || p.calib.excitationAmplitude > 0.05 * min(p.ctrl.energyLimit, p.ctrl.quadLimit) % 检查正弦自激幅值是否保持小扰动属性。
        report.warnings{end + 1} = '在线标定正弦自激幅值偏大，可能污染正常导航性能窗口。'; % 记录在线标定小信号条件警告。
    end % 结束正弦自激幅值检查。
    if p.calib.excitationFrequencyHz <= 0 || p.calib.excitationFrequencyHz >= p.sim.fsCtrl / 4 % 检查同步解调频率是否处于控制域可解析范围。
        report.errors{end + 1} = '在线标定excitationFrequencyHz必须大于零且小于控制率四分之一。'; % 记录在线标定频率错误。
    end % 结束在线标定频率检查。
    if p.calib.rlsLambda <= 0 || p.calib.rlsLambda > 1 || p.calib.rlsDelta <= 0 % 检查RLS遗忘因子和初值协方差是否合法。
        report.errors{end + 1} = '在线标定RLS遗忘因子必须位于(0,1]且rlsDelta必须大于零。'; % 记录RLS参数错误。
    end % 结束RLS参数检查。
    if p.calib.matrixBlend < 0 || p.calib.matrixBlend > 1 || p.calib.matrixLimit <= 0 % 检查矩阵写入混合系数和限幅是否合法。
        report.errors{end + 1} = '在线标定矩阵混合系数必须位于[0,1]且matrixLimit必须大于零。'; % 记录矩阵标定参数错误。
    end % 结束矩阵标定参数检查。
    if p.calib.ekfProcessNoise < 0 || p.calib.ekfMeasurementNoise <= 0 || p.calib.ekfBlend < 0 || p.calib.ekfBlend > 1 % 检查EKF式物理参数更新参数是否合法。
        report.errors{end + 1} = '在线标定EKF噪声和混合系数配置非法。'; % 记录EKF参数错误。
    end % 结束EKF参数检查。
    if p.calib.safetyMin <= 0 || p.calib.safetyMax <= p.calib.safetyMin % 检查安全系数显示范围是否合法。
        report.errors{end + 1} = '在线标定安全系数上下限配置非法。'; % 记录安全系数参数错误。
    end % 结束安全系数范围检查。
end % 结束V4.3在线标定参数检查。
if p.selftest.enable && (p.selftest.startTime <= 0 || p.selftest.startTime >= p.sim.duration) % 检查自动SELFTEST触发时刻是否处于仿真区间。
    report.errors{end + 1} = '启用SELFTEST时startTime必须位于零与仿真结束时刻之间。'; % 记录SELFTEST触发时刻错误。
end % 结束SELFTEST触发时刻检查。
if p.selftest.duration <= 0 || p.selftest.modulationHz <= 0 || p.selftest.injectionAmplitude <= 0 % 检查SELFTEST持续时间、调制频率和命令幅值是否为正。
    report.errors{end + 1} = 'SELFTEST持续时间、调制频率和注入幅值必须全部大于零。'; % 记录SELFTEST核心参数错误。
end % 结束SELFTEST核心参数检查。
if p.selftest.minimumGain < 0 || p.selftest.maximumGain <= p.selftest.minimumGain || p.selftest.maximumQuadratureRatio < 0 % 检查SELFTEST增益窗口和正交残差门限。
    report.errors{end + 1} = 'SELFTEST增益窗口或正交残差门限配置非法。'; % 记录SELFTEST判定窗口错误。
end % 结束SELFTEST判定窗口检查。
if p.selftest.injectionAmplitude * abs(p.selftest.injectionScale) > 0.20 * min(p.afe.fullScale, p.adc.fullScale) % 检查SELFTEST注入是否保留足够模拟前端量程裕量。
    report.warnings{end + 1} = 'SELFTEST测试载波超过AFE或ADC满量程的20%，应降低注入幅值避免扰动正常驻波测量。'; % 记录SELFTEST注入量程风险警告。
end % 结束SELFTEST注入量程检查。
selftestCycleCount = p.selftest.duration * p.selftest.modulationHz; % 计算SELFTEST同步相关累计的调制周期数。
if abs(selftestCycleCount - round(selftestCycleCount)) > 1e-9 % 检查SELFTEST时长是否覆盖整数个调制周期。
    report.warnings{end + 1} = 'SELFTEST持续时间未覆盖整数个调制周期，固定驻波分量可能泄漏到同步相关结果。'; % 记录SELFTEST同步相关谱泄漏风险。
end % 结束SELFTEST整数周期检查。
if p.analysis.minimumSamples < 16 || p.analysis.maximumAllanPoints < 3 || p.analysis.psdSegmentSec <= 0 % 检查Allan与PSD分析的基本尺寸参数。
    report.errors{end + 1} = '噪声分析最少样本数、Allan点数或PSD分段时长配置非法。'; % 记录噪声分析参数错误。
end % 结束Allan与PSD分析尺寸检查。
if p.analysis.psdOverlapRatio < 0 || p.analysis.psdOverlapRatio >= 1 % 检查Welch PSD重叠比例范围。
    report.errors{end + 1} = 'PSD重叠比例必须大于等于零且小于一。'; % 记录Welch PSD重叠比例错误。
end % 结束Welch PSD重叠比例检查。
if p.monteCarlo.seedCount < 1 || p.monteCarlo.seedCount ~= round(p.monteCarlo.seedCount) || p.monteCarlo.minimumPassRate <= 0 || p.monteCarlo.minimumPassRate > 1 % 检查Monte Carlo运行次数和通过率门限。
    report.errors{end + 1} = 'Monte Carlo种子数必须为正整数且最低通过率必须位于零到一之间。'; % 记录Monte Carlo基本参数错误。
end % 结束Monte Carlo基本参数检查。
monteCarloSigmas = [p.monteCarlo.qRelativeSigma p.monteCarlo.frequencySplitRelativeSigma p.monteCarlo.dampingAnisotropyRelativeSigma p.monteCarlo.afeGainSigma p.monteCarlo.afeOffsetSigma p.monteCarlo.dacGainSigma]; % 汇总全部Monte Carlo离散标准差参数。
if any(~isfinite(monteCarloSigmas)) || any(monteCarloSigmas < 0) % 检查Monte Carlo离散标准差是否有限且非负。
    report.errors{end + 1} = 'Monte Carlo全部离散标准差必须是有限非负数。'; % 记录Monte Carlo离散标准差非法错误。
end % 结束Monte Carlo离散标准差检查。
minimumSettleWindow = 5 / (2 * pi * p.ctrl.rateLpfHz); % 计算角速度一阶低通五个时间常数对应的稳定窗口。
if p.test.ignoreAfterLock < minimumSettleWindow % 检查锁定后统计排除窗口是否覆盖滤波器稳定过程。
    report.warnings{end + 1} = 'ignoreAfterLock小于角速度低通五个时间常数，RMS可能包含锁定瞬态。'; % 记录锁定后统计窗口不足警告。
end % 结束锁定后统计窗口检查。
if p.ctrl.energyLockTolerance * p.res.energyTarget >= min(p.res.energyTarget - p.protect.energyMin, p.protect.energyMax - p.res.energyTarget) % 检查能量锁定窗口与故障保护窗口是否保持层级关系。
    report.warnings{end + 1} = '能量锁定窗口已接近或越过保护门限，应扩大保护范围或收紧锁定容差。'; % 记录锁定与保护门限重叠警告。
end % 结束能量锁定层级检查。
if p.ctrl.quadLockTolerance >= p.protect.quadMax % 检查正交锁定门限是否严格小于保护门限。
    report.errors{end + 1} = 'quadLockTolerance必须小于quadMax保护门限。'; % 记录正交锁定与保护门限错误。
end % 结束正交门限层级检查。
if isfield(p.input, 'rateLevelsDps') && max(abs(p.input.rateLevelsDps)) > 0.5 * suggestion.maximumUnambiguousRateDps % 检查用户最大输入角速度相对理论展开极限是否保留至少二倍裕量。
    report.warnings{end + 1} = '最大输入角速度已超过理论四倍角展开极限的一半，需进行更严格的丢拍与噪声验证。'; % 记录高动态展开裕量警告。
end % 结束高动态展开裕量检查。
report.ok = isempty(report.errors); % 汇总是否不存在致命参数错误。
report.suggestion = suggestion; % 把控制器和动态范围建议附加到检查报告。
if issueMessages && ~isempty(report.warnings) % 判断是否需要在命令窗口输出工程警告。
    warning('HRG_WA:ParameterWarning', '%s', strjoin(report.warnings, newline)); % 输出全部参数警告但允许仿真继续。
end % 结束参数警告输出判断。
if issueMessages && ~isempty(report.errors) % 判断是否需要用致命错误阻止仿真。
    error('HRG_WA:ParameterError', '%s', strjoin(report.errors, newline)); % 输出全部致命参数错误并停止运行。
end % 结束参数错误输出判断。
end % 结束参数一致性检查函数。
