clear; % 清除工作区变量，保证回归用例互不污染。
clc; % 清空命令窗口，便于阅读测试报告。
base = HRG_WA_v3_params(); % 加载标称模型参数作为所有用例的基础。
caseNames = {'ideal_float', 'nominal_fixed', 'high_dynamic_wrap', 'adc14_stress', 'virtual_precession', 'loop_fault'}; % 定义六组回归测试名称。
passed = false(size(caseNames)); % 预分配各测试用例通过标志。
summary = cell(numel(caseNames), 1); % 预分配各测试用例的文字摘要。
for c = 1:numel(caseNames) % 逐个执行回归测试用例。
    p = base; % 为当前用例复制一份独立参数。
    p.sim.duration = 5.0; % 缩短回归用例时长以提高执行效率。
    p.test.rateTransitionTimes = [1.2 2.8 4.0]; % 设置回归用例的角速度切换时刻。
    p.input.rateFcn = @(t) ((t >= 1.2 & t < 2.8) * 60 + (t >= 2.8 & t < 4.0) * (-35) + (t >= 4.0) * 100) * pi / 180; % 定义回归用例的统一分段速率输入。
    switch caseNames{c} % 根据用例名称配置差异化参数。
        case 'ideal_float' % 配置理想浮点基准用例。
            p.asic.fixedEnable = false; % 关闭ASIC定点量化。
            p.afe.enable = false; % 关闭AFE非理想模型。
            p.afe.offset = [0; 0]; % 清除AFE偏置。
            p.afe.noiseSigma = [0; 0]; % 清除AFE白噪声。
            p.res.dampingAnisotropy = 0; % 清除阻尼不均匀。
            p.res.frequencySplitHz = 0; % 清除频率裂解。
            p.res.processEnergyNoise = 0; % 清除能量过程噪声。
            p.res.processQuadNoise = 0; % 清除正交过程噪声。
            p.res.processThetaNoise = 0; % 清除驻波角过程噪声。
        case 'nominal_fixed' % 配置标称定点ASIC用例。
            p.sim.seed = 101; % 设置标称定点用例的独立随机种子。
        case 'high_dynamic_wrap' % 配置高动态连续展开用例。
            p.input.rateFcn = @(t) (t >= 1.2) * 1200 * pi / 180; % 施加每秒一千二百度的高动态恒定速率。
            p.test.rateTransitionTimes = 1.2; % 记录高动态用例唯一的速率切换时刻。
        case 'adc14_stress' % 配置十四位ADC量化压力用例。
            p.adc.bits = 14; % 将ADC位宽降低到十四位。
            p.asic.demodWordLength = 22; % 收窄数字解调总字长。
            p.asic.demodFractionLength = 16; % 收窄数字解调小数位数。
        case 'virtual_precession' % 配置零均值虚拟进动用例。
            p.virtual.enable = true; % 使能周期虚拟进动。
            p.virtual.amplitudeDps = 20; % 提高虚拟进动峰值以覆盖调制通道。
            p.input.rateFcn = @(t) 0 * t; % 将真实外部角速度设置为零。
            p.test.rateTransitionTimes = []; % 清除不存在的输入速率切换时刻。
        case 'loop_fault' % 配置控制环关闭故障用例。
            p.fault.enable = true; % 使能故障注入。
            p.fault.time = 3.0; % 在三秒时注入故障。
            p.fault.type = 'loop_disable'; % 选择关闭能量与正交控制环的故障类型。
            p.protect.energyMin = 0.99; % 提高低能量故障门限以在有限时长内验证故障路径。
    end % 结束当前测试用例参数配置。
    result = HRG_WA_v3_simulate(p); % 运行当前测试用例的闭环仿真。
    m = result.metrics; % 取得当前测试用例的指标。
    if strcmp(caseNames{c}, 'loop_fault') % 判断当前是否为故障注入用例。
        passed(c) = m.locked && m.faulted && m.allFinite; % 故障用例要求先锁定、后进入FAULT且所有数值有限。
    else % 处理其余功能与压力测试用例。
        passed(c) = m.locked && ~m.faulted && m.allFinite && m.unwrapFaultCount == 0; % 正常用例要求锁定、无故障、数值有限且无展开异常。
    end % 结束测试通过判据选择。
    summary{c} = sprintf('%s: PASS=%d, lock=%.3fs, angleRMS=%.4gdeg, rateRMS=%.4gdeg/s, unwrap=%d', caseNames{c}, passed(c), m.lockTime, m.rmsAngleErrorDeg, m.rmsRateErrorDps, m.unwrapFaultCount); % 生成当前用例的简要报告。
    fprintf('%s\n', summary{c}); % 在命令窗口打印当前用例报告。
end % 结束全部回归测试循环。
assert(all(passed), '至少一个HRG全角数字ASIC回归测试未通过。'); % 要求六组回归测试全部通过。
save('HRG_WA_v3_test_result.mat', 'caseNames', 'passed', 'summary'); % 保存回归测试结果以供版本追溯。
