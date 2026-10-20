function u = HRG_WA_v4_user_config() % 定义用户可直接修改的物理量、数字接口、控制器和验证判据表头。
%% A. 仿真时基与输入工况参数表。 % 标记仿真时基与输入工况参数区域。
u.sim.seed = 20260713; % 设置随机种子，比较两组参数时应保持该值相同。
u.sim.duration = 12.0; % 设置仿真总时长，单位为秒。
u.sim.fsAdc = 40000; % 设置检测ADC采样率，单位为赫兹，修改谐振频率后应同步检查每周期采样点数。
u.sim.fsCtrl = 1000; % 设置数字控制器更新率，单位为赫兹，修改后应重新检查环路带宽和展开裕量。
u.input.rateTransitionTimesSec = [2.0 6.0 9.0]; % 设置角速度分段切换时刻，单位为秒。
u.input.rateLevelsDps = [0 45 -30 120]; % 设置各时间区间的输入角速度，单位为度每秒，元素数必须比切换时刻多一。
u.env.referenceTemperature = 25; % 设置温度补偿参考点，单位为摄氏度。
u.env.temperatureStartC = 25; % 设置仿真起始温度，单位为摄氏度。
u.env.temperatureEndC = 45; % 设置仿真结束温度，单位为摄氏度。
u.env.temperatureRampStartSec = 4.0; % 设置线性温度扫描开始时刻，单位为秒。

%% B. HRG谐振子与敏感机理物理参数表。 % 标记谐振子物理参数区域。
u.res.f0 = 5000; % 设置标称谐振频率，单位为赫兹。
u.res.Q = 2.0e6; % 设置机械品质因数，减小时能量与正交环需要更大的稳态驱动力。
u.res.bryan = 0.277; % 设置Bryan系数，该参数必须由真实器件转台标定。
u.res.energyTarget = 1.0; % 设置归一化驻波能量目标值。
u.res.energyInitial = 0.25; % 设置上电初始归一化能量。
u.res.quadInitial = 0.015; % 设置上电初始正交量。
u.res.thetaInitialDeg = 8.0; % 设置上电驻波方位角，单位为度，参数装载时自动转换为弧度。
u.res.dampingAnisotropy = 2.5e-4; % 设置阻尼不均匀慢变量系数，单位为每秒。
u.res.dampingAxisDeg = 17.0; % 设置阻尼主轴方向，单位为度。
u.res.frequencySplitHz = 0.008; % 设置简并模态频率裂解，单位为赫兹，增大后必须提高Q环带宽或驱动裕量。
u.res.stiffnessAxisDeg = 41.0; % 设置刚度主轴方向，单位为度。
u.res.duffingHzPerEnergy = 0.015; % 设置能量相关非线性频移系数，单位为赫兹每归一化能量。
u.res.phaseNoiseRad = 2.0e-6; % 设置每个ADC样本的谐振相位白噪声标准差，单位为弧度。
u.res.processEnergyNoise = 2.0e-5; % 设置能量慢变量过程噪声强度。
u.res.processQuadNoise = 2.0e-5; % 设置正交慢变量过程噪声强度。
u.res.processThetaNoise = 2.0e-6; % 设置驻波角慢变量过程噪声强度。
u.env.resonanceTempCoeff1 = -18e-6; % 设置谐振频率一阶温度系数，单位为每摄氏度。
u.env.resonanceTempCoeff2 = 0.08e-6; % 设置谐振频率二阶温度系数，单位为每摄氏度平方。
u.env.rateBiasAtRefDph = 0.02; % 设置参考温度处等效零偏，单位为度每小时。
u.env.rateBiasTemp1DphPerC = 0.004; % 设置零偏一阶温度系数，单位为度每小时每摄氏度。
u.env.rateBiasTemp2DphPerC2 = 0.0001; % 设置零偏二阶温度系数，单位为度每小时每摄氏度平方。

