function [p, s] = HRG_WA_v45_autotune(p, applySuggested) % 根据当前物理量和目标自然频率计算DPLL、能量环与正交环的解析初值。
if nargin < 2 % 判断调用者是否指定自动应用建议值。
    applySuggested = false; % 默认只输出建议而不修改控制器参数。
end % 结束自动应用选项判断。
energyDecayRate = 2 * pi * p.res.f0 / p.res.Q; % 根据慢变量方程计算能量与正交量的一阶自然衰减率。
pllWn = 2 * pi * p.tune.pllNaturalHz; % 把DPLL目标自然频率转换为自然角频率。
energyWn = 2 * pi * p.tune.energyNaturalHz; % 把能量环目标自然频率转换为自然角频率。
quadWn = 2 * pi * p.tune.quadNaturalHz; % 把正交环目标自然频率转换为自然角频率。
s.pllKpHz = 2 * p.tune.pllDampingRatio * pllWn / (2 * pi); % 按二阶近似计算DPLL比例增益初值。
s.pllKiHz = pllWn ^ 2 / (2 * pi); % 按二阶近似计算DPLL积分增益初值。
s.energyKp = max(2 * p.tune.energyDampingRatio * energyWn - energyDecayRate, 0); % 按一阶对象加PI闭环特征方程计算能量环比例增益。
s.energyKi = energyWn ^ 2; % 按目标自然频率计算能量环积分增益。
s.quadKp = max(2 * p.tune.quadDampingRatio * quadWn - energyDecayRate, 0); % 按一阶对象加PI闭环特征方程计算正交环比例增益。
s.quadKi = quadWn ^ 2; % 按目标自然频率计算正交环积分增益。
energyMaxForSizing = max([p.res.energyTarget, p.res.energyInitial, p.protect.energyMax]); % 取得执行器估算使用的最大能量尺度。
energySteadyDrive = energyDecayRate * p.res.energyTarget + abs(p.res.dampingAnisotropy) * p.res.energyTarget; % 估算最不利阻尼下维持目标能量需要的稳态驱动力。
quadWorstDisturbance = 4 * pi * abs(p.res.frequencySplitHz) * energyMaxForSizing; % 估算频率裂解对正交量产生的最不利等效驱动。
s.minimumEnergyLimit = max(1.20 * abs(p.ctrl.startupDrive), p.tune.actuatorMargin * energySteadyDrive); % 给出兼顾起振和稳态阻尼的能量输出最小建议限幅。
s.minimumQuadLimit = p.tune.actuatorMargin * quadWorstDisturbance; % 给出覆盖频率裂解扰动的正交输出最小建议限幅。
deltaTMax = max(abs([p.env.temperatureStartC, p.env.temperatureEndC] - p.env.referenceTemperature)); % 计算温度扫描相对参考点的最大温差。
temperatureExcursionHz = p.res.f0 * (abs(p.env.resonanceTempCoeff1) * deltaTMax + abs(p.env.resonanceTempCoeff2) * deltaTMax ^ 2); % 保守估算温度引起的最大谐振频率偏移。
duffingExcursionHz = abs(p.res.duffingHzPerEnergy) * energyMaxForSizing; % 保守估算Duffing效应引起的最大频率偏移。
physicalFrequencyExcursionHz = temperatureExcursionHz + duffingExcursionHz + abs(p.res.frequencySplitHz); % 合成温度、Duffing与裂解频率偏移包络。
s.minimumPllFrequencyLimitHz = max(10, p.tune.pllRangeMargin * physicalFrequencyExcursionHz); % 给出带工程裕量且不低于十赫兹的DPLL最小频率范围。
delaySec = p.asic.pipelineDelayCtrl * p.sim.TsCtrl; % 计算数字流水线至执行器的总延迟。
s.maximumNaturalHzFromDelay = p.tune.delayPhaseBudgetRad / max(2 * pi * delaySec, eps); % 根据延迟相位预算估算建议的最高环路自然频率。
s.maximumUnambiguousRateDps = p.asic.unwrapLimit / max(4 * abs(p.res.bryan) * p.sim.TsCtrl, eps) * 180 / pi; % 根据四倍角单拍增量门限计算理论最大无歧义输入角速度。
s.adcSamplesPerCarrier = p.sim.fsAdc / p.res.f0; % 计算每个载波周期的ADC采样点数。
s.samplesPerControl = p.sim.samplesPerCtrl; % 记录每个数字控制拍包含的ADC样本数。
s.current = struct('pllKpHz', p.pll.kpHz, 'pllKiHz', p.pll.kiHz, 'energyKp', p.ctrl.energyKp, 'energyKi', p.ctrl.energyKi, 'quadKp', p.ctrl.quadKp, 'quadKi', p.ctrl.quadKi); % 保存应用前控制器增益供对照。
if applySuggested % 判断是否把解析初值写入控制器结构体。
    p.pll.kpHz = s.pllKpHz; % 应用DPLL比例增益建议值。
    p.pll.kiHz = s.pllKiHz; % 应用DPLL积分增益建议值。
    p.ctrl.energyKp = s.energyKp; % 应用能量环比例增益建议值。
    p.ctrl.energyKi = s.energyKi; % 应用能量环积分增益建议值。
    p.ctrl.quadKp = s.quadKp; % 应用正交环比例增益建议值。
    p.ctrl.quadKi = s.quadKi; % 应用正交环积分增益建议值。
    p.ctrl.energyLimit = max(p.ctrl.energyLimit, s.minimumEnergyLimit); % 仅在现有限幅不足时提高能量控制输出范围。
    p.ctrl.quadLimit = max(p.ctrl.quadLimit, s.minimumQuadLimit); % 仅在现有限幅不足时提高正交控制输出范围。
    p.pll.frequencyLimitHz = max(p.pll.frequencyLimitHz, s.minimumPllFrequencyLimitHz); % 仅在现有DPLL范围不足时提高频率限幅。
end % 结束解析建议值应用判断。
end % 结束控制器解析初值计算函数。
