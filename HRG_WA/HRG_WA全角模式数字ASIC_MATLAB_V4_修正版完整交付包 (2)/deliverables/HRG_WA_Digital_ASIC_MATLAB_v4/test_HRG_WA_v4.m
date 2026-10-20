clear; % 清除工作区变量，保证回归用例互不污染。
clc; % 清空命令窗口，便于阅读分层测试报告。
user = HRG_WA_v4_user_config(); % 加载集中式用户参数表头作为回归基础。
user.sim.seed = 101; % 为全部可比较用例设置相同随机种子以隔离参数变化影响。
user.sim.duration = 6.0; % 设置回归总时长，兼顾锁定、三个速率平台和故障验证。
user.input.rateTransitionTimesSec = [2.0 3.6 4.8]; % 把第一段非零速率安排在标称锁定之后，避免把捕获瞬态误算为动态误差。
user.input.rateLevelsDps = [0 60 -35 100]; % 设置普通回归用例的统一分段角速度，单位为度每秒。
base = HRG_WA_v4_params(user); % 把用户表头转换为内部统一参数并执行一致性检查。
caseNames = {'ideal_float', 'nominal_fixed', 'high_dynamic_wrap', 'adc14_stress', 'virtual_precession', 'loop_fault'}; % 定义六组功能、性能、压力和故障回归用例。
passed = false(size(caseNames)); % 预分配各用例最终通过标志。
functionalPassed = false(size(caseNames)); % 预分配各用例功能层通过标志。
performancePassed = false(size(caseNames)); % 预分配各用例性能层通过标志。
metrics = cell(size(caseNames)); % 预分配各用例完整指标结构体。
summary = cell(numel(caseNames), 1); % 预分配各用例文字摘要。
caseParams = cell(size(caseNames)); % 预分配各用例实际参数快照以支持数值回归追溯。
for c = 1:numel(caseNames) % 逐个执行六组回归测试。
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
        case 'loop_fault' % 配置控制环关闭与FAULT安全输出用例。
            p.fault.enable = true; % 使能故障注入。
            p.fault.time = 3.5; % 在完成锁定和一段RUN数据后关闭控制环。
            p.fault.type = 'loop_disable'; % 选择关闭能量与正交控制输出的故障类型。
            p.protect.energyMin = 0.99; % 提高低能量故障门限以在有限仿真时长内进入FAULT。
    end % 结束当前用例差异化配置。
    HRG_WA_v4_validate_params(p, true); % 在执行仿真前检查当前用例参数一致性与动态裕量。
    caseParams{c} = p; % 保存当前用例送入仿真器的完整参数结构体。
    result = HRG_WA_v4_simulate(p); % 运行当前用例的多速率闭环仿真。
    m = result.metrics; % 取得当前用例的分层性能与诊断指标。
    metrics{c} = m; % 保存当前用例完整指标供版本间数值对比。
    functionalPassed(c) = m.passFunctional; % 记录锁定、有限数值和连续展开功能是否通过。
    performancePassed(c) = m.passPerformance; % 记录角度、速率、E、Q、相位和饱和性能是否通过。
    if strcmp(caseNames{c}, 'loop_fault') % 判断当前是否为故障安全用例。
        faultTimingValid = m.faulted && m.faultTime >= p.fault.time && m.faultTime <= p.sim.duration; % 检查FAULT是否在注入后且仿真结束前发生。
        passed(c) = m.passFaultSafety && faultTimingValid; % 故障用例要求先锁定、进入FAULT、数值有限且三路控制字安全归零。
    elseif strcmp(caseNames{c}, 'virtual_precession') % 判断当前是否为虚拟进动抵消用例。
        cancellationValid = abs(m.meanRateErrorDps) <= 0.75 && abs(m.finalAngleErrorDeg) <= 1.0; % 检查虚拟进动抵消后的平均速率和累计角度是否接近零。
        passed(c) = m.passPerformance && cancellationValid; % 虚拟进动用例同时要求性能门限和零均值抵消关系通过。
    elseif strcmp(caseNames{c}, 'high_dynamic_wrap') % 判断当前是否为高动态展开用例。
        scaleValid = abs(m.meanRateErrorDps) <= 0.05 * 1200; % 检查高动态平均速率尺度误差不超过输入的百分之五。
        passed(c) = m.passPerformance && scaleValid; % 高动态用例同时要求连续展开、性能包络和尺度关系通过。
    else % 处理理想、标称定点和十四位ADC用例。
        passed(c) = m.passPerformance; % 普通用例直接采用完整性能回归判据。
    end % 结束当前用例最终通过判据选择。
    summary{c} = sprintf('%s: PASS=%d, FUNC=%d, PERF=%d, lock=%.3fs, fault=%d, faultTime=%.3fs, angleRMS=%.4gdeg, rateRMS=%.4gdeg/s, fixedOv=%d, unwrap=%d', caseNames{c}, passed(c), functionalPassed(c), performancePassed(c), m.lockTime, m.faulted, m.faultTime, m.rmsAngleErrorDeg, m.rmsRateErrorDps, m.fixedOverflowCount, m.unwrapFaultCount); % 生成包含分层结论、故障时刻和真实定点溢出的测试摘要。
    fprintf('%s\n', summary{c}); % 在命令窗口打印当前用例摘要。
end % 结束六组回归测试循环。
nominalIndex = find(strcmp(caseNames, 'nominal_fixed'), 1); % 查找标称定点用例索引。
adc14Index = find(strcmp(caseNames, 'adc14_stress'), 1); % 查找十四位ADC压力用例索引。
comparison.nominalRateRmsDps = metrics{nominalIndex}.rmsRateErrorDps; % 记录标称十八位ADC用例角速度RMS。
comparison.adc14RateRmsDps = metrics{adc14Index}.rmsRateErrorDps; % 记录相同随机种子下十四位ADC用例角速度RMS。
comparison.rateRmsDeltaDps = comparison.adc14RateRmsDps - comparison.nominalRateRmsDps; % 计算仅由ADC和解调字长变化共同导致的角速度RMS差值。
fprintf('同随机种子ADC压力对比：nominal=%.6g deg/s，adc14=%.6g deg/s，差值=%+.6g deg/s\n', comparison.nominalRateRmsDps, comparison.adc14RateRmsDps, comparison.rateRmsDeltaDps); % 打印可解释的同种子ADC压力对比。
matlabVersion = version; % 记录执行回归时使用的MATLAB版本字符串。
save('HRG_WA_v4_test_result.mat', 'matlabVersion', 'user', 'caseNames', 'caseParams', 'passed', 'functionalPassed', 'performancePassed', 'metrics', 'comparison', 'summary'); % 在断言前保存版本、种子来源、实际参数和分层结果，失败用例也可复盘。
assert(all(passed), '至少一个HRG全角数字ASIC V4回归测试未通过，请查看已保存MAT文件中的FUNC、PERF及具体性能检查字段。'); % 要求六组功能、性能与故障安全回归全部通过。
