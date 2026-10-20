clear; % 清除工作区变量，保证回归用例互不污染。
clc; % 清空命令窗口，便于阅读分层测试报告。
verify_HRG_WA_v45_install(); % 在回归开始前检查MATLAB实际解析路径和V4.5多误差FRP联合辨识修订标志。
user = HRG_WA_v45_user_config(); % 加载集中式用户参数表头作为回归基础。
user.sim.seed = 101; % 为全部可比较用例设置相同随机种子以隔离参数变化影响。
user.sim.duration = 6.0; % 设置回归总时长，兼顾锁定、三个速率平台和故障验证。
user.input.rateTransitionTimesSec = [2.0 3.6 4.8]; % 把第一段非零速率安排在标称锁定之后，避免把捕获瞬态误算为动态误差。
user.input.rateLevelsDps = [0 60 -35 100]; % 设置普通回归用例的统一分段角速度，单位为度每秒。
base = HRG_WA_v45_params(user); % 把用户表头转换为内部统一参数并执行一致性检查。
fprintf('模型修订=%s\n', base.meta.revision); % 打印明确维护版本以便回归记录能够识别新旧代码。
caseNames = {'ideal_float', 'nominal_fixed', 'high_dynamic_wrap', 'adc14_stress', 'virtual_precession', 'antiwindup_stress', 'dpll_dropout_freeze', 'selftest_pass', 'selftest_fail', 'loop_fault', 'online_calibration', 'bittrue_asic', 'frp_joint_identification'}; % 定义十组基础回归、在线标定、位真ASIC和V4.5多误差FRP联合辨识用例。
passed = false(size(caseNames)); % 预分配各用例最终通过标志。
functionalPassed = false(size(caseNames)); % 预分配各用例功能层通过标志。
performancePassed = false(size(caseNames)); % 预分配各用例性能层通过标志。
metrics = cell(size(caseNames)); % 预分配各用例完整指标结构体。
summary = cell(numel(caseNames), 1); % 预分配各用例文字摘要。
caseParams = cell(size(caseNames)); % 预分配各用例实际参数快照以支持数值回归追溯。
for c = 1:numel(caseNames) % 逐个执行十组闭环性能与测量可信度回归测试。
    p = base; % 为当前用例复制一份独立参数。
    switch caseNames{c} % 根据用例名称配置差异化物理量和接口条件。
        case 'ideal_float' % 配置浮点低非理想基准用例。
            p.asic.fixedEnable = false; % 关闭数字ASIC定点量化。
            p.afe.enable = false; % 关闭AFE带宽、串扰和偏置非理想模型。
            p.afe.offset = [0; 0]; % 清除AFE输入直流偏置。
            p.afe.noiseSigma = [0; 0]; % 清除AFE输入白噪声。
            p.adc.bits = 24; % 提高ADC位宽以使量化误差相对控制与解算误差可以忽略。
            p.adc.jitterRms = 0; % 清除ADC采样时钟抖动。
            p.dac.bits = 24; % 提高DAC位宽以使执行量化误差相对闭环误差可以忽略。
            p.dac.gain = [1; 1; 1]; % 清除三路执行通道增益误差。
            p.dac.offset = [0; 0; 0]; % 清除三路执行通道直流偏置。
            p.dac.noiseSigma = [0; 0; 0]; % 清除三路执行通道输出噪声。
            p.res.dampingAnisotropy = 0; % 清除阻尼不均匀。
            p.res.frequencySplitHz = 0; % 清除模态频率裂解。
            p.comp.dampingAnisotropyHat = 0; % 同步清除补偿器中的阻尼不均匀估计值。
            p.comp.frequencySplitHatHz = 0; % 同步清除补偿器中的频率裂解估计值。
            p.res.duffingHzPerEnergy = 0; % 清除能量相关非线性频移。
            p.res.processEnergyNoise = 0; % 清除能量慢变量过程噪声。
            p.res.processQuadNoise = 0; % 清除正交慢变量过程噪声。
            p.res.processThetaNoise = 0; % 清除驻波角慢变量过程噪声。
            p.res.phaseNoiseRad = 0; % 清除谐振载波相位噪声。
            referenceTemperature = p.env.referenceTemperature; % 保存理想用例使用的常值参考温度。
            p.env.temperatureFcn = @(t) referenceTemperature + 0 * t; % 固定环境温度为参考温度。
            p.comp.extraHarmonicsDps = [0 0 0 0]; % 清除不存在物理对应项的附加补偿系数。
        case 'nominal_fixed' % 配置标称定点ASIC用例。
            p.sim.seed = 101; % 明确使用与十四位ADC压力用例相同的随机种子。
        case 'high_dynamic_wrap' % 配置高动态四倍角连续展开与速率尺度用例。
            p.input.rateFcn = @(t) (t >= 2.0) * 1200 * pi / 180; % 在完成标称锁定后施加每秒一千二百度恒定角速度。
            p.test.rateTransitionTimes = 2.0; % 记录高动态用例唯一速率切换时刻。
            p.test.maxAngleRmsDeg = 5.0; % 设置高动态回归角度RMS上限，单位为度。
            p.test.maxRateRmsDps = 60.0; % 设置高动态回归角速度RMS上限为满量程输入的百分之五。
            p.test.maxRateErrorDps = 250.0; % 设置高动态回归最大角速度误差上限。
        case 'adc14_stress' % 配置十四位ADC与收窄解调字长压力用例。
            p.sim.seed = 101; % 使用与标称定点用例相同的随机种子以实现单变量比较。
            p.adc.bits = 14; % 把检测ADC位宽降低到十四位。
            p.asic.demodWordLength = 22; % 收窄数字正交解调总字长。
            p.asic.demodFractionLength = 16; % 收窄数字正交解调小数位数。
        case 'virtual_precession' % 配置零外部输入下的虚拟进动注入与抵消用例。
            p.virtual.enable = true; % 使能周期虚拟进动。
            p.virtual.amplitudeDps = 20; % 把虚拟进动峰值提高到每秒二十度。
            p.input.rateFcn = @(t) 0 * t; % 将真实外部角速度设置为零。
            p.test.rateTransitionTimes = []; % 清除不存在的外部速率切换时刻。
            p.test.maxAngleRmsDeg = 0.75; % 设置虚拟进动抵消后的角度RMS回归上限。
            p.test.maxRateRmsDps = 5.0; % 设置虚拟进动抵消后的角速度RMS回归上限。
        case 'antiwindup_stress' % 配置初始高能量和PI输出饱和后的抗饱和恢复用例。
            p.res.energyInitial = 1.60; % 把初始驻波能量提高到目标值之上以驱动能量PI进入负向输出饱和。
            p.ctrl.startupTime = 0.02; % 缩短开环起振阶段以尽快进入闭环抗饱和恢复过程。
            p.ctrl.startupDrive = 0; % 关闭高能量初值用例中不必要的开环正向驱动。
            p.test.maxLockTime = 5.50; % 放宽高能量恢复用例的锁定时间门限。
            p.test.rateTransitionTimes = []; % 清除动态速率切换窗口以集中评价控制器饱和恢复。
            p.input.rateFcn = @(t) 0 * t; % 将外部输入角速度设置为零以隔离抗饱和控制行为。
        case 'dpll_dropout_freeze' % 配置检测信号丢失、DPLL冻结和FAULT安全关断用例。
            p.fault.enable = true; % 使能检测链路故障注入。
            p.fault.time = 3.5; % 在完成闭环锁定和一段正常RUN数据后丢失检测载波。
            p.fault.type = 'signal_dropout'; % 选择两路检测信号完全丢失故障类型。
            p.input.rateFcn = @(t) 0 * t; % 把外部输入角速度设置为零以便检查NCO冻结行为。
            p.test.rateTransitionTimes = []; % 清除不存在的动态速率切换窗口。
        case 'selftest_pass' % 配置真实检测链路SELFTEST正常通过并返回RUN的用例。
            p.selftest.enable = true; % 使能运行中自动SELFTEST触发。
            p.selftest.startTime = 3.0; % 在完成锁定后触发真实检测链路SELFTEST。
            p.selftest.injectionScale = 1.0; % 使用标称受限测试载波幅值覆盖AFE、ADC、NCO与解调链路。
            p.input.rateFcn = @(t) 0 * t; % 把外部角速度设置为零以提高SELFTEST同步相关可观测性。
            p.test.rateTransitionTimes = []; % 清除不存在的外部速率切换窗口。
        case 'selftest_fail' % 配置SELFTEST检测不到注入响应后进入FAULT并安全归零的用例。
            p.selftest.enable = true; % 使能运行中自动SELFTEST触发。
            p.selftest.startTime = 3.0; % 在完成锁定后触发真实检测链路SELFTEST。
            p.selftest.injectionScale = 0; % 人为阻断测试载波以验证SELFTEST失败检测而不是直接强制故障位。
            p.input.rateFcn = @(t) 0 * t; % 把外部角速度设置为零以避免物理驻波旋转伪装成SELFTEST响应。
            p.test.rateTransitionTimes = []; % 清除不存在的外部速率切换窗口。
        case 'loop_fault' % 配置控制环关闭与FAULT安全输出用例。
            p.fault.enable = true; % 使能故障注入。
            p.fault.time = 3.5; % 在完成锁定和一段RUN数据后关闭控制环。
            p.fault.type = 'loop_disable'; % 选择关闭能量与正交控制输出的故障类型。
        case 'online_calibration' % 配置V4.3检测/驱动矩阵、正弦自激同步解调、RLS/EKF和安全系数更新用例。
            p.calib.enable = true; % 打开在线标定总开关。
            p.calib.startTime = 2.20; % 在闭环进入RUN并略过锁定瞬态后启动在线标定。
            p.calib.updateDecimation = 4; % 每四个控制拍更新一次在线参数。
            p.calib.excitationAmplitude = 0.0015; % 使用更小幅正弦自激，避免在线辨识扰动污染主导航性能。
            p.calib.excitationFrequencyHz = 11.0; % 使用与控制和输入速率切换错开的同步解调频率。
            p.calib.matrixBlend = 0.006; % 使用保守矩阵写入速度，确保先辨识、后释放补偿。
            p.calib.ekfBlend = 0.006; % 使用保守物理参数写入速度，避免在线EKF补偿造成角度漂移。
            p.calib.matrixLimit = 0.020; % 将在线矩阵限制在接口小非理想邻域内，防止RLS受慢变量噪声驱动到边界。
            p.calib.compensationStartUpdates = 300; % 至少完成三百次更新后才允许检测/驱动/谐波补偿进入主通道。
            p.calib.compensationRampUpdates = 900; % 采用长斜坡释放补偿权重。
            p.calib.maxCompensationAlpha = 0.35; % 在线补偿最多小权重并入主闭环。
            p.calib.maxHarmonicCorrectionDps = 0.35; % 限制在线EKF速率补偿幅值。
            p.calib.maxDampingAnisotropy = 5.0e-4; % 在线回归使用物理可达阻尼不均匀安全包络。
            p.calib.maxFrequencySplitHz = 0.025; % 在线回归使用物理可达模态裂解安全包络。
            p.afe.crossMatrix = [1.0000 0.0060; -0.0040 1.0000]; % 增大检测矩阵非理想量以验证在线检测矩阵RLS链路。
            p.drive.crossMatrix = [1.0000 0.0060; -0.0040 1.0000]; % 增大驱动矩阵交叉耦合以验证在线驱动矩阵RLS链路。
            p.sim.duration = 8.0; % 延长在线标定用例以积累足够RLS/EKF更新拍。
            p.input.rateFcn = @(t) 0 * t; % 使用零速工况隔离阻尼不均匀和模态裂解辨识。
            p.test.rateTransitionTimes = []; % 清除不存在的外部速率切换窗口。
            p.test.maxAngleRmsDeg = 1.0; % 在线小扰动用例略放宽角度RMS门限。
            p.test.maxRateRmsDps = 5.0; % 保持角速度RMS门限。
            p.comp.trackPhysical = false; % 关闭补偿参数自动跟随真实物理量，迫使在线RLS/EKF从初始偏差收敛。
            p.comp.dampingAnisotropyHat = 0.5 * p.res.dampingAnisotropy; % 设置阻尼不均匀初值偏差以验证在线辨识。
            p.comp.frequencySplitHatHz = 0.5 * p.res.frequencySplitHz; % 设置模态裂解初值偏差以验证在线辨识。
            p.comp.dampingAxisHat = p.res.dampingAxis + 8 * pi / 180; % 设置阻尼主轴初始偏差。
            p.comp.stiffnessAxisHat = p.res.stiffnessAxis - 8 * pi / 180; % 设置刚度主轴初始偏差。
        case 'bittrue_asic' % 配置V4.4 CIC/FIR、整数NCO、迭代CORDIC、流水线valid、CDC和SPI事务用例。
            p.asic.bitTrueEnable = true; % 打开V4.4位真ASIC数据通路总开关。
            p.asic.fixedEnable = true; % 保持每级Q格式量化和溢出统计。
            p.asic.ncoPhaseBits = 32; % 使用三十二位整数NCO相位累加器。
            p.asic.ncoAmplitudeBits = 18; % 使用十八位NCO正弦/余弦幅度量化。
            p.asic.cicStages = 3; % 使用三级CIC抽取。
            p.asic.firCoefficients = [1 2 3 2 1] / 9; % 使用五抽头CIC后FIR补偿。
            p.asic.cordicIterations = 18; % 使用十八次微旋CORDIC相位解算。
            p.asic.validPipelineDepth = 5; % 打开五级控制域有效信号流水线诊断。
            p.asic.cdcEnable = true; % 打开CDC同步事务统计。
            p.asic.spiEnable = true; % 打开SPI寄存器事务统计。
            p.asic.spiTransactionPeriodCtrl = 200; % 使短回归内产生多次SPI维护事务。
            p.test.maxAngleRmsDeg = 1.2; % 位真多级滤波和CORDIC用例允许略大的角度RMS包络。
            p.test.maxRateRmsDps = 8.0; % 位真多级滤波和CORDIC用例允许略大的角速度RMS包络。
            p.test.maxRateErrorDps = 35.0; % 放宽最大瞬时速率误差以覆盖FIR群时延和量化阶跃。
            p.test.requireBitTrueActivity = true; % 要求CIC/FIR、NCO、CORDIC、valid、CDC和SPI均产生活动。
        case 'frp_joint_identification' % 配置V4.5检测/驱动多误差与正反转FRP联合辨识专用用例。
            p.sim.duration = 28.0; % 延长仿真以完成正向一周、平滑换向和反向一周的角位置覆盖。
            p.input.rateFcn = @(t) 0 * t; % 使用零外部真实角速度满足FRP自标定的可观测前提。
            p.test.rateTransitionTimes = []; % 清除不存在的外部角速度切换窗口。
            p.env.temperatureFcn = @(t) p.env.referenceTemperature + 12 * min(max((t - 2.0) / 24.0, 0), 1); % 在FRP过程中施加十二摄氏度慢速温扫以激励联合温度项。
            p.frp.enable = true; % 打开V4.5正反转FRP联合辨识总开关。
            p.frp.startTime = 2.20; % 在标称闭环进入RUN后启动FRP有限序列。
            p.frp.forwardDps = 30; % 使用第三路执行器量程内的正向平台角速度完成整周覆盖。
            p.frp.reverseDps = -30; % 使用幅值相同的反向平台分离方向不对称误差。
            p.frp.dwellSec = 12.0; % 每个方向驻留十二秒以在每秒三十度下覆盖完整圆周。
            p.frp.transitionSec = 0.25; % 使用四分之一秒余弦平滑换向抑制瞬态污染。
            p.frp.cycleCount = 1; % 使用一次正向和一次反向完整循环完成专用回归。
            p.frp.rlsLambda = 0.9999; % 延长联合RLS记忆以同时保留正向整周和反向整周的信息。
            p.frp.minimumSamples = 800; % 要求联合RLS至少积累八百个有效更新后才判可信。
            p.frp.compensationStartSamples = 800; % 在八百次更新前只辨识不注入补偿。
            p.frp.compensationRampSamples = 1200; % 使用一千二百次更新平滑释放联合补偿。
            p.frp.confidenceThreshold = 0.20; % 专用短记录使用保守但可达的综合可信门限。
            p.test.minimumFrpConfidence = 0.15; % 设置专用回归最低可信度以验证评分链路实际工作。
            p.afe.crossMatrix = [1.012 0.008; -0.006 0.988]; % 注入检测增益不一致与串扰误差。
            p.afe.assemblyAngleRad = 0.35 * pi / 180; % 注入检测电极装配角误差。
            p.afe.phaseDelayRad = [0.25; -0.18] * pi / 180; % 注入两检测通道不一致相位延迟。
            p.afe.gainTempCoeff = [100; -80] * 1e-6; % 注入两检测通道方向相反的增益温度系数。
            p.afe.phaseTempCoeffRad = [25; -20] * 1e-6; % 注入两检测通道方向相反的相位温度系数。
            p.afe.quadraticNonlinearity = [0.0010; -0.0008]; % 注入小幅检测二次非线性。
            p.afe.cubicNonlinearity = [0.0005; -0.0004]; % 注入小幅检测三次非线性。
            p.drive.crossMatrix = [1.006 0.004; -0.003 0.994]; % 注入驱动增益不一致与交叉耦合。
            p.drive.assemblyAngleRad = 0.20 * pi / 180; % 注入驱动电极装配角误差。
            p.drive.phaseDelayRad = 0.25 * pi / 180; % 注入驱动等效相位延迟。
            p.drive.gainTempCoeff = [60; -50] * 1e-6; % 注入两驱动通道增益温度系数。
            p.drive.phaseTempCoeffRad = 15e-6; % 注入驱动相位延迟温度系数。
            p.drive.quadraticNonlinearity = [0.0008; -0.0006]; % 注入小幅驱动二次非线性。
            p.drive.cubicNonlinearity = [0.0004; -0.0003]; % 注入小幅驱动三次非线性。
            p.test.maxAngleRmsDeg = 12.0; % 放宽专用辨识过程角度RMS包络以容纳未释放阶段的累计误差。
            p.test.maxRateRmsDps = 10.0; % 设置多误差FRP过程角速度RMS安全包络。
            p.test.maxRateErrorDps = 50.0; % 设置正反转换向附近最大角速度误差安全包络。
    end % 结束当前用例差异化配置。
    HRG_WA_v45_validate_params(p, true); % 在执行仿真前检查当前用例参数一致性与动态裕量。
    caseParams{c} = p; % 保存当前用例送入仿真器的完整参数结构体。
    result = HRG_WA_v45_simulate(p); % 运行当前用例的多速率闭环仿真。
    m = result.metrics; % 取得当前用例的分层性能与诊断指标。
    metrics{c} = m; % 保存当前用例完整指标供版本间数值对比。
    functionalPassed(c) = m.passFunctional; % 记录锁定、有限数值和连续展开功能是否通过。
    performancePassed(c) = m.passPerformance; % 记录角度、速率、E、Q、相位和饱和性能是否通过。
    if strcmp(caseNames{c}, 'loop_fault') % 判断当前是否为显式控制环关闭故障安全用例。
        expectedFaultTime = p.fault.time + (p.protect.consecutiveFaults - 1) * p.sim.TsCtrl; % 根据连续故障消抖拍数计算预期FAULT锁存时刻。
        faultTimingValid = m.faulted && abs(m.faultTime - expectedFaultTime) <= 1.5 * p.sim.TsCtrl; % 检查FAULT是否在故障注入并经过规定消抖拍数后锁存。
        passed(c) = m.passFaultSafety && faultTimingValid; % 故障用例要求先锁定、进入FAULT、数值有限且三路控制字安全归零。
    elseif strcmp(caseNames{c}, 'dpll_dropout_freeze') % 判断当前是否为检测载波丢失与DPLL冻结用例。
        expectedFaultTime = p.fault.time + (p.protect.consecutiveFaults - 1) * p.sim.TsCtrl; % 根据连续故障消抖拍数计算检测丢失预期FAULT时刻。
        faultTimingValid = m.faulted && abs(m.faultTime - expectedFaultTime) <= 1.5 * p.sim.TsCtrl; % 检查检测信号丢失后是否按规定消抖拍数锁存FAULT。
        ncoBeforeFault = result.log.ncoFrequencyHz(find(result.log.t < p.fault.time, 1, 'last')); % 读取检测信号丢失前最后一拍NCO频率控制字。
        freezeMask = result.log.pllFrozen & result.log.t >= p.fault.time; % 选择检测信号丢失后的DPLL冻结控制拍。
        ncoHeld = any(freezeMask) && max(abs(result.log.ncoFrequencyHz(freezeMask) - ncoBeforeFault)) <= 1e-12; % 检查冻结期间NCO频率控制字是否逐拍保持不变。
        passed(c) = m.passFaultSafety && faultTimingValid && m.pllFreezeCount > 0 && ncoHeld; % 要求故障安全、时序正确、冻结发生且NCO控制字保持。
    elseif strcmp(caseNames{c}, 'selftest_pass') % 判断当前是否为SELFTEST正常通过用例。
        passed(c) = m.passSelftest; % 要求SELFTEST完成、同步相关判定通过、返回RUN且未触发FAULT。
    elseif strcmp(caseNames{c}, 'selftest_fail') % 判断当前是否为SELFTEST失败安全路径用例。
        passed(c) = m.passSelftestFailureSafety; % 要求检测不到测试载波时SELFTEST失败、进入FAULT并安全归零。
    elseif strcmp(caseNames{c}, 'antiwindup_stress') % 判断当前是否为完整抗饱和恢复压力用例。
        integratorsBounded = max(abs(result.log.energyIntegrator)) <= p.ctrl.integratorLimit + eps && max(abs(result.log.quadIntegrator)) <= p.ctrl.integratorLimit + eps; % 检查两路PI积分器始终保持在配置限幅范围内。
        passed(c) = m.passFunctional && m.antiWindupCount > 0 && m.controlOutputLimitCount > 0 && m.controlSlewLimitCount > 0 && integratorsBounded; % 要求系统经积分器冻结的受限捕获恢复锁定、控制约束实际动作且积分器没有越界。
    elseif strcmp(caseNames{c}, 'online_calibration') % 判断当前是否为V4.3在线标定专用用例。
        passed(c) = m.passOnlineCalibration && m.passPerformance; % 要求在线标定自身判据和普通闭环性能同时通过。
    elseif strcmp(caseNames{c}, 'bittrue_asic') % 判断当前是否为V4.4位真ASIC专用用例。
        passed(c) = m.passBitTrueAsic && m.passPerformance; % 要求CIC/FIR、整数NCO、CORDIC、流水线valid、CDC和SPI事务活动且闭环性能通过。
    elseif strcmp(caseNames{c}, 'frp_joint_identification') % 判断当前是否为V4.5多误差FRP联合辨识专用用例。
        passed(c) = m.passFrpJointIdentification && m.passPerformance; % 要求正反转、覆盖、联合RLS、条件数、可信度、限幅和普通闭环性能全部通过。
    elseif strcmp(caseNames{c}, 'virtual_precession') % 判断当前是否为虚拟进动抵消用例。
        cancellationValid = abs(m.meanRateErrorDps) <= 0.75 && abs(m.finalAngleErrorDeg) <= 1.0; % 检查虚拟进动抵消后的平均速率和累计角度是否接近零。
        passed(c) = m.passPerformance && cancellationValid; % 虚拟进动用例同时要求性能门限和零均值抵消关系通过。
    elseif strcmp(caseNames{c}, 'high_dynamic_wrap') % 判断当前是否为高动态展开用例。
        scaleValid = abs(m.meanRateErrorDps) <= 0.05 * 1200; % 检查高动态平均速率尺度误差不超过输入的百分之五。
        passed(c) = m.passPerformance && scaleValid; % 高动态用例同时要求连续展开、性能包络和尺度关系通过。
    else % 处理理想、标称定点和十四位ADC用例。
        passed(c) = m.passPerformance; % 普通用例直接采用完整性能回归判据。
    end % 结束当前用例最终通过判据选择。
    summary{c} = sprintf('%s: PASS=%d, FUNC=%d, PERF=%d, lock=%.3fs, fault=%d, faultTime=%.3fs, angleRMS=%.4gdeg, rateRMS=%.4gdeg/s, fixedOv=%d, unwrap=%d, valid=%.5f, freeze=%d, aw=%d, track=%d, kfReject=%d, selftest=%d/%d, calib=%d upd=%d sf=%.3g splitHat=%.4gHz, bittrue=%d cic=%d fir=%d cordic=%d spi=%d cdcErr=%d spiErr=%d, frp=%d upd=%d cov=%.3f conf=%.3f resid=%.4gdeg/s', caseNames{c}, passed(c), functionalPassed(c), performancePassed(c), m.lockTime, m.faulted, m.faultTime, m.rmsAngleErrorDeg, m.rmsRateErrorDps, m.fixedOverflowCount, m.unwrapFaultCount, m.measurementValidFraction, m.pllFreezeCount, m.antiWindupCount, m.actuatorTrackingCount, m.kalmanRejectCount, m.selftestExecuted, m.selftestPassed, m.calibEnabled, m.calibUpdateCount, m.calibSafetyFactorFinal, m.calibFrequencySplitFinalHz, m.bitTrueEnabled, m.bitTrueCicValidCount, m.bitTrueFirValidCount, m.bitTrueCordicIterationCount, m.bitTrueSpiTransactionCount, m.bitTrueCdcErrorCount, m.bitTrueSpiErrorCount, m.frpEnabled, m.frpUpdateCount, m.frpCoverageFraction, m.frpConfidence, m.frpResidualRmsDps); % 生成包含测量可信度、故障、在线标定、位真ASIC和V4.5 FRP字段的回归摘要。
    fprintf('%s\n', summary{c}); % 在命令窗口打印当前用例摘要。
    failedPerformanceFields = fieldnames(m.performanceChecks); % 取得当前用例全部性能子判据字段名称。
    failedPerformanceMask = ~structfun(@logical, m.performanceChecks); % 标记当前用例没有通过的性能子判据。
    failedPerformanceFields = failedPerformanceFields(failedPerformanceMask); % 仅保留失败的性能字段名称。
    if ~isempty(failedPerformanceFields) % 判断是否需要输出性能失败根因定位信息。
        fprintf('  性能失败项=%s，Emean=%.6g，Erel=%+.6g，Qrms=%.6g，phaseRMS=%.6g，maxRate=%.6gdeg/s，adcSat=%d，dacSat=%d\n', strjoin(failedPerformanceFields.', ','), m.energyMean, m.energyRelativeError, m.quadRms, m.phaseErrorRms, m.maxRateErrorDps, m.adcSaturationCount, m.dacSaturationCount); % 输出完整性能子判据，避免只看角度和速率RMS误判。
    end % 结束性能失败根因定位输出。
    if strcmp(caseNames{c}, 'online_calibration') % 判断是否输出在线标定专用诊断。
        fprintf('  在线标定诊断：upd=%d，detErr=%.6g，drvErr=%.6g，dampHat=%.6g，dampErr=%.6g，splitHat=%.6gHz，splitErr=%.6gHz，safety=%.6g，modeMatch=%.6g，alpha=%.6g，syncE=%.6g，syncQ=%.6g\n', m.calibUpdateCount, m.calibDetectionMatrixError, m.calibDriveMatrixError, m.calibDampingAnisotropyFinal, m.calibDampingError, m.calibFrequencySplitFinalHz, m.calibSplitErrorHz, m.calibSafetyFactorFinal, m.calibModeMatchFactorFinal, m.calibCompensationAlphaFinal, m.calibSyncEnergyGainFinal, m.calibSyncQuadGainFinal); % 输出RLS/EKF、同步解调、安全系数和补偿释放权重诊断。
    end % 结束在线标定诊断输出。
    if strcmp(caseNames{c}, 'bittrue_asic') % 判断是否输出V4.4位真ASIC专用诊断。
        fprintf('  位真ASIC诊断：cic=%d，fir=%d，cordicIter=%d，ncoWrap=%d，validPipe=%d，cdc=%d，cdcErr=%d，spi=%d，spiErr=%d\n', m.bitTrueCicValidCount, m.bitTrueFirValidCount, m.bitTrueCordicIterationCount, m.bitTrueNcoWrapCount, m.bitTruePipelineValidCount, m.bitTrueCdcEventCount, m.bitTrueCdcErrorCount, m.bitTrueSpiTransactionCount, m.bitTrueSpiErrorCount); % 输出CIC/FIR、整数NCO、CORDIC、流水线valid、CDC和SPI事务诊断。
    end % 结束位真ASIC诊断输出。
    if strcmp(caseNames{c}, 'frp_joint_identification') % 判断是否输出V4.5多误差FRP联合辨识专用诊断。
        fprintf('  FRP联合辨识诊断：active=%d，stable=%d，forward=%d，reverse=%d，transition=%d，upd=%d，coverage=%.6f，condition=%.6g，confidence=%.6f，residual=%.6gdeg/s，transitionPeak=%.6gdeg/s，trustedSamples=%d，released=%d，alpha=%.6f，corrMax=%.6gdeg/s，bias/s4/c4/s8/c8/dir=[%s]deg/s，temp=%.6gdeg/s/C\n', m.frpActiveCount, m.frpStableCount, m.frpForwardCount, m.frpReverseCount, m.frpTransitionCount, m.frpUpdateCount, m.frpCoverageFraction, m.frpConditionNumber, m.frpConfidence, m.frpResidualRmsDps, m.frpTransitionPeakDps, m.frpTrustedSampleCount, m.frpCompensationReleased, m.frpCompensationAlpha, m.frpCorrectionMaxDps, sprintf(' %.6g', m.frpParameterHatDps), m.frpTemperatureHatDpsPerC); % 输出FRP方向覆盖、联合参数、数值条件、可信度、独立换向峰值和补偿安全释放诊断。
        failedFrpFields = fieldnames(m.frpChecks); % 取得FRP专用活动、双向、更新、覆盖、条件数、可信度、残差、换向峰值、补偿释放和有限数判据名称。
        failedFrpMask = ~structfun(@logical, m.frpChecks); % 标记没有通过的FRP专用子判据。
        failedFrpFields = failedFrpFields(failedFrpMask); % 仅保留失败的FRP子判据名称。
        if ~isempty(failedFrpFields) % 判断是否需要输出FRP专用失败根因。
            fprintf('  FRP失败项=%s\n', strjoin(failedFrpFields.', ',')); % 直接打印FRP专用失败字段，避免只从总PASS反推原因。
        end % 结束FRP专用失败字段输出。
    end % 结束V4.5 FRP诊断输出。
    if ~m.locked % 判断当前用例是否需要输出捕获阶段的锁定条件诊断。
        fprintf('  未锁定诊断：E曾满足=%d，Q曾满足=%d，相位曾满足=%d，同拍满足=%d，末态E=%.6g，末态Q=%.6g，末态相位误差=%.6g，ACQUIRE拍数=%d\n', m.energyLockConditionSeen, m.quadLockConditionSeen, m.phaseLockConditionSeen, m.simultaneousLockConditionSeen, m.finalEnergy, m.finalQuad, m.finalPhaseError, m.acquireSampleCount); % 输出未锁定根因所需的四项窗口和末态量。
    end % 结束未锁定条件诊断输出。
end % 结束十组闭环性能与测量可信度回归测试循环。
nominalIndex = find(strcmp(caseNames, 'nominal_fixed'), 1); % 查找标称定点用例索引。
adc14Index = find(strcmp(caseNames, 'adc14_stress'), 1); % 查找十四位ADC压力用例索引。
comparison.nominalRateRmsDps = metrics{nominalIndex}.rmsRateErrorDps; % 记录标称十八位ADC用例角速度RMS。
comparison.adc14RateRmsDps = metrics{adc14Index}.rmsRateErrorDps; % 记录相同随机种子下十四位ADC用例角速度RMS。
comparison.rateRmsDeltaDps = comparison.adc14RateRmsDps - comparison.nominalRateRmsDps; % 计算仅由ADC和解调字长变化共同导致的角速度RMS差值。
fprintf('同随机种子ADC压力对比：nominal=%.6g deg/s，adc14=%.6g deg/s，差值=%+.6g deg/s\n', comparison.nominalRateRmsDps, comparison.adc14RateRmsDps, comparison.rateRmsDeltaDps); % 打印可解释的同种子ADC压力对比。
noiseParams = base; % 复制基准参数用于Allan与PSD短记录功能回归。
noiseParams.input.rateFcn = @(t) 0 * t; % 把噪声分析功能回归的外部角速度设置为零。
noiseParams.test.rateTransitionTimes = []; % 清除噪声分析功能回归中不存在的动态切换窗口。
noiseReferenceTemperature = noiseParams.env.referenceTemperature; % 保存噪声分析功能回归使用的常值参考温度。
noiseParams.env.temperatureFcn = @(t) noiseReferenceTemperature + 0 * t; % 固定温度以形成连续稳定噪声数据段。
noiseResult = HRG_WA_v45_simulate(noiseParams); % 生成Allan与PSD功能回归所需的连续零速闭环日志。
noiseAnalysis = HRG_WA_v45_noise_analysis(noiseResult.log, noiseParams); % 对零速闭环日志执行Allan偏差与Welch功率谱分析。
noisePassed = noiseAnalysis.valid && all(isfinite(noiseAnalysis.tauSec)) && all(isfinite(noiseAnalysis.allanDeviationDps)) && all(isfinite(noiseAnalysis.psdFrequencyHz)) && all(isfinite(noiseAnalysis.psdDps2PerHz)); % 检查Allan与PSD输出存在且全部为有限数值。
fprintf('noise_analysis: PASS=%d, samples=%d, AllanPoints=%d, PSDPoints=%d\n', noisePassed, noiseAnalysis.sampleCount, numel(noiseAnalysis.tauSec), numel(noiseAnalysis.psdFrequencyHz)); % 打印Allan与PSD功能回归摘要。
monteCarloUser = user; % 复制基础用户表头用于小规模多种子Monte Carlo冒烟回归。
monteCarloUser.monteCarlo.enableParameterSpread = false; % 冒烟回归仅改变随机种子以降低参数角点导致的版本门限耦合。
monteCarloUser.monteCarlo.minimumPassRate = 0.66; % 要求三种子冒烟回归至少三分之二用例通过完整性能门限。
monteCarloReport = run_HRG_WA_v45_monte_carlo(3, monteCarloUser); % 执行三组确定性随机种子的Monte Carlo冒烟回归。
monteCarloPassed = monteCarloReport.seedCount == 3 && monteCarloReport.pass && all(isfinite(monteCarloReport.rateRmsDps)); % 检查Monte Carlo运行次数、通过率和关键指标有限性。
fprintf('monte_carlo_smoke: PASS=%d, passRate=%.3f, rateRmsP95=%.6gdeg/s\n', monteCarloPassed, monteCarloReport.passRate, monteCarloReport.summary.rateRmsP95Dps); % 打印多种子Monte Carlo冒烟回归摘要。
matlabVersion = version; % 记录执行回归时使用的MATLAB版本字符串。
save('HRG_WA_v45_test_result.mat', 'matlabVersion', 'user', 'caseNames', 'caseParams', 'passed', 'functionalPassed', 'performancePassed', 'metrics', 'comparison', 'summary', 'noiseAnalysis', 'noisePassed', 'monteCarloReport', 'monteCarloPassed'); % 在断言前保存基础回归、噪声分析和多种子Monte Carlo结果以支持失败复盘。
assert(all(passed) && noisePassed && monteCarloPassed, '至少一个HRG全角数字ASIC V4.5回归未通过，请检查性能字段、测量可信度、在线标定、位真ASIC或多误差FRP联合辨识的覆盖度、条件数、可信度和安全补偿字段。'); % 要求十三组闭环回归、噪声分析和多种子Monte Carlo全部通过。