%% C. AFE、ADC、DAC及数字字长参数表。 % 标记接口电路与定点数据通路参数区域。
u.afe.crossMatrix = [1.0000 0.0030; -0.0020 1.0000]; % 设置两检测通道的增益串扰矩阵。
u.afe.offset = [0.0008; -0.0005]; % 设置两检测通道的等效输入直流偏置。
u.afe.noiseSigma = [2.5e-4; 2.5e-4]; % 设置两检测通道的等效输入白噪声标准差。
u.afe.fullScale = 2.0; % 设置模拟前端双极性满量程。
u.afe.bandwidthHz = 12000; % 设置模拟前端一阶低通带宽，单位为赫兹。
u.afe.enable = true; % 设置是否启用AFE非理想模型。
u.adc.bits = 18; % 设置检测ADC有效位宽。
u.adc.fullScale = 2.0; % 设置检测ADC双极性满量程。
u.adc.enableDither = false; % 设置是否加入半LSB数字抖动。
u.adc.jitterRms = 8e-9; % 设置采样时钟均方根抖动，单位为秒。
u.dac.bits = 16; % 设置能量、正交和虚拟进动执行DAC位宽。
u.dac.fullScaleEnergy = 0.60; % 设置能量驱动通道双极性满量程。
u.dac.fullScaleQuad = 0.50; % 设置正交驱动通道双极性满量程。
u.dac.fullScaleVirtualDps = 40; % 设置虚拟进动通道双极性满量程，单位为度每秒。
u.dac.gain = [1.000; 0.995; 1.002]; % 设置三路执行通道增益误差。
u.dac.offset = [0.0002; -0.0002; 0]; % 设置三路执行通道直流偏置。
u.dac.noiseSigma = [2e-5; 2e-5; 2e-7]; % 设置三路执行通道等效输出噪声。
u.asic.fixedEnable = true; % 设置是否启用数字ASIC定点量化。
u.asic.demodWordLength = 28; % 设置正交解调结果总字长。
u.asic.demodFractionLength = 22; % 设置正交解调结果小数位数。
u.asic.invariantWordLength = 32; % 设置E、Q、R、S、L不变量总字长。
u.asic.invariantFractionLength = 24; % 设置不变量小数位数。
u.asic.controlWordLength = 28; % 设置控制字总字长。
u.asic.controlFractionLength = 22; % 设置控制字小数位数。
u.asic.integratorWordLength = 40; % 设置控制器积分器总字长。
u.asic.integratorFractionLength = 30; % 设置控制器积分器小数位数。
u.asic.angleBits = 24; % 设置CORDIC四倍角输出位数。
u.asic.angleAccumulatorBits = 48; % 设置连续导航角累加器规划位数。
u.asic.pipelineDelayCtrl = 3; % 设置控制字至执行器生效的控制周期延迟。

%% D. DPLL、能量环、正交环与导航滤波器参数表。 % 标记内部控制器参数区域。
u.pll.kpHz = 8.0; % 设置DPLL比例增益，输出单位为赫兹。
u.pll.kiHz = 35.0; % 设置DPLL积分增益，输出单位为赫兹每秒。
u.pll.integratorLimitHz = 800; % 设置DPLL积分项最大频率贡献，单位为赫兹。
u.pll.frequencyLimitHz = 1200; % 设置NCO相对标称频率最大校正范围，单位为赫兹。
u.pll.lockPhaseError = 0.025; % 设置归一化相位误差锁定门限。
u.ctrl.energyKp = 2.4; % 设置能量PI比例增益。
u.ctrl.energyKi = 0.35; % 设置能量PI积分增益。
u.ctrl.quadKp = 7.0; % 设置正交PI比例增益。
u.ctrl.quadKi = 1.4; % 设置正交PI积分增益。
u.ctrl.energyLimit = 0.55; % 设置能量控制输出绝对限幅。
u.ctrl.quadLimit = 0.45; % 设置正交控制输出绝对限幅。
u.ctrl.integratorLimit = 1.5; % 设置能量与正交积分器绝对限幅。
u.ctrl.rateLpfHz = 45; % 设置角速度输出低通截止频率，单位为赫兹；导航角不再积分该低通输出。
u.ctrl.startupTime = 0.25; % 设置STARTUP最短持续时间，单位为秒。
u.ctrl.acquireTime = 0.50; % 设置ACQUIRE最短持续时间，单位为秒。
u.ctrl.startupDrive = 0.35; % 设置STARTUP开环能量驱动量。
u.ctrl.energyLockTolerance = 0.08; % 设置能量锁定相对容差。
u.ctrl.quadLockTolerance = 0.03; % 设置正交量锁定绝对容差。
u.asic.phaseValidThreshold = 0.08; % 设置R/S四倍角矢量有效门限。
u.asic.unwrapLimit = 0.80 * pi; % 设置相邻控制拍四倍角最大允许增量，单位为弧度。
u.virtual.enable = false; % 设置是否启用零均值虚拟进动。
u.virtual.amplitudeDps = 12; % 设置虚拟进动峰值角速度，单位为度每秒。
u.virtual.frequencyHz = 0.35; % 设置虚拟进动频率，单位为赫兹。
u.virtual.phaseRad = 0; % 设置虚拟进动初相位，单位为弧度。
u.comp.trackPhysical = true; % 设置补偿器估计参数是否自动跟随物理模型，关闭后可研究辨识误差。
u.comp.enableHarmonic = true; % 设置是否启用四倍角与八倍角谐波补偿。
u.comp.enableTemperature = true; % 设置是否启用二阶温度零偏补偿。
u.comp.extraHarmonicsDps = [0.0010 -0.0006 0.0003 -0.0002]; % 设置附加四次与八次角位置谐波补偿系数，单位为度每秒。

