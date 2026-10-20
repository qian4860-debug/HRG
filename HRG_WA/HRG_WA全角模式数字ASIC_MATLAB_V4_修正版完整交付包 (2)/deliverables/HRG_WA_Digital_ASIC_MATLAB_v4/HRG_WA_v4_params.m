function p = HRG_WA_v4_params(userOverride) % 定义半球谐振陀螺全角模式及数字ASIC行为级模型的全部参数并装载用户表头。
if nargin < 1 || isempty(userOverride) % 判断调用者是否提供了独立参数覆盖结构体。
    userOverride = HRG_WA_v4_user_config(); % 默认读取集中式用户物理量与控制器参数表头。
end % 结束用户参数来源判断。
p.meta.name = 'HRG whole-angle digital ASIC behavioral model V4.0'; % 记录模型名称，便于结果文件追溯。
p.meta.basis = 'public literature and patents, non-proprietary behavioral abstraction'; % 声明模型只采用公开原理而非专有实现。
p.sim.seed = 20260713; % 固定随机数种子，保证噪声仿真能够重复。
p.sim.duration = 12.0; % 设置标称仿真总时长，单位为秒。
p.sim.fsAdc = 40000; % 设置两路检测ADC采样率，单位为赫兹。
p.sim.fsCtrl = 1000; % 设置数字控制环更新率，单位为赫兹。
p.sim.TsCtrl = 1 / p.sim.fsCtrl; % 由控制频率计算控制周期，单位为秒。
p.sim.samplesPerCtrl = round(p.sim.fsAdc / p.sim.fsCtrl); % 计算每次控制更新包含的ADC样本数。
p.sim.requireIntegerRate = true; % 要求ADC采样率与控制率之比为整数，便于硬件抽取实现。
p.sim.makePlots = true; % 指定演示脚本默认生成闭环结果图。
p.res.f0 = 5000; % 设置谐振子标称二阶模态频率，单位为赫兹。
p.res.Q = 2.0e6; % 设置谐振子机械品质因数。
p.res.bryan = 0.277; % 设置Bryan进动系数，实际工程中必须通过转台标定。
p.res.energyTarget = 1.0; % 设置归一化主驻波能量目标值。
p.res.energyInitial = 0.25; % 设置上电时归一化主驻波能量初值。
p.res.quadInitial = 0.015; % 设置上电时正交量初值。
p.res.thetaInitial = 8 * pi / 180; % 设置上电时驻波波腹方位角初值，单位为弧度。
p.res.meanDamping = pi * p.res.f0 / p.res.Q; % 由频率和品质因数得到慢变量平均阻尼率。
p.res.dampingAnisotropy = 2.5e-4; % 设置阻尼不均匀系数，单位为每秒。
p.res.dampingAxis = 17 * pi / 180; % 设置阻尼主轴方位角，单位为弧度。
p.res.frequencySplitHz = 0.008; % 设置两简并模态的频率裂解，单位为赫兹。
p.res.stiffnessAxis = 41 * pi / 180; % 设置刚度主轴方位角，单位为弧度。
p.res.duffingHzPerEnergy = 0.015; % 设置能量变化引起的等效谐振频移系数。
p.res.phaseNoiseRad = 2.0e-6; % 设置每个ADC采样点的谐振相位白噪声标准差。
p.res.processEnergyNoise = 2.0e-5; % 设置能量慢变量过程噪声强度。
p.res.processQuadNoise = 2.0e-5; % 设置正交慢变量过程噪声强度。
p.res.processThetaNoise = 2.0e-6; % 设置驻波角慢变量过程噪声强度。
p.input.rateFcn = @(t) ((t >= 2.0 & t < 6.0) * 45 + (t >= 6.0 & t < 9.0) * (-30) + (t >= 9.0) * 120) * pi / 180; % 定义标称分段角速度输入，单位为弧度每秒。
p.env.referenceTemperature = 25; % 设置标定参考温度，单位为摄氏度。
p.env.temperatureFcn = @(t) 25 + 20 * max(t - 4, 0) / max(p.sim.duration - 4, 1); % 定义仿真中的线性升温曲线。
p.env.resonanceTempCoeff1 = -18e-6; % 设置谐振频率一阶温度系数，单位为每摄氏度。
p.env.resonanceTempCoeff2 = 0.08e-6; % 设置谐振频率二阶温度系数，单位为每摄氏度平方。
p.env.rateBiasAtRef = 0.02 * pi / 180 / 3600; % 设置参考温度处等效零偏，单位为弧度每秒。
p.env.rateBiasTemp1 = 0.004 * pi / 180 / 3600; % 设置零偏一阶温度系数，单位为弧度每秒每摄氏度。
p.env.rateBiasTemp2 = 0.0001 * pi / 180 / 3600; % 设置零偏二阶温度系数，单位为弧度每秒每摄氏度平方。
p.afe.crossMatrix = [1.0000 0.0030; -0.0020 1.0000]; % 设置两检测通道的增益与串扰矩阵。
p.afe.offset = [0.0008; -0.0005]; % 设置两检测通道的等效输入直流偏置。
p.afe.noiseSigma = [2.5e-4; 2.5e-4]; % 设置两检测通道的等效输入白噪声标准差。
p.afe.fullScale = 2.0; % 设置模拟前端双极性满量程幅值。
p.afe.bandwidthHz = 12000; % 设置模拟前端一阶低通带宽，单位为赫兹。
p.afe.enable = true; % 使能模拟前端的非理想行为。
p.adc.bits = 18; % 设置检测ADC位宽。
p.adc.fullScale = 2.0; % 设置检测ADC双极性满量程幅值。
p.adc.enableDither = false; % 默认关闭ADC半LSB抖动。
p.adc.jitterRms = 8e-9; % 设置ADC采样时钟均方根抖动，单位为秒。
p.asic.fixedEnable = true; % 使能数字ASIC内部的等效定点量化。
p.asic.demodWordLength = 28; % 设置正交解调累加结果的总字长。
p.asic.demodFractionLength = 22; % 设置正交解调累加结果的小数位数。
p.asic.invariantWordLength = 32; % 设置E/Q/R/S/L不变量的总字长。
p.asic.invariantFractionLength = 24; % 设置E/Q/R/S/L不变量的小数位数。
p.asic.controlWordLength = 28; % 设置PI控制输出的总字长。
p.asic.controlFractionLength = 22; % 设置PI控制输出的小数位数。
p.asic.integratorWordLength = 40; % 设置PI积分器的总字长。
p.asic.integratorFractionLength = 30; % 设置PI积分器的小数位数。
p.asic.angleBits = 24; % 设置CORDIC等效相位输出位数。
p.asic.angleAccumulatorBits = 48; % 设置连续角度累加器位数，用于接口规划。
p.asic.pipelineDelayCtrl = 3; % 设置控制字至执行器生效的控制周期延迟。
p.asic.outputDecimation = 1; % 设置导航输出数据就绪的控制周期抽取比。
p.asic.phaseValidThreshold = 0.08; % 设置R/S矢量幅值有效门限。
p.asic.unwrapLimit = 0.80 * pi; % 设置相邻四倍角允许的最大相位增量。
p.pll.kpHz = 8.0; % 设置数字锁相环比例增益，输出单位为赫兹。
p.pll.kiHz = 35.0; % 设置数字锁相环积分增益，输出单位为赫兹每秒。
p.pll.integratorLimitHz = 800; % 设置数字锁相环积分项限幅，单位为赫兹。
p.pll.frequencyLimitHz = 1200; % 设置NCO相对标称频率的最大校正范围。
p.pll.lockPhaseError = 0.025; % 设置频率相位环归一化误差锁定门限。
p.ctrl.energyKp = 2.4; % 设置能量PI环比例增益。
p.ctrl.energyKi = 0.35; % 设置能量PI环积分增益。
p.ctrl.quadKp = 7.0; % 设置正交PI环比例增益。
p.ctrl.quadKi = 1.4; % 设置正交PI环积分增益。
p.ctrl.energyLimit = 0.55; % 设置能量控制量的双极性限幅。
p.ctrl.quadLimit = 0.45; % 设置正交控制量的双极性限幅。
p.ctrl.integratorLimit = 1.5; % 设置能量与正交PI积分器的绝对限幅。
p.ctrl.rateLpfHz = 45; % 设置角速度输出一阶低通截止频率，单位为赫兹。
p.ctrl.startupTime = 0.25; % 设置开环起振阶段的最短持续时间，单位为秒。
p.ctrl.acquireTime = 0.50; % 设置闭环捕获阶段的最短持续时间，单位为秒。
p.ctrl.startupDrive = 0.35; % 设置起振阶段的开环能量驱动量。
p.ctrl.energyLockTolerance = 0.08; % 设置能量锁定的相对容差。
p.ctrl.quadLockTolerance = 0.03; % 设置正交量锁定的绝对容差。
p.virtual.enable = false; % 默认关闭零均值虚拟进动调制。
p.virtual.amplitudeDps = 12; % 设置虚拟进动的峰值角速度，单位为度每秒。
p.virtual.frequencyHz = 0.35; % 设置虚拟进动调制频率，单位为赫兹。
p.virtual.phaseRad = 0; % 设置虚拟进动调制初相位，单位为弧度。
p.comp.enableHarmonic = true; % 使能角位置相关漂移的谐波前馈补偿。
p.comp.dampingAnisotropyHat = p.res.dampingAnisotropy; % 设置阻尼不均匀补偿参数估计值。
p.comp.dampingAxisHat = p.res.dampingAxis; % 设置阻尼主轴补偿参数估计值。
p.comp.frequencySplitHatHz = p.res.frequencySplitHz; % 设置频率裂解补偿参数估计值。
p.comp.stiffnessAxisHat = p.res.stiffnessAxis; % 设置刚度主轴补偿参数估计值。
p.comp.extraHarmonicsDps = [0.0010 -0.0006 0.0003 -0.0002]; % 设置额外四次与八次谐波零偏补偿系数，单位为度每秒。
p.comp.enableTemperature = true; % 使能输出零偏的二阶温度补偿。
p.comp.trackPhysical = true; % 默认使补偿参数估计值跟随当前物理模型参数。
p.dac.bits = 16; % 设置能量、正交和虚拟进动执行通道的等效DAC位宽。
p.dac.fullScale = [0.60; 0.50; 40 * pi / 180]; % 设置三路执行通道的双极性满量程。
p.dac.gain = [1.000; 0.995; 1.002]; % 设置三路执行通道的增益误差。
p.dac.offset = [0.0002; -0.0002; 0]; % 设置三路执行通道的直流偏置。
p.dac.noiseSigma = [2e-5; 2e-5; 2e-7]; % 设置三路执行通道的等效输出白噪声。
p.fault.enable = false; % 默认关闭故障注入。
p.fault.time = 7.0; % 设置故障注入时刻，单位为秒。
p.fault.type = 'none'; % 设置故障类型，可选none、adc_stuck、afe_offset、loop_disable或dac_clip。
p.fault.magnitude = 0.25; % 设置故障注入幅值。
p.fsm.initialMode = uint8(1); % 设置初始状态为STARTUP。
p.fsm.names = {'IDLE','STARTUP','ACQUIRE','RUN','SELFTEST','FAULT'}; % 定义状态机编号对应的可读名称。
p.protect.energyMin = 0.05; % 设置运行阶段能量过低故障门限。
p.protect.energyMax = 1.80; % 设置运行阶段能量过高故障门限。
p.protect.quadMax = 0.35; % 设置运行阶段正交量绝对值故障门限。
p.protect.consecutiveFaults = 5; % 设置故障连续出现多少拍后进入FAULT状态。
p.test.ignoreAfterTransition = 0.12; % 设置指标统计中速率切换点附近的排除窗口，单位为秒。
p.test.rateTransitionTimes = [2 6 9]; % 设置标称输入角速度的切换时刻。
p.test.ignoreAfterLock = 0.05; % 设置进入RUN后排除的滤波稳定窗口，单位为秒。
p.test.maxLockTime = 2.10; % 设置标称性能回归允许的最大锁定时间，单位为秒。
p.test.maxAngleRmsDeg = 0.75; % 设置标称性能回归角度均方根误差上限，单位为度。
p.test.maxRateRmsDps = 5.0; % 设置标称性能回归角速度均方根误差上限，单位为度每秒。
p.test.maxRateErrorDps = 25.0; % 设置标称性能回归最大角速度误差上限，单位为度每秒。
p.test.energyMeanTolerance = 0.08; % 设置能量均值相对目标的允许偏差。
p.test.quadRmsMax = 0.03; % 设置正交量均方根上限。
p.test.phaseErrorRmsMax = 0.025; % 设置归一化相位误差均方根上限。
p.test.requireNoAdcSaturation = true; % 设置回归是否要求ADC零饱和。
p.test.requireNoDacSaturation = true; % 设置回归是否要求DAC零饱和。
p.test.requireNoFixedOverflow = true; % 设置回归是否要求真实定点溢出为零。
p.tune.autoApply = false; % 默认只生成控制器建议而不自动改写参数。
p.tune.pllNaturalHz = 2.36; % 设置DPLL目标自然频率，单位为赫兹。
p.tune.pllDampingRatio = 1.70; % 设置DPLL目标阻尼比。
p.tune.energyNaturalHz = 0.094; % 设置能量环目标自然频率，单位为赫兹。
p.tune.energyDampingRatio = 2.05; % 设置能量环目标阻尼比。
p.tune.quadNaturalHz = 0.188; % 设置正交环目标自然频率，单位为赫兹。
p.tune.quadDampingRatio = 2.97; % 设置正交环目标阻尼比。
p.tune.actuatorMargin = 1.50; % 设置执行器限幅建议的物理裕量倍数。
p.tune.pllRangeMargin = 2.00; % 设置DPLL频率范围建议的物理裕量倍数。
p.tune.delayPhaseBudgetRad = 0.20; % 设置环路自然角频率乘数字延迟的建议上限。
p = local_merge_struct(p, userOverride); % 把用户表头字段递归覆盖到内建默认参数。
p.sim.TsCtrl = 1 / p.sim.fsCtrl; % 根据用户控制率重新计算控制周期。
p.sim.samplesPerCtrl = round(p.sim.fsAdc / p.sim.fsCtrl); % 根据用户采样率重新计算每控制拍ADC样本数。
p.res.meanDamping = pi * p.res.f0 / p.res.Q; % 根据用户谐振频率和品质因数重新计算平均阻尼率。
if isfield(p.res, 'thetaInitialDeg') % 判断用户是否使用了便于阅读的角度制初始方位参数。
    p.res.thetaInitial = p.res.thetaInitialDeg * pi / 180; % 把初始驻波方位从度转换为弧度。
