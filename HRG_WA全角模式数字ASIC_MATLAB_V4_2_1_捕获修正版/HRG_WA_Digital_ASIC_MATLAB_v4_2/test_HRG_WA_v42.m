clear; % 清除工作区变量，保证回归用例互不污染。
clc; % 清空命令窗口，便于阅读分层测试报告。
verify_HRG_WA_v42_install(); % 在回归开始前检查MATLAB实际解析路径和V4.2测量可信度修订标志。
user = HRG_WA_v42_user_config(); % 加载集中式用户参数表头作为回归基础。
user.sim.seed = 101; % 为全部可比较用例设置相同随机种子以隔离参数变化影响。
user.sim.duration = 6.0; % 设置回归总时长，兼顾锁定、三个速率平台和故障验证。
user.input.rateTransitionTimesSec = [2.0 3.6 4.8]; % 把第一段非零速率安排在标称锁定之后，避免把捕获瞬态误算为动态误差。
user.input.rateLevelsDps = [0 60 -35 100]; % 设置普通回归用例的统一分段角速度，单位为度每秒。
base = HRG_WA_v42_params(user); % 把用户表头转换为内部统一参数并执行一致性检查。
fprintf('模型修订=%s\n', base.meta.revision); % 打印明确维护版本以便回归记录能够识别新旧代码。
caseNames = {'ideal_float', 'nominal_fixed', 'high_dynamic_wrap', 'adc14_stress', 'virtual_precession', 'antiwindup_stress', 'dpll_dropout_freeze', 'selftest_pass', 'selftest_fail', 'loop_fault'}; % 定义十组基础性能、可信度、SELFTEST和故障安全回归用例。
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
    end % 结束当前用例差异化配置。
    HRG_WA_v42_validate_params(p, true); % 在执行仿真前检查当前用例参数一致性与动态裕量。
    caseParams{c} = p; % 保存当前用例送入仿真器的完整参数结构体。
    result = HRG_WA_v42_simulate(p); % 运行当前用例的多速率闭环仿真。
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
    elseif strcmp(caseNames{c}, 'virtual_precession') % 判断当前是否为虚拟进动抵消用例。
        cancellationValid = abs(m.meanRateErrorDps) <= 0.75 && abs(m.finalAngleErrorDeg) <= 1.0; % 检查虚拟进动抵消后的平均速率和累计角度是否接近零。
        passed(c) = m.passPerformance && cancellationValid; % 虚拟进动用例同时要求性能门限和零均值抵消关系通过。
    elseif strcmp(caseNames{c}, 'high_dynamic_wrap') % 判断当前是否为高动态展开用例。
        scaleValid = abs(m.meanRateErrorDps) <= 0.05 * 1200; % 检查高动态平均速率尺度误差不超过输入的百分之五。
        passed(c) = m.passPerformance && scaleValid; % 高动态用例同时要求连续展开、性能包络和尺度关系通过。
    else % 处理理想、标称定点和十四位ADC用例。
        passed(c) = m.passPerformance; % 普通用例直接采用完整性能回归判据。
    end % 结束当前用例最终通过判据选择。
    summary{c} = sprintf('%s: PASS=%d, FUNC=%d, PERF=%d, lock=%.3fs, fault=%d, faultTime=%.3fs, angleRMS=%.4gdeg, rateRMS=%.4gdeg/s, fixedOv=%d, unwrap=%d, valid=%.5f, freeze=%d, aw=%d, track=%d, kfReject=%d, selftest=%d/%d', caseNames{c}, passed(c), functionalPassed(c), performancePassed(c), m.lockTime, m.faulted, m.faultTime, m.rmsAngleErrorDeg, m.rmsRateErrorDps, m.fixedOverflowCount, m.unwrapFaultCount, m.measurementValidFraction, m.pllFreezeCount, m.antiWindupCount, m.actuatorTrackingCount, m.kalmanRejectCount, m.selftestExecuted, m.selftestPassed); % 生成包含测量可信度、故障和SELFTEST字段的回归摘要。
    fprintf('%s\n', summary{c}); % 在命令窗口打印当前用例摘要。
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
noiseResult = HRG_WA_v42_simulate(noiseParams); % 生成Allan与PSD功能回归所需的连续零速闭环日志。
noiseAnalysis = HRG_WA_v42_noise_analysis(noiseResult.log, noiseParams); % 对零速闭环日志执行Allan偏差与Welch功率谱分析。
noisePassed = noiseAnalysis.valid && all(isfinite(noiseAnalysis.tauSec)) && all(isfinite(noiseAnalysis.allanDeviationDps)) && all(isfinite(noiseAnalysis.psdFrequencyHz)) && all(isfinite(noiseAnalysis.psdDps2PerHz)); % 检查Allan与PSD输出存在且全部为有限数值。
fprintf('noise_analysis: PASS=%d, samples=%d, AllanPoints=%d, PSDPoints=%d\n', noisePassed, noiseAnalysis.sampleCount, numel(noiseAnalysis.tauSec), numel(noiseAnalysis.psdFrequencyHz)); % 打印Allan与PSD功能回归摘要。
monteCarloUser = user; % 复制基础用户表头用于小规模多种子Monte Carlo冒烟回归。
monteCarloUser.monteCarlo.enableParameterSpread = false; % 冒烟回归仅改变随机种子以降低参数角点导致的版本门限耦合。
monteCarloUser.monteCarlo.minimumPassRate = 0.66; % 要求三种子冒烟回归至少三分之二用例通过完整性能门限。
monteCarloReport = run_HRG_WA_v42_monte_carlo(3, monteCarloUser); % 执行三组确定性随机种子的Monte Carlo冒烟回归。
monteCarloPassed = monteCarloReport.seedCount == 3 && monteCarloReport.pass && all(isfinite(monteCarloReport.rateRmsDps)); % 检查Monte Carlo运行次数、通过率和关键指标有限性。
fprintf('monte_carlo_smoke: PASS=%d, passRate=%.3f, rateRmsP95=%.6gdeg/s\n', monteCarloPassed, monteCarloReport.passRate, monteCarloReport.summary.rateRmsP95Dps); % 打印多种子Monte Carlo冒烟回归摘要。
matlabVersion = version; % 记录执行回归时使用的MATLAB版本字符串。
save('HRG_WA_v42_test_result.mat', 'matlabVersion', 'user', 'caseNames', 'caseParams', 'passed', 'functionalPassed', 'performancePassed', 'metrics', 'comparison', 'summary', 'noiseAnalysis', 'noisePassed', 'monteCarloReport', 'monteCarloPassed'); % 在断言前保存基础回归、噪声分析和多种子Monte Carlo结果以支持失败复盘。
assert(all(passed) && noisePassed && monteCarloPassed, '至少一个HRG全角数字ASIC V4.2测量可信度回归未通过，请检查MAT文件中的性能字段、冻结、抗饱和、Kalman、SELFTEST、Allan/PSD或Monte Carlo结果。'); % 要求十组闭环回归、噪声分析和多种子Monte Carlo全部通过。