%% E. 自动调参目标表。 % 标记由物理参数反算控制器初值的目标区域。
u.tune.autoApply = false; % 设置是否自动把建议增益写入控制器，首次修改物理量时建议先保持false并审阅报告。
u.tune.pllNaturalHz = 2.36; % 设置DPLL目标自然频率，单位为赫兹。
u.tune.pllDampingRatio = 1.70; % 设置DPLL目标阻尼比。
u.tune.energyNaturalHz = 0.094; % 设置能量环目标自然频率，单位为赫兹。
u.tune.energyDampingRatio = 2.05; % 设置能量环目标阻尼比。
u.tune.quadNaturalHz = 0.188; % 设置正交环目标自然频率，单位为赫兹。
u.tune.quadDampingRatio = 2.97; % 设置正交环目标阻尼比。
u.tune.actuatorMargin = 1.50; % 设置根据稳态物理扰动估算执行器限幅时采用的裕量倍数。
u.tune.pllRangeMargin = 2.00; % 设置根据温漂与Duffing频移估算DPLL频率范围时采用的裕量倍数。
u.tune.delayPhaseBudgetRad = 0.20; % 设置控制环目标自然角频率乘总延迟的建议上限。

%% F. 保护门限与性能回归判据表。 % 标记保护、统计和测试阈值区域。
u.protect.energyMin = 0.05; % 设置RUN阶段能量过低故障门限。
u.protect.energyMax = 1.80; % 设置RUN阶段能量过高故障门限。
u.protect.quadMax = 0.35; % 设置RUN阶段正交量绝对值故障门限。
u.protect.consecutiveFaults = 5; % 设置连续异常多少控制拍后锁存FAULT。
u.test.ignoreAfterTransition = 0.12; % 设置角速度切换前后排除窗口，单位为秒。
u.test.ignoreAfterLock = 0.05; % 设置进入RUN后额外排除的滤波稳定时间，单位为秒。
u.test.maxLockTime = 2.10; % 设置标称回归允许的最大锁定时间，单位为秒。
u.test.maxAngleRmsDeg = 0.75; % 设置标称回归角度RMS上限，单位为度，此值是回归门限而非产品指标。
u.test.maxRateRmsDps = 5.0; % 设置标称回归角速度RMS上限，单位为度每秒，此值是回归门限而非产品指标。
u.test.maxRateErrorDps = 25.0; % 设置标称回归最大角速度误差上限，单位为度每秒。
u.test.energyMeanTolerance = 0.08; % 设置有效RUN窗口内能量均值相对目标的允许偏差。
u.test.quadRmsMax = 0.03; % 设置有效RUN窗口内Q均方根上限。
u.test.phaseErrorRmsMax = 0.025; % 设置有效RUN窗口内相位误差均方根上限。
u.test.requireNoAdcSaturation = true; % 设置性能回归是否要求ADC与AFE零饱和。
u.test.requireNoDacSaturation = true; % 设置性能回归是否要求DAC与驱动零饱和。
u.test.requireNoFixedOverflow = true; % 设置性能回归是否要求真实定点溢出次数为零。
end % 结束用户参数表头函数。