end % 结束初始方位单位转换。
if isfield(p.res, 'dampingAxisDeg') % 判断用户是否使用了角度制阻尼主轴参数。
    p.res.dampingAxis = p.res.dampingAxisDeg * pi / 180; % 把阻尼主轴从度转换为弧度。
end % 结束阻尼主轴单位转换。
if isfield(p.res, 'stiffnessAxisDeg') % 判断用户是否使用了角度制刚度主轴参数。
    p.res.stiffnessAxis = p.res.stiffnessAxisDeg * pi / 180; % 把刚度主轴从度转换为弧度。
end % 结束刚度主轴单位转换。
if isfield(p.env, 'rateBiasAtRefDph') % 判断用户是否使用度每小时表示参考温度零偏。
    p.env.rateBiasAtRef = p.env.rateBiasAtRefDph * pi / 180 / 3600; % 把参考温度零偏转换为弧度每秒。
end % 结束参考温度零偏单位转换。
if isfield(p.env, 'rateBiasTemp1DphPerC') % 判断用户是否使用度每小时每摄氏度表示一阶温度零偏。
    p.env.rateBiasTemp1 = p.env.rateBiasTemp1DphPerC * pi / 180 / 3600; % 把一阶温度零偏转换为弧度每秒每摄氏度。
end % 结束一阶温度零偏单位转换。
if isfield(p.env, 'rateBiasTemp2DphPerC2') % 判断用户是否使用度每小时每摄氏度平方表示二阶温度零偏。
    p.env.rateBiasTemp2 = p.env.rateBiasTemp2DphPerC2 * pi / 180 / 3600; % 把二阶温度零偏转换为弧度每秒每摄氏度平方。
end % 结束二阶温度零偏单位转换。
if isfield(p.dac, 'fullScaleEnergy') && isfield(p.dac, 'fullScaleQuad') && isfield(p.dac, 'fullScaleVirtualDps') % 判断用户是否提供三路便捷满量程字段。
    p.dac.fullScale = [p.dac.fullScaleEnergy; p.dac.fullScaleQuad; p.dac.fullScaleVirtualDps * pi / 180]; % 组成内部统一使用的三路DAC满量程向量。
end % 结束DAC满量程映射。
if isfield(p.input, 'rateTransitionTimesSec') && isfield(p.input, 'rateLevelsDps') % 判断用户是否提供分段角速度表。
    p.input.rateFcn = @(t) local_piecewise_rate(t, p.input.rateTransitionTimesSec, p.input.rateLevelsDps); % 由用户分段表构造角速度输入函数。
    p.test.rateTransitionTimes = p.input.rateTransitionTimesSec; % 把输入切换时刻同步给指标排除窗口。
end % 结束分段角速度函数构造。
if isfield(p.env, 'temperatureStartC') && isfield(p.env, 'temperatureEndC') && isfield(p.env, 'temperatureRampStartSec') % 判断用户是否提供温度扫描表。
    p.env.temperatureFcn = @(t) local_temperature_profile(t, p.env.temperatureStartC, p.env.temperatureEndC, p.env.temperatureRampStartSec, p.sim.duration); % 由用户温度表构造线性温度输入函数。
end % 结束温度函数构造。
if isfield(p.comp, 'trackPhysical') && p.comp.trackPhysical % 判断补偿器估计参数是否自动跟随物理模型。
    p.comp.dampingAnisotropyHat = p.res.dampingAnisotropy; % 把阻尼不均匀估计值同步为当前物理值。
    p.comp.dampingAxisHat = p.res.dampingAxis; % 把阻尼主轴估计值同步为当前物理值。
    p.comp.frequencySplitHatHz = p.res.frequencySplitHz; % 把频率裂解估计值同步为当前物理值。
    p.comp.stiffnessAxisHat = p.res.stiffnessAxis; % 把刚度主轴估计值同步为当前物理值。
end % 结束补偿器参数自动同步。
if isfield(p.tune, 'autoApply') && p.tune.autoApply % 判断是否自动应用控制器解析初值。
    [p, ~] = HRG_WA_v4_autotune(p, true); % 根据当前物理量和目标带宽自动更新控制器参数。
end % 结束自动调参应用判断。
HRG_WA_v4_validate_params(p, true); % 对用户表头、动态范围、环路带宽和展开裕量执行参数一致性检查。
end % 结束参数定义函数。

function out = local_merge_struct(base, override) % 递归合并用户覆盖结构体并保留未覆盖的默认字段。
out = base; % 复制默认参数作为递归合并起点。
names = fieldnames(override); % 取得当前层用户覆盖字段名称。
for i = 1:numel(names) % 逐个处理当前层用户字段。
    name = names{i}; % 读取当前用户字段名称。
    if isfield(out, name) && isstruct(out.(name)) && isstruct(override.(name)) % 判断当前字段是否可以继续递归合并。
        out.(name) = local_merge_struct(out.(name), override.(name)); % 递归合并嵌套结构体。
    else % 处理标量、向量、矩阵、函数句柄或新增字段。
        out.(name) = override.(name); % 用用户值覆盖默认值或添加新字段。
    end % 结束当前字段类型判断。
end % 结束当前层字段循环。
end % 结束递归结构体合并函数。

function rate = local_piecewise_rate(t, transitions, levelsDps) % 根据切换时刻与区间值生成分段角速度。
rateDps = levelsDps(1) + zeros(size(t)); % 用第一个区间值初始化与输入时间同尺寸的角速度数组。
for i = 1:numel(transitions) % 逐个应用后续区间的角速度值。
    rateDps(t >= transitions(i)) = levelsDps(i + 1); % 在当前切换时刻之后写入新的角速度值。
end % 结束角速度区间循环。
rate = rateDps * pi / 180; % 把角速度从度每秒转换为弧度每秒。
end % 结束分段角速度函数。

function temperature = local_temperature_profile(t, startC, endC, rampStartSec, durationSec) % 根据起止温度和扫描时刻生成线性温度曲线。
fraction = min(max((t - rampStartSec) / max(durationSec - rampStartSec, eps), 0), 1); % 计算并限幅温度扫描的归一化进度。
temperature = startC + (endC - startC) .* fraction; % 根据归一化进度生成当前温度。
end % 结束温度曲线函数。
