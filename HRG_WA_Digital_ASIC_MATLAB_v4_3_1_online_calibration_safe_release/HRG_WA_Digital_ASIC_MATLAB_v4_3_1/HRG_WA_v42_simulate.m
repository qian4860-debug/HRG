function result = HRG_WA_v42_simulate(p) % 运行半球谐振陀螺全角模式与数字ASIC的多速率闭环行为仿真。
if nargin < 1 || isempty(p) % 判断调用者是否提供参数结构体。
    p = HRG_WA_v42_params(); % 未提供参数时加载标称参数。
end % 结束默认参数判断。
rng(p.sim.seed, 'twister'); % 固定随机数发生器，保证仿真可复现。
ratioExact = p.sim.fsAdc / p.sim.fsCtrl; % 计算ADC采样率与控制更新率的精确比值。
if p.sim.requireIntegerRate % 判断是否强制采用整数抽取比。
    assert(abs(ratioExact - round(ratioExact)) < 1e-12, 'ADC采样率必须是控制率的整数倍。'); % 检查多速率时序能否直接映射到硬件计数器。
end % 结束整数抽取比检查。
samplesPerCtrl = round(ratioExact); % 取每个控制周期内的ADC样本数。
TsCtrl = 1 / p.sim.fsCtrl; % 计算控制周期，单位为秒。
TsAdc = 1 / p.sim.fsAdc; % 计算ADC采样周期，单位为秒。
count = floor(p.sim.duration * p.sim.fsCtrl) + 1; % 计算控制域总采样点数。
t = (0:count - 1)' * TsCtrl; % 生成控制域时间向量。
x.energy = p.res.energyInitial; % 初始化谐振子能量慢变量。
x.quad = p.res.quadInitial; % 初始化谐振子正交慢变量。
x.theta = p.res.thetaInitial; % 初始化驻波物理方位角。
x.thetaVirtual = 0; % 初始化累计虚拟进动角。
x.resPhase = 0; % 初始化谐振载波相位。
st.mode = p.fsm.initialMode; % 初始化数字控制状态机。
st.modeTime = 0; % 初始化当前状态驻留时间。
st.locked = false; % 初始化闭环锁定标志。
st.ncoPhase = 0; % 初始化NCO相位累加器。
st.ncoFrequencyHz = p.res.f0; % 初始化NCO输出频率。
st.pllIntegratorHz = 0; % 初始化数字锁相环积分器。
st.energyIntegrator = 0; % 初始化能量PI积分器。
st.quadIntegrator = 0; % 初始化正交PI积分器。
st.previousEnergyCommand = 0; % 初始化能量控制字斜率限制器的上一拍输出。
st.previousQuadCommand = 0; % 初始化正交控制字斜率限制器的上一拍输出。
st.previousDeliveredCommand = zeros(3, 1); % 初始化上一拍真正到达DAC输入端的流水线对齐控制字。
st.previousActuatorOutput = zeros(3, 1); % 初始化上一拍DAC与驱动级实际物理输出。
st.previousActuatorSaturated = false; % 初始化上一拍DAC与驱动级物理饱和标志。
st.thetaEstimate = p.res.thetaInitial; % 初始化连续驻波角估计。
st.thetaPrevious = p.res.thetaInitial; % 初始化上一拍驻波角估计。
st.phiPrevious = local_wrap_pi(4 * p.res.thetaInitial); % 初始化四倍角上一拍相位。
st.phaseWasValid = true; % 初始化上一拍相位有效标志以允许启动阶段连续展开。
st.kalmanState = [p.res.thetaInitial; 0]; % 初始化Kalman驻波角与驻波角速度二状态向量。
st.kalmanCovariance = diag([(p.kalman.initialAngleStdDeg * pi / 180) ^ 2, (p.kalman.initialRateStdDps * pi / 180) ^ 2]); % 初始化Kalman状态协方差矩阵。
st.kalmanInnovation = 0; % 初始化Kalman测量创新诊断量。
st.kalmanUpdateCount = 0; % 初始化Kalman有效测量更新计数器。
st.kalmanRejectCount = 0; % 初始化Kalman创新超限拒绝计数器。
st.angleOutput = 0; % 初始化导航角度输出。
st.rateOutput = 0; % 初始化导航角速度输出。
st.afeState = [0; 0]; % 初始化两路模拟前端低通状态。
st.controlDelay = zeros(3, p.asic.pipelineDelayCtrl + 1); % 初始化三路控制命令流水线。
st.adcSaturationCount = 0; % 初始化ADC饱和计数器。
st.dacSaturationCount = 0; % 初始化DAC饱和计数器。
st.fixedOverflowCount = 0; % 初始化真实定点数据通路溢出计数器。
st.pllLimitCount = 0; % 初始化DPLL积分器或频率输出限幅计数器。
st.pllFreezeCount = 0; % 初始化DPLL因测量无效而冻结的控制拍计数器。
st.antiWindupCount = 0; % 初始化DPLL、能量环与正交环抗饱和动作计数器。
st.piIntegratorLimitCount = 0; % 初始化能量与正交PI积分器限幅计数器。
st.controlOutputLimitCount = 0; % 初始化能量与正交控制输出限幅计数器。
st.controlSlewLimitCount = 0; % 初始化能量与正交控制字斜率限制动作计数器。
st.actuatorTrackingCount = 0; % 初始化执行器实际输出与斜率限制跟踪反算动作计数器。
st.unwrapFaultCount = 0; % 初始化四倍角展开异常计数器。
st.consecutiveFaultCount = 0; % 初始化连续故障拍数计数器。
st.faultLatched = false; % 初始化故障锁存标志。
st.selftestDone = false; % 初始化SELFTEST完成标志。
st.selftestPassed = false; % 初始化SELFTEST通过标志。
st.selftestFailed = false; % 初始化SELFTEST失败标志。
st.selftestSampleCount = 0; % 初始化SELFTEST同步相关样本计数器。
st.selftestInPhaseSum = 0; % 初始化SELFTEST同相同步相关累加器。
st.selftestQuadratureSum = 0; % 初始化SELFTEST正交同步相关累加器。
st.selftestGainEstimate = 0; % 初始化SELFTEST检测链路增益估计值。
st.selftestQuadratureRatio = 0; % 初始化SELFTEST正交残差比例估计值。
st.previousMode = st.mode; % 初始化状态机上一拍模式以支持无扰切换诊断。
st.calibDetectionMatrixHat = eye(2); % 初始化V4.3在线检测矩阵估计值为单位矩阵。
st.calibDriveMatrixHat = eye(2); % 初始化V4.3在线驱动矩阵估计值为单位矩阵。
st.calibDetectionTheta = [1; 0; 0; 1]; % 初始化检测矩阵RLS参数向量[m11 m12 m21 m22]。
st.calibDriveTheta = [1; 0; 0; 1]; % 初始化驱动矩阵RLS参数向量[d11 d12 d21 d22]。
st.calibDetectionP = p.calib.rlsDelta * eye(4); % 初始化检测矩阵RLS协方差阵。
st.calibDriveP = p.calib.rlsDelta * eye(4); % 初始化驱动矩阵RLS协方差阵。
st.calibEkfState = [p.comp.dampingAnisotropyHat * cos(4 * p.comp.dampingAxisHat); p.comp.dampingAnisotropyHat * sin(4 * p.comp.dampingAxisHat); p.comp.frequencySplitHatHz * cos(4 * p.comp.stiffnessAxisHat); p.comp.frequencySplitHatHz * sin(4 * p.comp.stiffnessAxisHat)]; % 初始化阻尼与模态裂解EKF式线性谐波状态。
st.calibEkfCovariance = p.calib.rlsDelta * eye(4); % 初始化物理参数在线辨识协方差阵。
st.calibDampingAnisotropyHat = p.comp.dampingAnisotropyHat; % 初始化在线阻尼不均匀幅值估计。
st.calibDampingAxisHat = p.comp.dampingAxisHat; % 初始化在线阻尼主轴估计。
st.calibFrequencySplitHatHz = p.comp.frequencySplitHatHz; % 初始化在线频率裂解估计。
st.calibStiffnessAxisHat = p.comp.stiffnessAxisHat; % 初始化在线刚度主轴估计。
st.calibSafetyFactor = p.calib.safetyMax; % 初始化在线执行器安全系数显示值。
st.calibModeMatchFactor = 1.0; % 初始化模态匹配因子，越接近一表示裂解越低。
st.calibCompensationAlpha = 0; % 初始化在线补偿释放权重，V4.3.1采用先辨识、后小步补偿的安全释放策略。
st.calibUpdateCount = 0; % 初始化在线标定参数更新次数。
st.calibSynchronousCount = 0; % 初始化正弦自激同步解调累计拍数。
st.calibSyncEnergyI = 0; % 初始化能量通道同步同相累计量。
st.calibSyncEnergyQ = 0; % 初始化能量通道同步正交累计量。
st.calibSyncQuadI = 0; % 初始化正交通道同步同相累计量。
st.calibSyncQuadQ = 0; % 初始化正交通道同步正交累计量。
st.calibSyncEnergyGain = 0; % 初始化能量通道正弦响应幅值估计。
st.calibSyncQuadGain = 0; % 初始化正交通道正弦响应幅值估计。
st.calibPrevE = p.res.energyInitial; % 初始化上一拍E不变量用于慢变量差分辨识。
st.calibPrevQ = p.res.quadInitial; % 初始化上一拍Q不变量用于慢变量差分辨识。
st.calibPrevTheta = p.res.thetaInitial; % 初始化上一拍驻波角用于物理参数辨识。
st.calibPrevAct = zeros(2, 1); % 初始化上一拍能量/正交执行量用于驱动矩阵辨识。
log = local_allocate_log(count, t); % 预分配全部仿真日志，避免循环中动态扩容。
for k = 1:count % 逐个执行控制周期的闭环仿真。
    tk = t(k); % 读取当前控制周期的时间。
    temperature = p.env.temperatureFcn(tk); % 计算当前环境温度。
    inputRate = p.input.rateFcn(tk); % 计算当前外部角速度输入。
    [demod, st, x, adcDiag] = local_frontend_block(tk, x, st, p, samplesPerCtrl, TsAdc, temperature); % 生成原始载波并完成AFE、ADC、NCO和正交解调。
    rawDemod = demod; % 保存未经过在线检测矩阵反校正的原始解调量，供RLS辨识AFE检测矩阵使用。
    [demod, st] = local_apply_detection_calibration(demod, st, p); % 根据V4.3在线检测矩阵估计值反校正两路解调量。
    [inv, fixedSat] = local_invariants(demod, p); % 由四路正交分量计算E、Q、R、S和相位误差信号L。
    st.fixedOverflowCount = st.fixedOverflowCount + double(fixedSat); % 累加不变量数据通路真实定点溢出次数。
    measurementFlags.frontendSaturated = adcDiag.saturated; % 把本拍AFE或ADC饱和状态送入测量有效性判定。
    measurementFlags.fixedOverflow = fixedSat || adcDiag.fixedOverflow; % 把本拍解调或不变量定点溢出状态送入测量有效性判定。
    measurementFlags.selftestInjected = adcDiag.selftestInjected; % 把本拍前端是否真实注入SELFTEST载波送入控制与日志域。
    measurementFlags.rawDemod = rawDemod; % 把未反校正的原始同步解调量送入在线检测矩阵RLS辨识器。
    [cmd, nav, st] = local_asic_control(tk, inv, demod, measurementFlags, st, p, temperature); % 执行DPLL、能量环、正交环、Kalman角速度解算、SELFTEST和状态机。
    [act, st, dacDiag] = local_dac_driver(cmd, st, p); % 执行控制字流水线、DAC量化和驱动非理想模型。
    st.adcSaturationCount = st.adcSaturationCount + double(adcDiag.saturated); % 累加ADC或AFE饱和次数。
    st.dacSaturationCount = st.dacSaturationCount + double(dacDiag.saturated); % 累加DAC或驱动饱和次数。
    log = local_log_sample(log, k, x, inv, demod, nav, cmd, act, st, temperature, inputRate); % 将当前拍的关键中间量写入预分配日志。
    if k < count % 判断当前拍之后是否还需要更新机械慢变量。
        x = local_plant_step(tk, x, act, inputRate, temperature, p, TsCtrl); % 以执行器实际输出推进谐振子慢变量。
    end % 结束机械状态更新判断。
end % 结束控制周期主循环。
log.inputAngle = cumtrapz(log.t, log.inputRate); % 对输入角速度积分得到参考输入角度。
metrics = HRG_WA_v42_metrics(log, p); % 计算闭环性能、饱和和故障指标。
result.log = log; % 把完整日志写入结果结构体。
result.metrics = metrics; % 把性能指标写入结果结构体。
result.params = p; % 把本次实际参数写入结果结构体以便复现。
result.regmap = HRG_WA_v42_regmap(p); % 把建议寄存器表写入结果结构体。
if p.analysis.autoRun % 判断是否要求在本次闭环仿真后立即执行噪声可信度分析。
    result.noiseAnalysis = HRG_WA_v42_noise_analysis(log, p); % 对最长连续有效数据段计算Allan偏差与Welch功率谱。
end % 结束自动噪声分析判断。
end % 结束多速率闭环仿真主函数。

function log = local_allocate_log(count, t) % 预分配控制域日志结构体。
log.t = t; % 保存控制域时间向量。
names = {'energy','quad','thetaTrue','thetaEstimate','Cx','Sx','Cy','Sy','E','Q','R','S','L','phaseError','ncoFrequencyHz','pllIntegrator','energyIntegrator','quadIntegrator','angleOutput','rateOutput','rawRate','compensatedRate','inputRate','inputAngle','energyCmd','quadCmd','virtualCmd','energyAct','quadAct','virtualAct','temperature','mode','statusWord','measurementInvalidReason','adcSatCount','dacSatCount','fixedOverflowCount','pllLimitCount','pllFreezeCount','antiWindupCount','piIntegratorLimitCount','controlOutputLimitCount','controlSlewLimitCount','actuatorTrackingCount','unwrapFaultCount','kalmanAngle','kalmanThetaRate','kalmanInnovation','kalmanP11','kalmanP22','kalmanUpdateCount','kalmanRejectCount','calibUpdateCount','calibDet11','calibDet12','calibDet21','calibDet22','calibDrv11','calibDrv12','calibDrv21','calibDrv22','calibDampingAnisotropy','calibDampingAxis','calibFrequencySplitHz','calibStiffnessAxis','calibSafetyFactor','calibModeMatchFactor','calibCompensationAlpha','calibSyncEnergyGain','calibSyncQuadGain','selftestGainEstimate','selftestQuadratureRatio','selftestSampleCount'}; % 定义需要预分配的数值字段名称。
for i = 1:numel(names) % 遍历全部数值日志字段。
    log.(names{i}) = zeros(count, 1); % 为当前字段分配列向量。
end % 结束日志字段预分配循环。
log.locked = false(count, 1); % 单独预分配逻辑型锁定标志。
log.phaseValid = false(count, 1); % 单独预分配DPLL与四倍角方位测量有效标志。
log.pllFrozen = false(count, 1); % 单独预分配DPLL本拍冻结标志。
log.antiWindupActive = false(count, 1); % 单独预分配任一控制环本拍抗饱和动作标志。
log.kalmanUpdated = false(count, 1); % 单独预分配Kalman本拍测量更新标志。
log.calibActive = false(count, 1); % 单独预分配V4.3在线标定活动标志。
log.selftestActive = false(count, 1); % 单独预分配SELFTEST活动标志。
log.selftestDone = false(count, 1); % 单独预分配SELFTEST完成锁存标志。
log.selftestPassed = false(count, 1); % 单独预分配SELFTEST通过锁存标志。
log.selftestFailed = false(count, 1); % 单独预分配SELFTEST失败锁存标志。
end % 结束日志预分配函数。

function [demod, st] = local_apply_detection_calibration(demod, st, p) % 用V4.3在线检测矩阵估计值反校正两路同步解调量。
if p.calib.enable && p.calib.detectionCorrectionEnable % 判断是否启用在线检测矩阵补偿。
    alphaCalib = local_calib_alpha(st, p); % 读取V4.3.1在线补偿安全释放权重，未收敛前保持接近零。
    detectionMatrix = eye(2) + alphaCalib * (st.calibDetectionMatrixHat - eye(2)); % 采用单位阵到估计矩阵的加权释放，避免RLS瞬时误差直接污染解调量。
    if alphaCalib > 0 && all(isfinite(detectionMatrix(:))) && rcond(detectionMatrix) > 1e-6 % 检查矩阵是否数值可逆且补偿权重已释放。
        cVector = detectionMatrix \ [demod.Cx; demod.Cy]; % 对同相分量执行二通道反串扰和增益校正。
        sVector = detectionMatrix \ [demod.Sx; demod.Sy]; % 对正交分量执行同一检测矩阵反校正。
        demod.Cx = cVector(1); % 写回校正后的X同相分量。
        demod.Cy = cVector(2); % 写回校正后的Y同相分量。
        demod.Sx = sVector(1); % 写回校正后的X正交分量。
        demod.Sy = sVector(2); % 写回校正后的Y正交分量。
    end % 结束检测矩阵可逆性检查。
end % 结束检测矩阵补偿开关判断。
end % 结束V4.3检测矩阵在线反校正函数。

function [demod, st, x, diag] = local_frontend_block(t0, x, st, p, samplesPerCtrl, TsAdc, temperature) % 生成一个控制周期的原始载波并完成数字正交解调。
sumCx = 0; % 初始化X通道同相累加器。
sumSx = 0; % 初始化X通道正交累加器。
sumCy = 0; % 初始化Y通道同相累加器。
sumSy = 0; % 初始化Y通道正交累加器。
saturated = false; % 初始化本控制周期的AFE或ADC饱和标志。
fixedOverflow = false; % 初始化本控制周期数字解调量定点溢出标志。
selftestInjected = st.mode == 5; % 锁存本ADC块开始时是否真实处于SELFTEST载波注入状态。
alphaAfe = exp(-2 * pi * p.afe.bandwidthHz * TsAdc); % 计算模拟前端一阶低通离散极点。
for n = 1:samplesPerCtrl % 遍历本控制周期内的全部ADC采样点。
    tn = t0 + (n - 1) * TsAdc; % 计算当前ADC样本的绝对时间。
    deltaT = temperature - p.env.referenceTemperature; % 计算当前温差。
    resonanceHz = p.res.f0 * (1 + p.env.resonanceTempCoeff1 * deltaT + p.env.resonanceTempCoeff2 * deltaT ^ 2); % 计算温度引起的谐振频率变化。
    resonanceHz = resonanceHz + p.res.duffingHzPerEnergy * (x.energy - p.res.energyTarget); % 加入能量相关的Duffing等效频移。
    resonanceHz = resonanceHz + 0.5 * p.res.frequencySplitHz * cos(4 * (x.theta - p.res.stiffnessAxis)); % 加入频率裂解随驻波角变化的投影。
    x.resPhase = local_wrap_2pi(x.resPhase + 2 * pi * resonanceHz * TsAdc + p.res.phaseNoiseRad * randn); % 推进谐振载波相位并加入相位噪声。
    mainAmplitude = sqrt(max(x.energy, eps)); % 由归一化能量计算主驻波幅值。
    quadAmplitude = x.quad / max(2 * mainAmplitude, eps); % 由Q等效量反算正交驻波幅值。
    rawX = mainAmplitude * cos(2 * x.theta) * cos(x.resPhase) - quadAmplitude * sin(2 * x.theta) * sin(x.resPhase); % 依据公开全角模型生成X电极检测载波。
    rawY = mainAmplitude * sin(2 * x.theta) * cos(x.resPhase) + quadAmplitude * cos(2 * x.theta) * sin(x.resPhase); % 依据公开全角模型生成Y电极检测载波。
    analog = [rawX; rawY]; % 组成两路模拟检测向量。
    if selftestInjected % 判断本ADC块是否正在执行真实检测链路SELFTEST。
        selftestAngle = 2 * pi * p.selftest.modulationHz * tn; % 计算SELFTEST低频旋转空间矢量的当前相位。
        selftestCarrier = cos(x.resPhase); % 生成与真实谐振载波同相的受限测试载波。
        selftestVector = p.selftest.injectionScale * p.selftest.injectionAmplitude * [cos(selftestAngle); sin(selftestAngle)]; % 构造幅值受限且方向旋转的两通道测试空间矢量。
        analog = analog + selftestVector * selftestCarrier; % 在AFE之前叠加测试载波以覆盖模拟前端、ADC、NCO混频和抽取链路。
    end % 结束SELFTEST检测载波注入判断。
    if p.afe.enable % 判断是否启用AFE非理想模型。
        analog = p.afe.crossMatrix * analog + p.afe.offset; % 加入通道增益、串扰和直流偏置。
        st.afeState = alphaAfe * st.afeState + (1 - alphaAfe) * analog; % 通过一阶低通模拟AFE有限带宽。
        analog = st.afeState + p.afe.noiseSigma .* randn(2, 1); % 加入AFE等效输入白噪声。
    end % 结束AFE非理想模型判断。
    if p.fault.enable && tn >= p.fault.time && strcmpi(p.fault.type, 'afe_offset') % 判断是否到达AFE偏置故障注入时刻。
        analog = analog + p.fault.magnitude * [1; -1]; % 向两检测通道注入反向偏置故障。
    end % 结束AFE偏置故障注入判断。
    if p.fault.enable && tn >= p.fault.time && strcmpi(p.fault.type, 'signal_dropout') % 判断是否到达检测载波完全丢失故障注入时刻。
        analog = zeros(2, 1); % 将两路检测信号强制置零以验证DPLL有效性冻结和失效诊断。
    end % 结束检测载波丢失故障注入判断。
    jitterGain = 2 * pi * resonanceHz * p.adc.jitterRms; % 计算采样抖动折算的相对幅度系数。
    analog = analog + jitterGain * abs(analog) .* randn(2, 1); % 以小信号近似加入采样时钟抖动噪声。
    [analog, satAfe] = local_clip(analog, -p.afe.fullScale, p.afe.fullScale); % 执行AFE输出满量程限幅。
    [adc, satAdc] = local_adc_quantize(analog, p); % 执行ADC故障、量化和满量程限制。
    if p.fault.enable && tn >= p.fault.time && strcmpi(p.fault.type, 'adc_stuck') % 判断是否到达ADC卡死故障注入时刻。
        adc = p.fault.magnitude * ones(2, 1); % 将两路ADC输出固定到指定故障码。
        satAdc = true; % 把ADC卡死标记为接口异常。
    end % 结束ADC卡死故障注入判断。
    saturated = saturated || satAfe || satAdc; % 合并本采样点的AFE和ADC饱和标志。
    ncoCos = cos(st.ncoPhase); % 生成当前NCO余弦参考载波。
    ncoSin = sin(st.ncoPhase); % 生成当前NCO正弦参考载波。
    sumCx = sumCx + 2 * adc(1) * ncoCos; % 累加X通道同相混频结果。
    sumSx = sumSx + 2 * adc(1) * ncoSin; % 累加X通道正交混频结果。
    sumCy = sumCy + 2 * adc(2) * ncoCos; % 累加Y通道同相混频结果。
    sumSy = sumSy + 2 * adc(2) * ncoSin; % 累加Y通道正交混频结果。
    st.ncoPhase = local_wrap_2pi(st.ncoPhase + 2 * pi * st.ncoFrequencyHz * TsAdc); % 按当前频率控制字推进NCO相位累加器。
end % 结束ADC采样块循环。
demod.Cx = sumCx / samplesPerCtrl; % 对X通道同相累加结果做块平均抽取。
demod.Sx = sumSx / samplesPerCtrl; % 对X通道正交累加结果做块平均抽取。
demod.Cy = sumCy / samplesPerCtrl; % 对Y通道同相累加结果做块平均抽取。
demod.Sy = sumSy / samplesPerCtrl; % 对Y通道正交累加结果做块平均抽取。
if p.asic.fixedEnable % 判断是否对解调结果施加ASIC定点字长约束。
    [demod.Cx, sat1] = local_fixed(demod.Cx, p.asic.demodWordLength, p.asic.demodFractionLength); % 量化X同相分量。
    [demod.Sx, sat2] = local_fixed(demod.Sx, p.asic.demodWordLength, p.asic.demodFractionLength); % 量化X正交分量。
    [demod.Cy, sat3] = local_fixed(demod.Cy, p.asic.demodWordLength, p.asic.demodFractionLength); % 量化Y同相分量。
    [demod.Sy, sat4] = local_fixed(demod.Sy, p.asic.demodWordLength, p.asic.demodFractionLength); % 量化Y正交分量。
    st.fixedOverflowCount = st.fixedOverflowCount + double(sat1 || sat2 || sat3 || sat4); % 统计解调数据路径的真实定点溢出。
    fixedOverflow = sat1 || sat2 || sat3 || sat4; % 保存本拍解调数据路径定点溢出状态供测量有效性判定。
end % 结束解调定点量化判断。
diag.saturated = saturated; % 输出本控制周期的模拟与ADC饱和诊断。
diag.fixedOverflow = fixedOverflow; % 输出本控制周期数字解调量定点溢出诊断。
diag.selftestInjected = selftestInjected; % 输出本控制周期前端是否真实叠加SELFTEST测试载波。
end % 结束原始载波与数字前端函数。

function [adc, saturated] = local_adc_quantize(analog, p) % 执行双极性ADC的抖动、限幅和量化。
lsb = 2 * p.adc.fullScale / 2 ^ p.adc.bits; % 计算ADC最小量化步长。
if p.adc.enableDither % 判断是否启用半LSB均匀抖动。
    analog = analog + lsb * (rand(size(analog)) - 0.5); % 在量化前加入均匀抖动以抑制极限环。
end % 结束ADC抖动判断。
[limited, saturated] = local_clip(analog, -p.adc.fullScale, p.adc.fullScale - lsb); % 将输入限制在可表示的双极性码范围内。
adc = round(limited / lsb) * lsb; % 把模拟量舍入到最近的ADC码。
end % 结束ADC量化函数。

function [inv, saturated] = local_invariants(demod, p) % 由Cx、Sx、Cy和Sy构造全角控制需要的五个不变量。
Cx = demod.Cx; % 读取X通道同相分量。
Sx = demod.Sx; % 读取X通道正交分量。
Cy = demod.Cy; % 读取Y通道同相分量。
Sy = demod.Sy; % 读取Y通道正交分量。
inv.E = Cx ^ 2 + Sx ^ 2 + Cy ^ 2 + Sy ^ 2; % 计算主驻波与正交波总能量不变量。
inv.Q = 2 * (Cx * Sy - Cy * Sx); % 计算主驻波与正交波耦合不变量。
inv.R = Cx ^ 2 + Sx ^ 2 - Cy ^ 2 - Sy ^ 2; % 计算包含cos(4theta)的驻波方位不变量。
inv.S = 2 * (Cx * Cy + Sx * Sy); % 计算包含sin(4theta)的驻波方位不变量。
inv.L = 2 * (Cx * Sx + Cy * Sy); % 计算谐振载波与NCO之间的频率相位误差信号。
saturated = false; % 初始化不变量定点饱和标志。
if p.asic.fixedEnable % 判断是否启用不变量数据路径的定点约束。
    [inv.E, sat1] = local_fixed(inv.E, p.asic.invariantWordLength, p.asic.invariantFractionLength); % 量化能量不变量。
    [inv.Q, sat2] = local_fixed(inv.Q, p.asic.invariantWordLength, p.asic.invariantFractionLength); % 量化正交不变量。
    [inv.R, sat3] = local_fixed(inv.R, p.asic.invariantWordLength, p.asic.invariantFractionLength); % 量化余弦方位不变量。
    [inv.S, sat4] = local_fixed(inv.S, p.asic.invariantWordLength, p.asic.invariantFractionLength); % 量化正弦方位不变量。
    [inv.L, sat5] = local_fixed(inv.L, p.asic.invariantWordLength, p.asic.invariantFractionLength); % 量化相位误差信号。
    saturated = sat1 || sat2 || sat3 || sat4 || sat5; % 合并五条数据路径的定点饱和标志。
end % 结束不变量定点量化判断。
end % 结束不变量计算函数。

function [cmd, nav, st] = local_asic_control(tk, inv, demod, measurementFlags, st, p, temperature) % 执行数字ASIC的DPLL、完整抗饱和、Kalman解算、SELFTEST和状态管理。
Ts = p.sim.TsCtrl; % 读取数字控制周期。
modeAtEntry = st.mode; % 保存进入本控制拍时的状态机模式以隔离SELFTEST对导航输出的污染。
phaseMagnitude = hypot(inv.R, inv.S); % 计算四倍角方位矢量幅值。
finiteMeasurement = all(isfinite([demod.Cx demod.Sx demod.Cy demod.Sy inv.E inv.Q inv.R inv.S inv.L phaseMagnitude])); % 检查解调量和全部不变量是否均为有限数值。
lowEnergy = ~finiteMeasurement || inv.E < p.pll.energyValidThreshold; % 形成能量不足或非有限数导致的无效原因。
lowPhaseMagnitude = ~finiteMeasurement || phaseMagnitude <= p.asic.phaseValidThreshold; % 形成四倍角方位矢量幅值不足或非有限数导致的无效原因。
measurementInvalidReason = uint32(0); % 初始化本拍测量无效原因位图。
measurementInvalidReason = bitset(measurementInvalidReason, 1, lowEnergy); % 设置bit0能量低于DPLL有效门限。
measurementInvalidReason = bitset(measurementInvalidReason, 2, lowPhaseMagnitude); % 设置bit1四倍角方位矢量幅值不足。
measurementInvalidReason = bitset(measurementInvalidReason, 3, measurementFlags.frontendSaturated); % 设置bit2本拍AFE或ADC发生饱和。
measurementInvalidReason = bitset(measurementInvalidReason, 4, measurementFlags.fixedOverflow); % 设置bit3本拍不变量定点路径发生溢出。
measurementInvalidReason = bitset(measurementInvalidReason, 5, ~finiteMeasurement); % 设置bit4本拍解调量或不变量出现非有限数。
phaseValid = measurementInvalidReason == 0; % 仅在幅值、量程、字长和有限数全部可信时允许测量进入DPLL与方位观测器。
phaseDenominator = max(inv.E, p.pll.energyValidThreshold); % 构造DPLL归一化相位鉴别器的安全分母。
phaseError = 0; % 默认把无效测量对应的DPLL相位误差置零。
if phaseValid % 判断本拍测量是否允许进入DPLL环路滤波器。
    phaseError = -inv.L / phaseDenominator; % 按既定相位鉴别器极性计算归一化频率相位误差。
end % 结束DPLL相位误差有效性判断。
pllFrozen = p.pll.freezeOnInvalid && ~phaseValid; % 生成能量或方位矢量无效时的DPLL冻结条件。
pllIntSat = false; % 初始化DPLL积分器限幅标志。
pllOutSat = false; % 初始化DPLL频率校正输出限幅标志。
pllAwActive = false; % 初始化DPLL本拍抗饱和动作标志。
if pllFrozen % 判断是否需要保持上一拍DPLL积分器和NCO频率控制字。
    st.pllFreezeCount = st.pllFreezeCount + 1; % 累加DPLL有效性冻结控制拍数。
else % 处理DPLL测量有效或用户关闭冻结功能的情况。
    pllIntegratorLimit = p.pll.integratorLimitHz / max(abs(p.pll.kiHz), eps); % 把DPLL积分频率贡献限幅换算为积分器状态限幅。
    [frequencyCorrection, st.pllIntegratorHz, pllIntSat, pllOutSat, pllAwActive] = local_pi_aw(phaseError, st.pllIntegratorHz, p.pll.kpHz, p.pll.kiHz, pllIntegratorLimit, p.pll.frequencyLimitHz, p.pll.backCalculationGain, p.pll.antiWindupEnable, Ts); % 采用条件积分与反算联合抗饱和计算DPLL频率校正量。
    st.ncoFrequencyHz = p.res.f0 + frequencyCorrection; % 更新下一ADC采样块使用的NCO频率控制字。
end % 结束DPLL有效性冻结判断。
st.pllLimitCount = st.pllLimitCount + double(pllIntSat || pllOutSat); % 单独累计DPLL积分器与频率输出限幅事件。
st.antiWindupCount = st.antiWindupCount + double(pllAwActive); % 累计DPLL抗饱和实际动作事件。
phi = atan2(inv.S, inv.R); % 用反正切等效CORDIC得到负pi至正pi范围的四倍角相位。
angleQuantum = 2 * pi / 2 ^ p.asic.angleBits; % 计算CORDIC有限位宽相位量化步长。
phi = round(phi / angleQuantum) * angleQuantum; % 把四倍角相位舍入到CORDIC规划位宽。
deltaPhi = 0; % 默认在相位无效或重新捕获首拍冻结四倍角增量。
if phaseValid && st.phaseWasValid % 判断当前与上一拍相位是否都有效。
    deltaPhi = local_wrap_pi(phi - st.phiPrevious); % 计算连续有效测量之间的最小四倍角相位增量。
    st.phiPrevious = phi; % 保存当前四倍角相位供下一拍展开使用。
elseif phaseValid % 处理相位从无效恢复到有效的重新捕获首拍。
    st.phiPrevious = phi; % 仅重建四倍角展开锚点而不积分失效期间未知相位变化。
end % 结束四倍角相位有效性与重新捕获判断。
st.phaseWasValid = phaseValid; % 保存本拍相位有效性供下一拍识别重新捕获边界。
unwrapFault = abs(deltaPhi) > p.asic.unwrapLimit; % 检查四倍角单拍增量是否超过无歧义展开保护门限。
if unwrapFault % 判断是否发生四倍角展开异常。
    deltaPhi = 0; % 展开异常时冻结本拍驻波角以避免整周跳变污染输出。
    st.unwrapFaultCount = st.unwrapFaultCount + 1; % 累加四倍角展开异常计数器。
end % 结束四倍角展开异常处理。
st.thetaPrevious = st.thetaEstimate; % 保存更新前的连续驻波角供禁用Kalman时计算一阶差分。
st.thetaEstimate = st.thetaEstimate + 0.25 * deltaPhi; % 将连续四倍角增量除以四得到连续物理驻波角测量。
directThetaRate = (st.thetaEstimate - st.thetaPrevious) / Ts; % 计算兼容模式使用的驻波角一阶差分角速度。
kalmanMeasurementValid = phaseValid && ~unwrapFault && modeAtEntry ~= 5; % 仅允许正常导航阶段的有效无异常相位更新Kalman观测器。
kalmanUpdated = false; % 初始化本拍Kalman测量更新标志。
if p.kalman.enable % 判断是否启用二状态Kalman速率估计器。
    [st, kalmanUpdated] = local_kalman_step(st, st.thetaEstimate, kalmanMeasurementValid, p, Ts); % 使用连续驻波角测量更新角度与角速度状态。
    thetaRate = st.kalmanState(2); % 读取Kalman估计的驻波角速度作为Bryan解算输入。
else % 处理关闭Kalman以进行兼容性或对照试验的情况。
    st.kalmanState = [st.thetaEstimate; directThetaRate]; % 用直接测量和一阶差分保持Kalman诊断字段具有明确意义。
    st.kalmanInnovation = 0; % 关闭Kalman时将创新诊断量清零。
    thetaRate = directThetaRate; % 使用V4.1兼容的一阶差分驻波角速度。
end % 结束Kalman速率估计选择。
virtualRateCommand = 0; % 初始化零均值虚拟进动命令。
if p.virtual.enable % 判断是否启用周期虚拟进动。
    virtualRateCommand = p.virtual.amplitudeDps * pi / 180 * sin(2 * pi * p.virtual.frequencyHz * tk + p.virtual.phaseRad); % 生成零均值正弦虚拟进动速率命令。
end % 结束虚拟进动命令生成判断。
rawRate = -(thetaRate - virtualRateCommand) / p.res.bryan; % 根据Bryan关系从驻波进动率恢复载体角速度。
harmonicCorrection = 0; % 初始化角位置相关谐波补偿量。
if p.comp.enableHarmonic % 判断是否启用角位置相关漂移补偿。
    driftHat = 0.5 * p.comp.dampingAnisotropyHat * sin(4 * (st.thetaEstimate - p.comp.dampingAxisHat)); % 估计阻尼不均匀引起的驻波角漂移。
    driftHat = driftHat + pi * p.comp.frequencySplitHatHz * cos(4 * (st.thetaEstimate - p.comp.stiffnessAxisHat)) * inv.Q / max(inv.E, eps); % 估计频率裂解与残余正交耦合产生的驻波角漂移。
    extra = p.comp.extraHarmonicsDps * pi / 180; % 将附加谐波补偿系数从度每秒转换为弧度每秒。
    harmonicCorrection = driftHat / p.res.bryan + extra(1) * sin(4 * st.thetaEstimate) + extra(2) * cos(4 * st.thetaEstimate) + extra(3) * sin(8 * st.thetaEstimate) + extra(4) * cos(8 * st.thetaEstimate); % 合成四次与八次角位置谐波补偿。
end % 结束谐波补偿判断。
deltaT = temperature - p.env.referenceTemperature; % 计算当前温差供温度补偿使用。
temperatureBiasHat = 0; % 初始化温度零偏估计量。
if p.comp.enableTemperature % 判断是否启用温度零偏补偿。
    temperatureBiasHat = p.env.rateBiasAtRef + p.env.rateBiasTemp1 * deltaT + p.env.rateBiasTemp2 * deltaT ^ 2; % 按二阶多项式估计等效角速度零偏。
end % 结束温度补偿判断。
compensatedRate = rawRate + harmonicCorrection - temperatureBiasHat; % 合成Kalman速率、角谐波与温度补偿后的角速度。
[st, harmonicCorrection, compensatedRate] = local_online_calibration_step(tk, inv, demod, measurementFlags, st, p, phaseValid, unwrapFault, modeAtEntry, harmonicCorrection, rawRate, temperatureBiasHat); % 执行V4.3在线检测/驱动矩阵、正弦同步解调、RLS/EKF和安全系数更新。
rateAlpha = 1 - exp(-2 * pi * p.ctrl.rateLpfHz * Ts); % 计算角速度显示输出一阶低通离散系数。
if modeAtEntry ~= 5 && modeAtEntry ~= 6 % 判断本拍进入时是否允许更新导航角度和角速度输出。
    st.rateOutput = st.rateOutput + rateAlpha * (compensatedRate - st.rateOutput); % 更新带宽明确的导航角速度显示输出。
    st.angleOutput = st.angleOutput + compensatedRate * Ts; % 对未经过显示低通的补偿角速度积分以保持阶跃面积。
end % 结束SELFTEST与FAULT期间导航输出冻结判断。
energyError = p.res.energyTarget - inv.E; % 计算能量控制误差。
quadError = -inv.Q; % 计算正交控制误差。
st.modeTime = st.modeTime + Ts; % 累加当前状态驻留时间。
enteredSelftest = false; % 初始化本拍是否刚触发SELFTEST的标志。
if st.mode == 1 && st.modeTime >= p.ctrl.startupTime % 判断起振阶段是否达到最短持续时间。
    st.mode = uint8(2); % 从STARTUP切换到ACQUIRE。
    st.modeTime = 0; % 清零ACQUIRE状态驻留计时器。
end % 结束STARTUP状态转移判断。
energyLocked = abs(inv.E - p.res.energyTarget) <= p.ctrl.energyLockTolerance * p.res.energyTarget; % 判断能量是否进入锁定窗口。
quadLocked = abs(inv.Q) <= p.ctrl.quadLockTolerance; % 判断正交量是否进入锁定窗口。
phaseLocked = phaseValid && abs(phaseError) <= p.pll.lockPhaseError; % 判断DPLL测量有效且归一化相位误差进入锁定窗口。
if st.mode == 2 && st.modeTime >= p.ctrl.acquireTime && energyLocked && quadLocked && phaseLocked % 判断捕获阶段是否满足进入RUN的全部条件。
    if p.ctrl.bumplessTransferEnable % 判断是否在受限捕获驱动切换到正常PI前重建闭环初值。
        if isfield(p.ctrl, 'runEntrySteadyFeedforwardEnable') && p.ctrl.runEntrySteadyFeedforwardEnable % 判断是否采用慢变量稳态前馈而不是继承ACQUIRE限幅输出。
            energyTransferCommand = local_energy_hold_command(inv, st, p); % 根据能量慢变量稳态方程计算RUN入口能量保持驱动。
            quadTransferCommand = local_quad_hold_command(inv, st, p); % 根据正交慢变量稳态方程计算RUN入口正交保持驱动。
        else % 处理兼容旧版无扰切换的情况。
            energyTransferCommand = st.previousEnergyCommand; % 兼容旧版时继续使用上一拍能量命令作为反算目标。
            quadTransferCommand = st.previousQuadCommand; % 兼容旧版时继续使用上一拍正交命令作为反算目标。
        end % 结束RUN入口反算目标来源选择。
        [energyTransferCommand, ~] = local_clip(energyTransferCommand, -p.ctrl.energyLimit, p.ctrl.energyLimit); % 把RUN入口能量反算目标限制到数字能量通道可实现范围。
        [quadTransferCommand, ~] = local_clip(quadTransferCommand, -p.ctrl.quadLimit, p.ctrl.quadLimit); % 把RUN入口正交反算目标限制到数字正交通道可实现范围。
        requiredEnergyIntegrator = energyTransferCommand / max(abs(p.ctrl.energyKi), eps); % 用零误差稳态驱动对应的积分器初值隔离捕获阶段大比例项。
        requiredQuadIntegrator = quadTransferCommand / max(abs(p.ctrl.quadKi), eps); % 用零误差稳态正交驱动对应的积分器初值隔离捕获阶段大控制字。
        [st.energyIntegrator, ~] = local_clip(requiredEnergyIntegrator, -p.ctrl.integratorLimit, p.ctrl.integratorLimit); % 对能量PI积分器初值执行物理限幅。
        [st.quadIntegrator, ~] = local_clip(requiredQuadIntegrator, -p.ctrl.integratorLimit, p.ctrl.integratorLimit); % 对正交PI积分器初值执行物理限幅。
        energyRunEntryCommand = p.ctrl.energyKp * energyError + p.ctrl.energyKi * st.energyIntegrator; % 计算RUN首拍正常PI在当前误差下应输出的能量控制字。
        quadRunEntryCommand = p.ctrl.quadKp * quadError + p.ctrl.quadKi * st.quadIntegrator; % 计算RUN首拍正常PI在当前误差下应输出的正交控制字。
        [energyRunEntryCommand, ~] = local_clip(energyRunEntryCommand, -p.ctrl.energyLimit, p.ctrl.energyLimit); % 把RUN首拍能量控制字限制到可实现范围。
        [quadRunEntryCommand, ~] = local_clip(quadRunEntryCommand, -p.ctrl.quadLimit, p.ctrl.quadLimit); % 把RUN首拍正交控制字限制到可实现范围。
        if isfield(p.ctrl, 'runEntryFlushPipeline') && p.ctrl.runEntryFlushPipeline % 判断是否同时刷新控制字历史和ASIC至DAC流水线。
            st.previousEnergyCommand = energyRunEntryCommand; % 用RUN首拍PI目标重置能量斜率限制历史，避免从ACQUIRE最大驱动缓慢回落。
            st.previousQuadCommand = quadRunEntryCommand; % 用RUN首拍PI目标重置正交斜率限制历史，避免继承捕获阶段瞬态命令。
            st.controlDelay(1, :) = energyRunEntryCommand; % 刷新能量控制流水线，避免后续三拍继续输出捕获限幅驱动。
            st.controlDelay(2, :) = quadRunEntryCommand; % 刷新正交控制流水线，使RUN首拍执行器与PI目标时序一致。
        end % 结束RUN入口控制历史刷新。
    end % 结束ACQUIRE到RUN闭环初值重建判断。
    st.mode = uint8(3); % 从ACQUIRE切换到RUN。
    st.modeTime = 0; % 清零RUN状态驻留计时器。
    st.locked = true; % 锁存闭环曾经完成锁定的历史标志。
    st.angleOutput = 0; % 在首次进入RUN时清零导航角参考。
end % 结束ACQUIRE到RUN状态转移判断。
if p.selftest.enable && st.mode == 3 && tk >= p.selftest.startTime && ~st.selftestDone % 判断是否到达配置时刻且SELFTEST尚未执行。
    st.mode = uint8(5); % 从RUN切换到SELFTEST状态。
    st.modeTime = 0; % 清零SELFTEST状态驻留计时器。
    st.selftestSampleCount = 0; % 清零SELFTEST同步相关样本计数器。
    st.selftestInPhaseSum = 0; % 清零SELFTEST同相同步相关累加器。
    st.selftestQuadratureSum = 0; % 清零SELFTEST正交同步相关累加器。
    enteredSelftest = true; % 标记本拍刚触发SELFTEST且当前解调数据尚未包含测试载波。
end % 结束运行中SELFTEST触发判断。
if st.mode == 5 && ~enteredSelftest % 判断当前解调数据是否来自已经注入测试载波的SELFTEST控制拍。
    selftestAngle = 2 * pi * p.selftest.modulationHz * tk; % 计算控制域SELFTEST同步解调参考相位。
    selftestInPhase = demod.Cx * cos(selftestAngle) + demod.Cy * sin(selftestAngle); % 对两路同相解调量执行旋转矢量同相投影。
    selftestQuadrature = -demod.Cx * sin(selftestAngle) + demod.Cy * cos(selftestAngle); % 对两路同相解调量执行旋转矢量正交投影。
    st.selftestSampleCount = st.selftestSampleCount + 1; % 累加SELFTEST有效同步相关样本数。
    st.selftestInPhaseSum = st.selftestInPhaseSum + selftestInPhase; % 累加SELFTEST同相投影响应。
    st.selftestQuadratureSum = st.selftestQuadratureSum + selftestQuadrature; % 累加SELFTEST正交投影响应。
    if st.modeTime >= p.selftest.duration % 判断SELFTEST是否已经达到配置的累计时长。
        meanInPhase = st.selftestInPhaseSum / max(st.selftestSampleCount, 1); % 计算SELFTEST平均同相响应幅值。
        meanQuadrature = st.selftestQuadratureSum / max(st.selftestSampleCount, 1); % 计算SELFTEST平均正交残差幅值。
        st.selftestGainEstimate = meanInPhase / max(p.selftest.injectionAmplitude, eps); % 估计带符号的AFE至ADC与数字解调链路归一化同相增益以检测极性反转。
        st.selftestQuadratureRatio = abs(meanQuadrature) / max(abs(meanInPhase), eps); % 估计检测链路正交残差相对同相响应的比例。
        gainPassed = st.selftestGainEstimate >= p.selftest.minimumGain && st.selftestGainEstimate <= p.selftest.maximumGain; % 检查SELFTEST估计增益是否处于允许窗口。
        quadraturePassed = st.selftestQuadratureRatio <= p.selftest.maximumQuadratureRatio; % 检查SELFTEST正交残差比例是否满足门限。
        st.selftestPassed = gainPassed && quadraturePassed; % 汇总SELFTEST检测链路通过判据。
        st.selftestFailed = ~st.selftestPassed; % 形成SELFTEST失败锁存标志。
        st.selftestDone = true; % 锁存SELFTEST已经完成。
        if st.selftestPassed && p.selftest.returnToRunOnPass % 判断SELFTEST通过后是否返回正常导航状态。
            st.mode = uint8(3); % 从SELFTEST返回RUN。
            st.modeTime = 0; % 清零返回RUN后的状态驻留计时器。
        elseif st.selftestFailed % 判断SELFTEST是否检测到检测链路增益或正交响应异常。
            st.mode = uint8(6); % SELFTEST失败后进入FAULT安全状态。
            st.faultLatched = true; % 锁存SELFTEST失败故障。
        end % 结束SELFTEST完成后的状态选择。
    end % 结束SELFTEST累计时长判断。
end % 结束SELFTEST同步相关与判定处理。
energyCommand = 0; % 初始化能量控制命令。
quadCommand = 0; % 初始化正交控制命令。
energyIntSat = false; % 初始化能量PI积分器限幅标志。
quadIntSat = false; % 初始化正交PI积分器限幅标志。
energyOutSat = false; % 初始化能量PI输出限幅标志。
quadOutSat = false; % 初始化正交PI输出限幅标志。
energyAwActive = false; % 初始化能量PI抗饱和动作标志。
quadAwActive = false; % 初始化正交PI抗饱和动作标志。
actuatorTrackingActive = false; % 初始化上一拍DAC与驱动实际输出跟踪反算标志。
slewTrackingActive = false; % 初始化本拍控制字斜率限制跟踪反算标志。
trackingIntSat = false; % 初始化执行器与斜率跟踪反算造成的积分器限幅标志。
closedLoopControl = st.mode == 2 || st.mode == 3 || st.mode == 5; % 形成允许能量与正交闭环控制的状态条件。
energyLowerLockBoundary = p.res.energyTarget * (1 - p.ctrl.energyLockTolerance); % 计算能量锁定窗口下边界供受限捕获驱动使用。
energyUpperLockBoundary = p.res.energyTarget * (1 + p.ctrl.energyLockTolerance); % 计算能量锁定窗口上边界供受限捕获制动使用。
energyAcquireBoost = st.mode == 2 && inv.E < energyLowerLockBoundary; % 判断ACQUIRE阶段能量是否低于锁定窗口并需要受限正向驱动。
energyAcquireBrake = st.mode == 2 && inv.E > energyUpperLockBoundary; % 判断ACQUIRE阶段能量是否高于锁定窗口并需要受限反向驱动。
energyPiActive = false; % 初始化本拍能量PI是否实际参与控制的标志。
quadPiActive = false; % 初始化本拍正交PI是否实际参与控制的标志。
if closedLoopControl && p.ctrl.antiWindupEnable && p.ctrl.actuatorTrackingEnable && st.previousActuatorSaturated % 判断上一拍DAC或驱动饱和后是否把流水线对齐的实际输出误差反算回积分器。
    [st.energyIntegrator, energyTrackSat, energyTrackActive] = local_tracking_aw(st.energyIntegrator, st.previousActuatorOutput(1), st.previousDeliveredCommand(1), p.ctrl.energyKi, p.ctrl.actuatorTrackingGain, p.ctrl.integratorLimit, Ts); % 把上一拍能量DAC与驱动实现误差反算到能量PI积分器。
    [st.quadIntegrator, quadTrackSat, quadTrackActive] = local_tracking_aw(st.quadIntegrator, st.previousActuatorOutput(2), st.previousDeliveredCommand(2), p.ctrl.quadKi, p.ctrl.actuatorTrackingGain, p.ctrl.integratorLimit, Ts); % 把上一拍正交DAC与驱动实现误差反算到正交PI积分器。
    actuatorTrackingActive = energyTrackActive || quadTrackActive; % 汇总两路执行器实现误差跟踪反算状态。
    trackingIntSat = energyTrackSat || quadTrackSat; % 汇总两路执行器跟踪反算造成的积分器限幅状态。
end % 结束上一拍执行器实际输出跟踪反算。
if st.mode == 1 % 判断当前是否处于开环起振阶段。
    energyCommand = p.ctrl.startupDrive; % 在STARTUP阶段施加固定开环能量驱动目标。
elseif closedLoopControl % 判断当前是否处于闭环捕获、运行或自检阶段。
    if energyAcquireBoost % 判断是否需要以积分器冻结方式执行能量受限捕获驱动。
        energyCommand = p.ctrl.energyLimit; % 在低能量捕获区施加最大允许正向驱动并避免PI积分累积。
        energyOutSat = true; % 把受限捕获驱动记录为有意的控制输出约束动作。
        energyAwActive = true; % 标记能量积分器冻结属于完整抗饱和捕获管理动作。
    elseif energyAcquireBrake % 判断是否需要以积分器冻结方式执行高能量受限制动。
        energyCommand = -p.ctrl.energyLimit; % 在高能量捕获区施加最大允许反向驱动并避免PI积分累积。
        energyOutSat = true; % 把受限捕获制动记录为有意的控制输出约束动作。
        energyAwActive = true; % 标记能量积分器冻结属于完整抗饱和捕获管理动作。
    else % 处理能量已经进入捕获窗口或处于RUN与SELFTEST的情况。
        [energyCommand, st.energyIntegrator, energyIntSat, energyOutSat, energyAwActive] = local_pi_aw(energyError, st.energyIntegrator, p.ctrl.energyKp, p.ctrl.energyKi, p.ctrl.integratorLimit, p.ctrl.energyLimit, p.ctrl.energyBackCalculationGain, p.ctrl.antiWindupEnable, Ts); % 采用完整抗饱和PI计算能量控制字。
        energyPiActive = true; % 标记本拍能量控制字来自正常完整抗饱和PI。
    end % 结束ACQUIRE受限驱动与正常能量PI选择。
    [quadCommand, st.quadIntegrator, quadIntSat, quadOutSat, quadAwActive] = local_pi_aw(quadError, st.quadIntegrator, p.ctrl.quadKp, p.ctrl.quadKi, p.ctrl.integratorLimit, p.ctrl.quadLimit, p.ctrl.quadBackCalculationGain, p.ctrl.antiWindupEnable, Ts); % 采用完整抗饱和PI计算正交控制字。
    quadPiActive = true; % 标记本拍正交控制字来自正常完整抗饱和PI。
end % 结束能量与正交控制模式判断。
if p.calib.enable && p.calib.excitationEnable && st.mode == 3 && tk >= p.calib.startTime % 判断是否在RUN阶段叠加V4.3在线标定正弦自激。
    probeSin = sin(2 * pi * p.calib.excitationFrequencyHz * tk); % 生成能量通道自激正弦参考。
    probeCos = cos(2 * pi * p.calib.excitationFrequencyHz * tk); % 生成正交通道正交相位自激参考。
    excitationRamp = min(1, max(0, (tk - p.calib.startTime) / max(0.50, eps))); % 对在线自激幅值执行半秒软启动，避免标定开始瞬间给主闭环注入阶跃扰动。
    energyCommand = energyCommand + excitationRamp * p.calib.excitationAmplitude * probeSin; % 在能量闭环命令上叠加小幅正弦标定激励。
    quadCommand = quadCommand + excitationRamp * p.calib.excitationAmplitude * probeCos; % 在正交闭环命令上叠加正交相位小幅标定激励。
    [energyCommand, ~] = local_clip(energyCommand, -p.ctrl.energyLimit, p.ctrl.energyLimit); % 保证自激叠加后能量命令仍在数字限幅内。
    [quadCommand, ~] = local_clip(quadCommand, -p.ctrl.quadLimit, p.ctrl.quadLimit); % 保证自激叠加后正交命令仍在数字限幅内。
end % 结束在线标定正弦自激叠加。
rawEnergyCommand = energyCommand; % 保存斜率限制之前的能量PI目标输出供跟踪反算。
rawQuadCommand = quadCommand; % 保存斜率限制之前的正交PI目标输出供跟踪反算。
[energyCommand, energySlewActive] = local_slew_limit(energyCommand, st.previousEnergyCommand, p.ctrl.energySlewPerSec, Ts); % 对能量控制字施加每秒变化率限制。
[quadCommand, quadSlewActive] = local_slew_limit(quadCommand, st.previousQuadCommand, p.ctrl.quadSlewPerSec, Ts); % 对正交控制字施加每秒变化率限制。
if closedLoopControl && p.ctrl.antiWindupEnable % 判断是否把本拍斜率限制器无法实现的PI控制量反算回对应积分器。
    energySlewTrackSat = false; % 默认受限捕获驱动不修改已冻结的能量积分器。
    energySlewTrackActive = false; % 默认受限捕获驱动不计为能量PI斜率反算。
    quadSlewTrackSat = false; % 初始化正交PI斜率反算积分器限幅标志。
    quadSlewTrackActive = false; % 初始化正交PI斜率反算活动标志。
    if energyPiActive % 判断本拍能量命令是否确实来自PI并允许后级斜率跟踪反算。
        [st.energyIntegrator, energySlewTrackSat, energySlewTrackActive] = local_tracking_aw(st.energyIntegrator, energyCommand, rawEnergyCommand, p.ctrl.energyKi, p.ctrl.slewTrackingGain, p.ctrl.integratorLimit, Ts); % 把能量PI控制字斜率限制误差反算到能量积分器。
    end % 结束能量PI斜率跟踪反算判断。
    if quadPiActive % 判断本拍正交命令是否确实来自PI并允许后级斜率跟踪反算。
        [st.quadIntegrator, quadSlewTrackSat, quadSlewTrackActive] = local_tracking_aw(st.quadIntegrator, quadCommand, rawQuadCommand, p.ctrl.quadKi, p.ctrl.slewTrackingGain, p.ctrl.integratorLimit, Ts); % 把正交PI控制字斜率限制误差反算到正交积分器。
    end % 结束正交PI斜率跟踪反算判断。
    slewTrackingActive = energySlewTrackActive || quadSlewTrackActive; % 汇总两路控制字斜率限制跟踪反算状态。
    trackingIntSat = trackingIntSat || energySlewTrackSat || quadSlewTrackSat; % 汇总全部执行器和斜率跟踪反算造成的积分器限幅状态。
end % 结束控制字斜率限制跟踪反算。
st.previousEnergyCommand = energyCommand; % 保存斜率限制后的能量控制字供下一拍使用。
st.previousQuadCommand = quadCommand; % 保存斜率限制后的正交控制字供下一拍使用。
st.piIntegratorLimitCount = st.piIntegratorLimitCount + double(energyIntSat || quadIntSat || trackingIntSat); % 累计能量、正交PI和跟踪反算积分器限幅事件。
st.controlOutputLimitCount = st.controlOutputLimitCount + double(energyOutSat || quadOutSat); % 累计能量与正交PI输出限幅事件。
st.controlSlewLimitCount = st.controlSlewLimitCount + double(energySlewActive || quadSlewActive); % 累计控制字斜率限制动作事件。
st.actuatorTrackingCount = st.actuatorTrackingCount + double(actuatorTrackingActive || slewTrackingActive); % 累计执行器实际输出或斜率限制跟踪反算动作事件。
st.antiWindupCount = st.antiWindupCount + double(energyAwActive || quadAwActive || actuatorTrackingActive || slewTrackingActive); % 累计双PI输出、执行器和斜率限制抗饱和动作事件。
antiWindupActive = pllAwActive || energyAwActive || quadAwActive || actuatorTrackingActive || slewTrackingActive; % 汇总本拍任一控制环和后级执行约束的抗饱和动作状态。
loopDisableFault = p.fault.enable && tk >= p.fault.time && strcmpi(p.fault.type, 'loop_disable'); % 形成控制环关闭故障条件。
if loopDisableFault % 判断是否触发控制环关闭故障。
    energyCommand = 0; % 故障后立即关闭能量驱动命令而不经过斜率限制。
    quadCommand = 0; % 故障后立即关闭正交驱动命令而不经过斜率限制。
end % 结束控制环关闭故障处理。
if p.asic.fixedEnable % 判断是否对三路控制输出施加ASIC定点字长限制。
    [energyCommand, sat1] = local_fixed(energyCommand, p.asic.controlWordLength, p.asic.controlFractionLength); % 量化能量控制命令。
    [quadCommand, sat2] = local_fixed(quadCommand, p.asic.controlWordLength, p.asic.controlFractionLength); % 量化正交控制命令。
    [virtualRateCommand, sat3] = local_fixed(virtualRateCommand, p.asic.controlWordLength, p.asic.controlFractionLength); % 量化虚拟进动命令。
    st.fixedOverflowCount = st.fixedOverflowCount + double(sat1 || sat2 || sat3); % 累计控制字数据路径真实定点溢出事件。
end % 结束控制字定点量化判断。
faultMonitoredMode = st.mode == 3 || st.mode == 5; % 指定RUN和SELFTEST为能量、正交与展开保护监控状态。
instantFault = faultMonitoredMode && (inv.E < p.protect.energyMin || inv.E > p.protect.energyMax || abs(inv.Q) > p.protect.quadMax || unwrapFault || loopDisableFault); % 汇总当前拍保护条件与显式控制环关闭故障。
if instantFault % 判断本拍是否存在需要消抖的瞬时故障。
    st.consecutiveFaultCount = st.consecutiveFaultCount + 1; % 累加连续故障控制拍数。
else % 处理本拍不存在保护故障的情况。
    st.consecutiveFaultCount = 0; % 清零连续故障控制拍数。
end % 结束瞬时故障消抖计数处理。
if st.consecutiveFaultCount >= p.protect.consecutiveFaults % 判断连续故障是否达到锁存门限。
    st.mode = uint8(6); % 将状态机切换到FAULT状态。
    st.faultLatched = true; % 锁存故障历史标志供软件读取。
end % 结束连续故障锁存判断。
if st.mode == 6 % 判断当前是否处于FAULT安全状态。
    energyCommand = 0; % FAULT状态强制关闭能量控制输出。
    quadCommand = 0; % FAULT状态强制关闭正交控制输出。
    virtualRateCommand = 0; % FAULT状态强制关闭虚拟进动输出。
    st.previousEnergyCommand = 0; % 同步清零能量控制字斜率限制历史状态。
    st.previousQuadCommand = 0; % 同步清零正交控制字斜率限制历史状态。
end % 结束FAULT安全输出处理。
cmd = [energyCommand; quadCommand; virtualRateCommand]; % 组成三路数字ASIC控制字向量。
statusWord = uint32(0); % 初始化32位状态字。
statusWord = bitset(statusWord, 1, mod(round(tk / Ts), p.asic.outputDecimation) == 0); % 设置bit0数据就绪标志。
statusWord = bitset(statusWord, 2, st.locked); % 设置bit1闭环曾锁定标志。
statusWord = bitset(statusWord, 3, st.adcSaturationCount > 0); % 设置bit2 ADC或AFE饱和历史标志。
statusWord = bitset(statusWord, 4, st.dacSaturationCount > 0); % 设置bit3 DAC或驱动饱和历史标志。
statusWord = bitset(statusWord, 5, st.fixedOverflowCount > 0); % 设置bit4真实定点溢出历史标志。
statusWord = bitset(statusWord, 6, st.unwrapFaultCount > 0); % 设置bit5四倍角展开异常历史标志。
statusWord = bitset(statusWord, 7, phaseValid); % 设置bit6相位与能量联合有效标志。
statusWord = bitset(statusWord, 8, st.faultLatched); % 设置bit7故障锁存标志。
statusWord = bitset(statusWord, 9, st.pllLimitCount > 0); % 设置bit8 DPLL限幅历史标志。
statusWord = bitset(statusWord, 10, st.piIntegratorLimitCount > 0); % 设置bit9 PI积分器限幅历史标志。
statusWord = bitset(statusWord, 11, st.controlOutputLimitCount > 0); % 设置bit10 控制输出限幅历史标志。
statusWord = bitset(statusWord, 12, pllFrozen); % 设置bit11 DPLL本拍有效性冻结标志。
statusWord = bitset(statusWord, 13, antiWindupActive); % 设置bit12 任一控制环本拍抗饱和动作标志。
statusWord = bitset(statusWord, 14, kalmanUpdated); % 设置bit13 Kalman本拍采用测量更新标志。
statusWord = bitset(statusWord, 15, measurementFlags.selftestInjected); % 设置bit14 本拍前端真实SELFTEST载波活动标志。
statusWord = bitset(statusWord, 16, st.selftestDone); % 设置bit15 SELFTEST完成锁存标志。
statusWord = bitset(statusWord, 17, st.selftestPassed); % 设置bit16 SELFTEST通过锁存标志。
statusWord = bitset(statusWord, 18, st.selftestFailed); % 设置bit17 SELFTEST失败锁存标志。
statusWord = bitset(statusWord, 19, ~phaseValid); % 设置bit18 本拍测量无效标志并配合独立原因位图读取。
statusWord = bitset(statusWord, 20, actuatorTrackingActive || slewTrackingActive); % 设置bit19 本拍后级执行约束跟踪反算活动标志。
statusWord = bitset(statusWord, 21, p.calib.enable && tk >= p.calib.startTime && st.mode == 3); % 设置bit20 V4.3在线标定活动标志。
statusWord = bitset(statusWord, 22, st.calibSafetyFactor <= 1.5); % 设置bit21 在线安全系数偏低预警标志。
nav.theta = st.thetaEstimate; % 输出连续驻波角测量。
nav.angle = st.angleOutput; % 输出连续导航角度。
nav.rate = st.rateOutput; % 输出Kalman估计后再经显示低通的角速度。
nav.rawRate = rawRate; % 输出补偿前的Bryan解算角速度供诊断。
nav.compensatedRate = compensatedRate; % 输出未经显示低通的补偿角速度供导航角积分和离线诊断。
nav.phaseError = phaseError; % 输出归一化DPLL相位误差。
nav.phaseValid = phaseValid; % 输出DPLL与方位解算联合有效标志。
nav.pllFrozen = pllFrozen; % 输出DPLL本拍冻结诊断标志。
nav.antiWindupActive = antiWindupActive; % 输出任一控制环本拍抗饱和动作标志。
nav.kalmanUpdated = kalmanUpdated; % 输出Kalman本拍测量更新标志。
nav.measurementInvalidReason = measurementInvalidReason; % 输出本拍测量无效原因位图供软件诊断冻结来源。
nav.selftestActive = measurementFlags.selftestInjected; % 输出本拍前端真实SELFTEST载波注入标志供统计窗口精确排除。
nav.calibActive = p.calib.enable && tk >= p.calib.startTime && st.mode == 3; % 输出V4.3在线标定活动标志。
nav.statusWord = statusWord; % 输出32位数字接口状态字。
st.previousMode = st.mode; % 保存本拍结束后的状态机模式供下一拍诊断。
end % 结束数字ASIC控制、可信度估计与状态管理函数。

function [st, harmonicCorrection, compensatedRate] = local_online_calibration_step(tk, inv, demod, measurementFlags, st, p, phaseValid, unwrapFault, modeAtEntry, harmonicCorrection, rawRate, temperatureBiasHat) % 执行V4.3在线标定总调度。
Ts = p.sim.TsCtrl; % 读取控制周期。
calibActive = p.calib.enable && modeAtEntry == 3 && tk >= p.calib.startTime && phaseValid && ~unwrapFault; % 仅在RUN、测量可信且超过启动时刻后允许在线标定。
if ~calibActive % 判断本拍是否不满足在线更新条件。
    st.calibPrevE = inv.E; % 仍然刷新上一拍E，避免下次启动差分跨越长时间状态切换。
    st.calibPrevQ = inv.Q; % 仍然刷新上一拍Q。
    st.calibPrevTheta = st.thetaEstimate; % 仍然刷新上一拍驻波角。
    compensatedRate = rawRate + harmonicCorrection - temperatureBiasHat; % 保持原有补偿输出。
    return; % 直接返回。
end % 结束在线标定活动条件判断。
refSin = sin(2 * pi * p.calib.excitationFrequencyHz * tk); % 生成在线正弦自激同步解调同相参考。
refCos = cos(2 * pi * p.calib.excitationFrequencyHz * tk); % 生成在线正弦自激同步解调正交参考。
st.calibSynchronousCount = st.calibSynchronousCount + 1; % 累加同步解调样本数。
st.calibSyncEnergyI = st.calibSyncEnergyI + (inv.E - p.res.energyTarget) * refSin; % 累加能量响应同相分量。
st.calibSyncEnergyQ = st.calibSyncEnergyQ + (inv.E - p.res.energyTarget) * refCos; % 累加能量响应正交分量。
st.calibSyncQuadI = st.calibSyncQuadI + inv.Q * refSin; % 累加正交响应同相分量。
st.calibSyncQuadQ = st.calibSyncQuadQ + inv.Q * refCos; % 累加正交响应正交分量。
windowSamples = max(1, round(p.calib.syncWindowCycles * p.sim.fsCtrl / max(p.calib.excitationFrequencyHz, eps))); % 计算整数周期同步相关窗口样本数。
if st.calibSynchronousCount >= windowSamples % 判断是否达到一个同步相关窗口。
    scale = 2 / max(st.calibSynchronousCount, 1); % 计算正弦同步解调幅值归一化比例。
    st.calibSyncEnergyGain = scale * hypot(st.calibSyncEnergyI, st.calibSyncEnergyQ) / max(p.calib.excitationAmplitude, eps); % 估计能量通道对自激信号的幅值响应。
    st.calibSyncQuadGain = scale * hypot(st.calibSyncQuadI, st.calibSyncQuadQ) / max(p.calib.excitationAmplitude, eps); % 估计正交通道对自激信号的幅值响应。
    st.calibSynchronousCount = 0; % 清零窗口样本计数器。
    st.calibSyncEnergyI = 0; % 清零能量同相累计量。
    st.calibSyncEnergyQ = 0; % 清零能量正交累计量。
    st.calibSyncQuadI = 0; % 清零正交同相累计量。
    st.calibSyncQuadQ = 0; % 清零正交正交累计量。
end % 结束同步相关窗口更新。
if mod(round(tk / Ts), max(1, round(p.calib.updateDecimation))) == 0 % 判断本拍是否到达在线RLS/EKF更新抽取点。
    rawDemod = measurementFlags.rawDemod; % 读取未经过检测矩阵反校正的原始解调量。
    idealVector = sqrt(max(inv.E, eps)) * [cos(2 * st.thetaEstimate); sin(2 * st.thetaEstimate)]; % 根据当前已校正E和驻波角构造理想两通道主驻波空间矢量。
    if p.calib.rlsEnable && all(isfinite([idealVector; rawDemod.Cx; rawDemod.Cy])) && norm(idealVector) > 0.05 % 检查检测矩阵RLS更新是否具备足够激励。
        phiDet = [idealVector(1) idealVector(2) 0 0; 0 0 idealVector(1) idealVector(2)]; % 构造两路检测矩阵观测回归矩阵。
        yDet = [rawDemod.Cx; rawDemod.Cy]; % 构造原始检测向量观测。
        [st.calibDetectionTheta, st.calibDetectionP] = local_rls_vector_update(st.calibDetectionTheta, st.calibDetectionP, phiDet, yDet, p.calib.rlsLambda); % 对检测矩阵执行向量RLS更新。
        detMatrixNew = reshape(st.calibDetectionTheta, 2, 2).'; % 将参数向量还原为检测矩阵。
        detMatrixNew = local_bounded_matrix(detMatrixNew, p.calib.matrixLimit); % 对检测矩阵估计施加物理限幅。
        st.calibDetectionMatrixHat = (1 - p.calib.matrixBlend) * st.calibDetectionMatrixHat + p.calib.matrixBlend * detMatrixNew; % 慢速写入补偿用检测矩阵。
    end % 结束检测矩阵RLS更新。
    eDot = (inv.E - st.calibPrevE) / Ts; % 由相邻控制拍能量不变量估计能量慢变量导数。
    qDot = (inv.Q - st.calibPrevQ) / Ts; % 由相邻控制拍正交不变量估计正交慢变量导数。
    naturalE = -2 * p.res.meanDamping * inv.E; % 计算不含各向异性与驱动的平均能量衰减项。
    naturalQ = -2 * p.res.meanDamping * inv.Q; % 计算不含频率裂解与驱动的平均正交衰减项。
    driveObservation = [eDot - naturalE; qDot - naturalQ]; % 构造由慢变量差分得到的合成驱动观测量。
    driveRegressor = st.calibPrevAct; % 读取上一拍实际能量/正交执行量作为驱动矩阵输入。
    if p.calib.rlsEnable && all(isfinite([driveObservation; driveRegressor])) && norm(driveRegressor) > 5e-4 % 检查驱动矩阵辨识是否具备足够执行激励。
        phiDrv = [driveRegressor(1) driveRegressor(2) 0 0; 0 0 driveRegressor(1) driveRegressor(2)]; % 构造两路驱动矩阵观测回归矩阵。
        [st.calibDriveTheta, st.calibDriveP] = local_rls_vector_update(st.calibDriveTheta, st.calibDriveP, phiDrv, driveObservation, p.calib.rlsLambda); % 对驱动矩阵执行向量RLS更新。
        drvMatrixNew = reshape(st.calibDriveTheta, 2, 2).'; % 将参数向量还原为驱动矩阵。
        drvMatrixNew = local_bounded_matrix(drvMatrixNew, p.calib.matrixLimit); % 对驱动矩阵估计施加物理限幅。
        st.calibDriveMatrixHat = (1 - p.calib.matrixBlend) * st.calibDriveMatrixHat + p.calib.matrixBlend * drvMatrixNew; % 慢速写入驱动预补偿矩阵。
    end % 结束驱动矩阵RLS更新。
    if p.calib.ekfEnable && all(isfinite([eDot qDot inv.E inv.Q st.thetaEstimate])) && inv.E > p.pll.energyValidThreshold % 判断是否允许使用E/Q慢变量差分更新物理机理参数。
        thetaForId = st.calibPrevTheta; % 使用上一拍驻波角与上一拍执行量对齐差分观测。
        zEnergy = -(eDot - st.calibPrevAct(1) + 2 * p.res.meanDamping * inv.E) / max(inv.E, eps); % 构造阻尼不均匀投影观测dC*cos4theta+dS*sin4theta。
        zSplit = -(qDot - st.calibPrevAct(2) + 2 * p.res.meanDamping * inv.Q) / max(4 * pi * max(inv.E, eps), eps); % 构造频率裂解投影观测fC*sin4theta-fS*cos4theta。
        phiEkf = [cos(4 * thetaForId) sin(4 * thetaForId) 0 0; 0 0 sin(4 * thetaForId) -cos(4 * thetaForId)]; % 构造阻尼与裂解谐波参数观测矩阵。
        [st.calibEkfState, st.calibEkfCovariance] = local_kf_parameter_update(st.calibEkfState, st.calibEkfCovariance, phiEkf, [zEnergy; zSplit], p.calib.ekfProcessNoise, p.calib.ekfMeasurementNoise); % 执行EKF式有界线性化参数更新。
        dampingAmp = min(hypot(st.calibEkfState(1), st.calibEkfState(2)), p.calib.maxDampingAnisotropy); % 由谐波系数恢复阻尼不均匀幅值并限幅。
        dampingAxis = 0.25 * atan2(st.calibEkfState(2), st.calibEkfState(1)); % 由阻尼谐波系数恢复阻尼主轴。
        splitHz = min(hypot(st.calibEkfState(3), st.calibEkfState(4)), p.calib.maxFrequencySplitHz); % 由裂解谐波系数恢复频率裂解幅值并限幅。
        stiffnessAxis = 0.25 * atan2(st.calibEkfState(4), st.calibEkfState(3)); % 由裂解谐波系数恢复刚度主轴。
        st.calibDampingAnisotropyHat = (1 - p.calib.ekfBlend) * st.calibDampingAnisotropyHat + p.calib.ekfBlend * dampingAmp; % 慢速写入阻尼不均匀幅值估计。
        st.calibDampingAxisHat = local_wrap_pi((1 - p.calib.ekfBlend) * st.calibDampingAxisHat + p.calib.ekfBlend * dampingAxis); % 慢速写入阻尼主轴估计。
        st.calibFrequencySplitHatHz = (1 - p.calib.ekfBlend) * st.calibFrequencySplitHatHz + p.calib.ekfBlend * splitHz; % 慢速写入频率裂解估计。
        st.calibStiffnessAxisHat = local_wrap_pi((1 - p.calib.ekfBlend) * st.calibStiffnessAxisHat + p.calib.ekfBlend * stiffnessAxis); % 慢速写入刚度主轴估计。
    end % 结束物理机理参数EKF式在线更新。
    if p.calib.safetyUpdateEnable % 判断是否根据在线估计值刷新安全系数与模态匹配状态。
        requiredEnergy = (2 * p.res.meanDamping + abs(st.calibDampingAnisotropyHat)) * p.res.energyTarget; % 估算当前阻尼包络下的能量保持执行量需求。
        requiredQuad = 4 * pi * max(st.calibFrequencySplitHatHz, eps) * p.res.energyTarget; % 估算当前模态裂解包络下的正交抑制执行量需求。
        instantaneousSafety = min([p.ctrl.energyLimit / max(requiredEnergy, eps), p.ctrl.quadLimit / max(requiredQuad, eps), p.calib.safetyMax]); % 取能量与正交执行通道中较小裕量作为安全系数。
        instantaneousSafety = min(max(instantaneousSafety, p.calib.safetyMin), p.calib.safetyMax); % 对安全系数显示值限幅。
        st.calibSafetyFactor = (1 - p.calib.safetyBlend) * st.calibSafetyFactor + p.calib.safetyBlend * instantaneousSafety; % 低通更新安全系数。
        st.calibModeMatchFactor = 1 / (1 + st.calibFrequencySplitHatHz / max(p.calib.modeMatchTargetHz, eps)); % 根据频率裂解与目标裂解计算模态匹配因子。
    end % 结束在线安全系数更新。
    st.calibUpdateCount = st.calibUpdateCount + 1; % 累加成功到达在线参数更新拍的次数。
    st = local_update_calib_compensation_alpha(st, p); % 按更新次数和低通系数安全释放在线补偿权重。
end % 结束抽取更新判断。
if p.calib.ekfEnable % 判断是否把在线辨识结果用于后续谐波补偿。
    alphaCalib = local_calib_alpha(st, p); % 读取V4.3.1在线补偿释放权重。
    driftHatOnline = 0.5 * st.calibDampingAnisotropyHat * sin(4 * (st.thetaEstimate - st.calibDampingAxisHat)); % 根据在线阻尼不均匀估计计算驻波角漂移补偿。
    driftHatOnline = driftHatOnline + pi * st.calibFrequencySplitHatHz * cos(4 * (st.thetaEstimate - st.calibStiffnessAxisHat)) * inv.Q / max(inv.E, eps); % 根据在线裂解估计计算频率裂解-正交耦合漂移补偿。
    harmonicCorrectionCandidate = driftHatOnline / p.res.bryan; % 将驻波角漂移补偿转换为输入角速度补偿量。
    harmonicLimit = p.calib.maxHarmonicCorrectionDps * pi / 180; % 把在线谐波补偿限幅从度每秒转换到弧度每秒。
    [harmonicCorrectionCandidate, ~] = local_clip(harmonicCorrectionCandidate, -harmonicLimit, harmonicLimit); % 限制EKF未完全收敛时可能产生的速率补偿尖峰。
    harmonicCorrection = (1 - alphaCalib) * harmonicCorrection + alphaCalib * harmonicCorrectionCandidate; % 只按安全释放权重把在线EKF补偿并入导航速率。
end % 结束在线物理补偿写入。
compensatedRate = rawRate + harmonicCorrection - temperatureBiasHat; % 重新合成采用在线标定结果后的补偿角速度。
st.calibPrevE = inv.E; % 保存当前E用于下一次慢变量差分。
st.calibPrevQ = inv.Q; % 保存当前Q用于下一次慢变量差分。
st.calibPrevTheta = st.thetaEstimate; % 保存当前驻波角用于下一次参数辨识。
st.calibPrevAct = st.previousActuatorOutput(1:2); % 保存最近实际执行量用于下一次驱动矩阵辨识。
end % 结束V4.3在线标定总调度函数。

function alphaCalib = local_calib_alpha(st, p) % 读取并限幅在线补偿释放权重。
if isfield(st, 'calibCompensationAlpha') % 判断状态结构是否已经包含V4.3.1补偿释放权重。
    alphaCalib = st.calibCompensationAlpha; % 读取当前补偿释放权重。
else % 兼容旧状态结构。
    alphaCalib = 0; % 旧状态默认不释放在线补偿。
end % 结束状态字段兼容判断。
alphaCalib = min(max(alphaCalib, 0), p.calib.maxCompensationAlpha); % 限制补偿权重在零到配置最大值之间。
end % 结束在线补偿权重读取函数。

function st = local_update_calib_compensation_alpha(st, p) % 根据在线标定更新次数缓慢释放补偿权重。
if st.calibUpdateCount < p.calib.compensationStartUpdates % 判断是否仍处于只辨识不补偿阶段。
    targetAlpha = 0; % 未满足启动更新次数前保持旁路补偿。
else % 进入安全释放阶段。
    rampProgress = (st.calibUpdateCount - p.calib.compensationStartUpdates) / max(p.calib.compensationRampUpdates, 1); % 根据更新次数计算释放进度。
    targetAlpha = p.calib.maxCompensationAlpha * min(max(rampProgress, 0), 1); % 计算目标补偿权重并限制在最大允许值内。
end % 结束释放阶段判断。
st.calibCompensationAlpha = (1 - p.calib.compensationBlend) * st.calibCompensationAlpha + p.calib.compensationBlend * targetAlpha; % 低通更新补偿权重，避免矩阵补偿突变。
st.calibCompensationAlpha = min(max(st.calibCompensationAlpha, 0), p.calib.maxCompensationAlpha); % 对更新后的补偿权重做最终限幅。
end % 结束在线补偿权重释放函数。

function [theta, covariance] = local_rls_vector_update(theta, covariance, phi, y, lambda) % 对多输出线性观测执行递推最小二乘更新。
for row = 1:size(phi, 1) % 按观测行逐条执行标量RLS，便于ASIC串行化。
    h = phi(row, :).'; % 读取当前观测行回归向量。
    if norm(h) <= eps || ~isfinite(y(row)) % 判断当前观测是否缺少有效激励。
        continue; % 跳过无效观测。
    end % 结束有效激励判断。
    gainDenominator = lambda + h.' * covariance * h; % 计算RLS增益分母。
    gain = covariance * h / max(gainDenominator, eps); % 计算RLS增益向量。
    innovation = y(row) - h.' * theta; % 计算当前观测创新。
    theta = theta + gain * innovation; % 更新参数向量。
    covariance = (covariance - gain * h.' * covariance) / lambda; % 更新协方差阵并施加遗忘因子。
    covariance = 0.5 * (covariance + covariance.'); % 显式对称化以抑制数值舍入误差。
end % 结束逐观测RLS更新。
end % 结束RLS向量更新函数。

function [state, covariance] = local_kf_parameter_update(state, covariance, H, z, qNoise, rNoise) % 执行物理参数EKF式线性化更新。
covariance = covariance + qNoise * eye(size(covariance)); % 先加入小过程噪声以允许慢漂辨识。
innovation = z - H * state; % 计算观测创新。
innovationCovariance = H * covariance * H.' + rNoise * eye(size(H, 1)); % 计算创新协方差。
gain = covariance * H.' / innovationCovariance; % 计算Kalman参数增益。
state = state + gain * innovation; % 更新参数状态。
identityMatrix = eye(size(covariance)); % 构造单位矩阵。
covariance = (identityMatrix - gain * H) * covariance * (identityMatrix - gain * H).' + gain * (rNoise * eye(size(H, 1))) * gain.'; % 使用Joseph形式更新协方差。
covariance = 0.5 * (covariance + covariance.'); % 对协方差执行显式对称化。
end % 结束EKF式物理参数更新函数。

function matrixOut = local_bounded_matrix(matrixIn, limit) % 对在线矩阵估计施加相对单位矩阵的幅度限幅。
matrixOut = eye(2) + min(max(matrixIn - eye(2), -abs(limit)), abs(limit)); % 将所有元素限制在单位矩阵邻域内。
if ~all(isfinite(matrixOut(:))) || rcond(matrixOut) <= 1e-6 % 判断限幅后矩阵是否仍然异常。
    matrixOut = eye(2); % 异常时退回单位矩阵，保证在线标定不会破坏主闭环。
end % 结束矩阵健康检查。
end % 结束在线矩阵限幅函数。

function [st, updated] = local_kalman_step(st, angleMeasurement, measurementValid, p, Ts) % 执行驻波角与驻波角速度二状态离散Kalman预测和量测更新。
transition = [1 Ts; 0 1]; % 构造恒角速度状态转移矩阵。
accelerationSigma = p.kalman.accelerationNoiseDps2 * pi / 180; % 把角加速度过程噪声标准差转换为弧度每秒平方。
noiseInput = [0.5 * Ts ^ 2; Ts]; % 构造离散角加速度噪声到角度与角速度状态的输入矩阵。
processCovariance = accelerationSigma ^ 2 * (noiseInput * noiseInput.'); % 计算单拍离散过程噪声协方差矩阵。
predictedState = transition * st.kalmanState; % 执行Kalman状态时间预测。
predictedCovariance = transition * st.kalmanCovariance * transition.' + processCovariance; % 执行Kalman协方差时间预测。
measurementMatrix = [1 0]; % 构造仅测量连续驻波角的观测矩阵。
measurementVariance = (p.kalman.measurementNoiseDeg * pi / 180) ^ 2; % 把驻波角测量噪声标准差转换为观测方差。
innovation = angleMeasurement - measurementMatrix * predictedState; % 计算连续驻波角测量创新。
st.kalmanInnovation = innovation; % 保存Kalman创新供日志与越界诊断。
innovationAllowed = abs(innovation) <= p.kalman.maxInnovationDeg * pi / 180; % 检查创新是否处于配置的物理可信范围。
updated = measurementValid && innovationAllowed; % 仅在相位有效且创新未越界时允许量测更新。
if updated % 判断本拍是否执行Kalman量测更新。
    innovationVariance = measurementMatrix * predictedCovariance * measurementMatrix.' + measurementVariance; % 计算创新方差。
    kalmanGain = predictedCovariance * measurementMatrix.' / max(innovationVariance, eps); % 计算二状态Kalman增益。
    st.kalmanState = predictedState + kalmanGain * innovation; % 使用连续驻波角创新修正预测状态。
    identityMatrix = eye(2); % 构造Joseph协方差更新需要的二阶单位矩阵。
    covarianceFactor = identityMatrix - kalmanGain * measurementMatrix; % 构造Joseph形式左侧协方差因子。
    st.kalmanCovariance = covarianceFactor * predictedCovariance * covarianceFactor.' + kalmanGain * measurementVariance * kalmanGain.'; % 使用Joseph形式更新协方差以保持半正定性。
    st.kalmanUpdateCount = st.kalmanUpdateCount + 1; % 累加Kalman有效测量更新次数。
else % 处理测量无效或创新越界的情况。
    st.kalmanState = predictedState; % 仅保留恒角速度模型的状态预测。
    st.kalmanCovariance = predictedCovariance; % 仅保留协方差时间预测。
    if measurementValid && ~innovationAllowed % 判断是否属于测量存在但创新超限。
        st.kalmanRejectCount = st.kalmanRejectCount + 1; % 累加Kalman创新超限拒绝次数。
    end % 结束Kalman创新拒绝计数判断。
end % 结束Kalman预测或更新分支。
st.kalmanCovariance = 0.5 * (st.kalmanCovariance + st.kalmanCovariance.'); % 对协方差矩阵执行显式对称化以抑制浮点舍入误差。
st.kalmanCovariance(1, 1) = max(st.kalmanCovariance(1, 1), p.kalman.covarianceFloor); % 限制角度方差不低于数值稳定下限。
st.kalmanCovariance(2, 2) = max(st.kalmanCovariance(2, 2), p.kalman.covarianceFloor); % 限制角速度方差不低于数值稳定下限。
end % 结束二状态Kalman估计函数。

function [output, integrator, integratorSaturated, outputSaturated, antiWindupActive] = local_pi_aw(errorSignal, integrator, kp, ki, integratorLimit, outputLimit, backCalculationGain, antiWindupEnable, Ts) % 执行条件积分、反算、积分限幅和输出限幅完整PI抗饱和算法。
candidateIntegrator = integrator + errorSignal * Ts; % 先按常规离散积分生成候选积分器状态。
[candidateIntegrator, firstIntegratorSaturation] = local_clip(candidateIntegrator, -abs(integratorLimit), abs(integratorLimit)); % 对候选积分器施加物理状态限幅。
unsaturatedOutput = kp * errorSignal + ki * candidateIntegrator; % 计算尚未执行输出限幅的候选PI控制量。
[saturatedOutput, firstOutputSaturation] = local_clip(unsaturatedOutput, -abs(outputLimit), abs(outputLimit)); % 对候选PI控制量施加执行范围限幅。
drivesPositiveSaturation = unsaturatedOutput > abs(outputLimit) && errorSignal > 0; % 判断当前误差是否会把正向饱和进一步推深。
drivesNegativeSaturation = unsaturatedOutput < -abs(outputLimit) && errorSignal < 0; % 判断当前误差是否会把负向饱和进一步推深。
conditionalHold = antiWindupEnable && (drivesPositiveSaturation || drivesNegativeSaturation); % 形成饱和方向条件积分冻结标志。
if conditionalHold % 判断是否应撤销本拍常规误差积分。
    candidateIntegrator = integrator; % 撤销会加深输出饱和的误差积分增量。
    unsaturatedOutput = kp * errorSignal + ki * candidateIntegrator; % 使用冻结后的积分器重新计算未限幅输出。
    [saturatedOutput, firstOutputSaturation] = local_clip(unsaturatedOutput, -abs(outputLimit), abs(outputLimit)); % 重新计算冻结后的输出饱和状态。
end % 结束条件积分冻结处理。
backCalculationActive = antiWindupEnable && firstOutputSaturation && abs(ki) > eps; % 判断输出饱和时是否允许执行反算泄放。
if backCalculationActive % 判断是否执行输出饱和误差反算。
    candidateIntegrator = candidateIntegrator + backCalculationGain * (saturatedOutput - unsaturatedOutput) / ki * Ts; % 把执行器无法实现的输出差值反算到积分器状态。
end % 结束反算抗饱和处理。
[integrator, secondIntegratorSaturation] = local_clip(candidateIntegrator, -abs(integratorLimit), abs(integratorLimit)); % 对条件积分与反算后的积分器执行最终限幅。
unsaturatedOutput = kp * errorSignal + ki * integrator; % 使用最终积分器重新计算PI控制量。
[output, outputSaturated] = local_clip(unsaturatedOutput, -abs(outputLimit), abs(outputLimit)); % 对最终PI控制量执行输出限幅。
integratorSaturated = firstIntegratorSaturation || secondIntegratorSaturation; % 汇总候选与最终积分器限幅事件。
antiWindupActive = conditionalHold || backCalculationActive; % 汇总条件积分冻结与反算抗饱和动作状态。
end % 结束完整PI抗饱和算法函数。

function [limitedOutput, slewActive] = local_slew_limit(targetOutput, previousOutput, maximumRatePerSecond, Ts) % 执行控制字对称变化率限制。
maximumDelta = abs(maximumRatePerSecond) * Ts; % 计算当前控制周期允许的最大控制字增量。
requestedDelta = targetOutput - previousOutput; % 计算目标控制字相对上一拍的请求增量。
[limitedDelta, slewActive] = local_clip(requestedDelta, -maximumDelta, maximumDelta); % 对请求增量施加对称斜率限制。
limitedOutput = previousOutput + limitedDelta; % 由上一拍控制字与受限增量形成当前实际数字控制字。
end % 结束控制字变化率限制函数。

function [integrator, integratorSaturated, trackingActive] = local_tracking_aw(integrator, realizedOutput, requestedOutput, ki, trackingGain, integratorLimit, Ts) % 把后级实际实现量与请求量之差反算回PI积分器。
trackingError = realizedOutput - requestedOutput; % 计算流水线对齐的后级实际实现量相对请求量的误差。
numericThreshold = 8 * eps(max([abs(realizedOutput), abs(requestedOutput), 1])); % 计算避免把纯浮点舍入误差计为抗饱和动作的数值门限。
trackingActive = abs(trackingError) > numericThreshold && abs(ki) > eps && trackingGain > 0; % 仅在后级实现误差可观测且积分通道有效时允许跟踪反算。
if trackingActive % 判断是否执行本拍后级约束跟踪反算。
    integrator = integrator + trackingGain * trackingError / ki * Ts; % 把后级无法实现的输出差值按跟踪增益反算到积分器状态。
end % 结束后级约束跟踪反算判断。
[integrator, integratorSaturated] = local_clip(integrator, -abs(integratorLimit), abs(integratorLimit)); % 对跟踪反算后的积分器执行最终物理限幅。
end % 结束后级执行约束跟踪反算函数。

function command = local_energy_hold_command(inv, st, p) % 按HRG能量慢变量稳态方程估算RUN入口能量保持驱动。
energyForHold = p.res.energyTarget; % 使用目标能量而不是捕获瞬时能量作为稳态保持驱动的设计点。
dampingProjection = p.comp.dampingAnisotropyHat * cos(4 * (st.thetaEstimate - p.comp.dampingAxisHat)); % 估算阻尼不均匀在当前驻波方位上的能量衰减投影。
command = (2 * p.res.meanDamping + dampingProjection) * energyForHold; % 由energyDot=0反推抵消平均阻尼和阻尼不均匀所需的能量驱动。
if ~isfinite(command) % 判断前馈估计是否因异常状态出现非有限数。
    command = 0; % 异常时退回零前馈以交给PI比例项重新捕获。
end % 结束非有限能量前馈保护。
end % 结束RUN入口能量保持驱动估计函数。

function command = local_quad_hold_command(inv, st, p) % 按HRG正交慢变量稳态方程估算RUN入口正交保持驱动。
energyForHold = min(max(inv.E, p.res.energyTarget * (1 - p.ctrl.energyLockTolerance)), p.res.energyTarget * (1 + p.ctrl.energyLockTolerance)); % 将当前能量限制在锁定窗口内用于正交裂解前馈估计。
splitRad = 2 * pi * p.comp.frequencySplitHatHz; % 把补偿器估计的模态频率裂解从赫兹转换为弧度每秒。
command = 2 * splitRad * energyForHold * sin(4 * (st.thetaEstimate - p.comp.stiffnessAxisHat)); % 由quadDot=0反推抵消频率裂解激励所需的正交驱动。
if ~isfinite(command) % 判断正交前馈估计是否因异常状态出现非有限数。
    command = 0; % 异常时退回零前馈以交给Q环比例项重新捕获。
end % 结束非有限正交前馈保护。
end % 结束RUN入口正交保持驱动估计函数。

function [act, st, diag] = local_dac_driver(cmd, st, p) % 模拟控制流水线、DAC量化、驱动增益和饱和。
if p.calib.enable && p.calib.driveCorrectionEnable % 判断是否启用V4.3驱动矩阵在线预补偿。
    alphaCalib = local_calib_alpha(st, p); % 读取V4.3.1在线补偿安全释放权重。
    driveMatrix = eye(2) + alphaCalib * (st.calibDriveMatrixHat - eye(2)); % 采用单位阵到估计矩阵的加权释放，避免驱动RLS未收敛时改变主控制通道。
    if alphaCalib > 0 && all(isfinite(driveMatrix(:))) && rcond(driveMatrix) > 1e-6 % 检查矩阵是否可安全求逆且补偿权重已释放。
        correctedCommand = driveMatrix \ cmd(1:2); % 用估计驱动矩阵的逆矩阵预补偿能量与正交命令。
        [correctedCommand(1), ~] = local_clip(correctedCommand(1), -p.ctrl.energyLimit, p.ctrl.energyLimit); % 对预补偿后的能量命令施加数字控制限幅。
        [correctedCommand(2), ~] = local_clip(correctedCommand(2), -p.ctrl.quadLimit, p.ctrl.quadLimit); % 对预补偿后的正交命令施加数字控制限幅。
        cmd(1:2) = correctedCommand; % 写回两路预补偿命令。
    end % 结束驱动矩阵可逆性检查。
end % 结束驱动矩阵预补偿。
st.controlDelay = [cmd, st.controlDelay(:, 1:end - 1)]; % 将本拍控制字推入ASIC到DAC的流水线。
delayed = st.controlDelay(:, end); % 读取到达流水线末端的控制字。
if p.fault.enable && strcmpi(p.fault.type, 'dac_clip') % 判断是否配置DAC满量程故障。
    effectiveFullScale = max(p.dac.fullScale * p.fault.magnitude, eps); % 按故障幅值缩小三路DAC有效满量程。
else % 处理标称DAC满量程情况。
    effectiveFullScale = p.dac.fullScale; % 使用配置的标称DAC满量程。
end % 结束DAC满量程故障判断。
quantized = zeros(3, 1); % 初始化三路DAC量化输出。
saturated = false; % 初始化DAC饱和标志。
for i = 1:3 % 遍历三路DAC或等效数模执行接口。
    lsb = 2 * effectiveFullScale(i) / 2 ^ p.dac.bits; % 计算当前通道的DAC量化步长。
    [limited, sat] = local_clip(delayed(i), -effectiveFullScale(i), effectiveFullScale(i) - lsb); % 将控制字限制在当前通道的可表示范围内。
    quantized(i) = round(limited / lsb) * lsb; % 将控制字舍入到最近的DAC码。
    saturated = saturated || sat; % 合并三路DAC饱和状态。
end % 结束三路DAC量化循环。
act = p.dac.gain .* quantized + p.dac.offset + p.dac.noiseSigma .* randn(3, 1); % 加入驱动通道增益、偏置和输出噪声。
[act, satDriver] = local_clip(act, -p.dac.fullScale, p.dac.fullScale); % 对驱动级实际输出再次执行物理满量程限制。
st.previousDeliveredCommand = delayed; % 保存与当前实际输出时序对齐的DAC输入端控制字供下一拍完整抗饱和跟踪。
st.previousActuatorOutput = act; % 保存当前DAC与驱动实际输出供下一拍执行器误差反算。
diag.saturated = saturated || satDriver; % 输出DAC与驱动级综合饱和标志。
st.previousActuatorSaturated = diag.saturated; % 保存当前DAC与驱动级饱和状态供下一拍完整抗饱和跟踪。
end % 结束DAC与驱动行为模型函数。

function x = local_plant_step(tk, x, act, inputRate, temperature, p, Ts) % 以慢变量平均方程推进HRG谐振子状态。
driveVector = p.drive.crossMatrix * act(1:2); % 通过真实能量/正交驱动矩阵施加执行通道增益与交叉耦合。
energyDrive = driveVector(1); % 读取矩阵耦合后的能量执行通道实际作用量。
quadDrive = driveVector(2); % 读取矩阵耦合后的正交执行通道实际作用量。
virtualRate = act(3); % 读取虚拟进动执行通道实际作用量。
deltaT = temperature - p.env.referenceTemperature; % 计算环境温差。
rateBias = p.env.rateBiasAtRef + p.env.rateBiasTemp1 * deltaT + p.env.rateBiasTemp2 * deltaT ^ 2; % 计算温度相关的等效输入角速度零偏。
splitRad = 2 * pi * p.res.frequencySplitHz; % 将频率裂解从赫兹转换为弧度每秒。
energyDot = -2 * p.res.meanDamping * x.energy - p.res.dampingAnisotropy * cos(4 * (x.theta - p.res.dampingAxis)) * x.energy + energyDrive; % 计算含平均阻尼和阻尼不均匀的能量导数。
energyDot = energyDot + p.res.processEnergyNoise * randn; % 向能量慢变量加入过程噪声。
quadDot = -2 * p.res.meanDamping * x.quad - 2 * splitRad * x.energy * sin(4 * (x.theta - p.res.stiffnessAxis)) + quadDrive; % 计算频率裂解激励和正交控制共同作用的Q导数。
quadDot = quadDot + p.res.processQuadNoise * randn; % 向正交慢变量加入过程噪声。
thetaDrift = 0.5 * p.res.dampingAnisotropy * sin(4 * (x.theta - p.res.dampingAxis)); % 计算阻尼不均匀导致的驻波角相关漂移。
thetaDrift = thetaDrift + 0.5 * splitRad * cos(4 * (x.theta - p.res.stiffnessAxis)) * x.quad / max(x.energy, eps); % 加入频率裂解与残余正交量耦合产生的漂移。
thetaDot = -p.res.bryan * (inputRate + rateBias) + virtualRate + thetaDrift + p.res.processThetaNoise * randn; % 根据Bryan进动关系计算驻波角导数。
x.energy = max(x.energy + Ts * energyDot, 1e-8); % 采用前向欧拉法更新能量并保证其为正。
x.quad = x.quad + Ts * quadDot; % 采用前向欧拉法更新正交慢变量。
x.theta = x.theta + Ts * thetaDot; % 采用前向欧拉法更新连续驻波角。
x.thetaVirtual = x.thetaVirtual + Ts * virtualRate; % 积分虚拟进动速率供诊断与理论角度核对。
end % 结束HRG慢变量状态更新函数。

function log = local_log_sample(log, k, x, inv, demod, nav, cmd, act, st, temperature, inputRate) % 记录单个控制周期的状态、接口与诊断量。
log.energy(k) = x.energy; % 记录真实能量慢变量。
log.quad(k) = x.quad; % 记录真实正交慢变量。
log.thetaTrue(k) = x.theta; % 记录真实连续驻波角。
log.thetaEstimate(k) = nav.theta; % 记录数字ASIC连续驻波角估计。
log.Cx(k) = demod.Cx; % 记录X通道同相解调量。
log.Sx(k) = demod.Sx; % 记录X通道正交解调量。
log.Cy(k) = demod.Cy; % 记录Y通道同相解调量。
log.Sy(k) = demod.Sy; % 记录Y通道正交解调量。
log.E(k) = inv.E; % 记录数字解调能量不变量。
log.Q(k) = inv.Q; % 记录数字解调正交不变量。
log.R(k) = inv.R; % 记录数字解调余弦方位不变量。
log.S(k) = inv.S; % 记录数字解调正弦方位不变量。
log.L(k) = inv.L; % 记录数字频率相位误差信号。
log.phaseError(k) = nav.phaseError; % 记录归一化频率相位误差。
log.ncoFrequencyHz(k) = st.ncoFrequencyHz; % 记录NCO频率控制字。
log.pllIntegrator(k) = st.pllIntegratorHz; % 记录DPLL积分器内部状态。
log.energyIntegrator(k) = st.energyIntegrator; % 记录能量PI积分器内部状态。
log.quadIntegrator(k) = st.quadIntegrator; % 记录正交PI积分器内部状态。
log.angleOutput(k) = nav.angle; % 记录导航角度输出。
log.rateOutput(k) = nav.rate; % 记录导航角速度输出。
log.rawRate(k) = nav.rawRate; % 记录补偿前的Bryan解算角速度。
log.compensatedRate(k) = nav.compensatedRate; % 记录未经过显示低通的补偿角速度。
log.inputRate(k) = inputRate; % 记录外部真实角速度输入。
log.energyCmd(k) = cmd(1); % 记录能量数字控制字。
log.quadCmd(k) = cmd(2); % 记录正交数字控制字。
log.virtualCmd(k) = cmd(3); % 记录虚拟进动数字控制字。
log.energyAct(k) = act(1); % 记录能量执行通道实际输出。
log.quadAct(k) = act(2); % 记录正交执行通道实际输出。
log.virtualAct(k) = act(3); % 记录虚拟进动执行通道实际输出。
log.temperature(k) = temperature; % 记录当前温度。
log.mode(k) = double(st.mode); % 记录状态机编码。
log.locked(k) = st.locked; % 记录闭环锁定标志。
log.statusWord(k) = double(nav.statusWord); % 记录32位状态字的数值形式。
log.measurementInvalidReason(k) = double(nav.measurementInvalidReason); % 记录本拍测量无效原因位图。
log.adcSatCount(k) = st.adcSaturationCount; % 记录累计ADC饱和次数。
log.dacSatCount(k) = st.dacSaturationCount; % 记录累计DAC饱和次数。
log.fixedOverflowCount(k) = st.fixedOverflowCount; % 记录累计真实定点数据通路溢出次数。
log.pllLimitCount(k) = st.pllLimitCount; % 记录累计DPLL限幅次数。
log.pllFreezeCount(k) = st.pllFreezeCount; % 记录累计DPLL有效性冻结控制拍数。
log.antiWindupCount(k) = st.antiWindupCount; % 记录累计DPLL与双PI抗饱和动作次数。
log.piIntegratorLimitCount(k) = st.piIntegratorLimitCount; % 记录累计PI积分器限幅次数。
log.controlOutputLimitCount(k) = st.controlOutputLimitCount; % 记录累计控制输出限幅次数。
log.controlSlewLimitCount(k) = st.controlSlewLimitCount; % 记录累计控制字斜率限制动作次数。
log.actuatorTrackingCount(k) = st.actuatorTrackingCount; % 记录累计执行器实际输出与斜率限制跟踪反算动作次数。
log.unwrapFaultCount(k) = st.unwrapFaultCount; % 记录累计四倍角展开异常次数。
log.kalmanAngle(k) = st.kalmanState(1); % 记录Kalman估计的连续驻波角。
log.kalmanThetaRate(k) = st.kalmanState(2); % 记录Kalman估计的驻波角速度。
log.kalmanInnovation(k) = st.kalmanInnovation; % 记录Kalman驻波角测量创新。
log.kalmanP11(k) = st.kalmanCovariance(1, 1); % 记录Kalman驻波角估计方差。
log.kalmanP22(k) = st.kalmanCovariance(2, 2); % 记录Kalman驻波角速度估计方差。
log.kalmanUpdateCount(k) = st.kalmanUpdateCount; % 记录累计Kalman有效测量更新次数。
log.kalmanRejectCount(k) = st.kalmanRejectCount; % 记录累计Kalman创新拒绝次数。
log.calibUpdateCount(k) = st.calibUpdateCount; % 记录累计在线标定参数更新次数。
log.calibDet11(k) = st.calibDetectionMatrixHat(1, 1); % 记录检测矩阵估计m11。
log.calibDet12(k) = st.calibDetectionMatrixHat(1, 2); % 记录检测矩阵估计m12。
log.calibDet21(k) = st.calibDetectionMatrixHat(2, 1); % 记录检测矩阵估计m21。
log.calibDet22(k) = st.calibDetectionMatrixHat(2, 2); % 记录检测矩阵估计m22。
log.calibDrv11(k) = st.calibDriveMatrixHat(1, 1); % 记录驱动矩阵估计d11。
log.calibDrv12(k) = st.calibDriveMatrixHat(1, 2); % 记录驱动矩阵估计d12。
log.calibDrv21(k) = st.calibDriveMatrixHat(2, 1); % 记录驱动矩阵估计d21。
log.calibDrv22(k) = st.calibDriveMatrixHat(2, 2); % 记录驱动矩阵估计d22。
log.calibDampingAnisotropy(k) = st.calibDampingAnisotropyHat; % 记录在线阻尼不均匀幅值估计。
log.calibDampingAxis(k) = st.calibDampingAxisHat; % 记录在线阻尼主轴估计。
log.calibFrequencySplitHz(k) = st.calibFrequencySplitHatHz; % 记录在线模态频率裂解估计。
log.calibStiffnessAxis(k) = st.calibStiffnessAxisHat; % 记录在线刚度主轴估计。
log.calibSafetyFactor(k) = st.calibSafetyFactor; % 记录在线执行器安全系数。
log.calibModeMatchFactor(k) = st.calibModeMatchFactor; % 记录在线模态匹配因子。
log.calibCompensationAlpha(k) = st.calibCompensationAlpha; % 记录V4.3.1在线补偿释放权重。
log.calibSyncEnergyGain(k) = st.calibSyncEnergyGain; % 记录能量通道正弦同步响应幅值。
log.calibSyncQuadGain(k) = st.calibSyncQuadGain; % 记录正交通道正弦同步响应幅值。
log.calibActive(k) = isfield(nav, 'calibActive') && nav.calibActive; % 记录V4.3在线标定活动标志。
log.selftestGainEstimate(k) = st.selftestGainEstimate; % 记录SELFTEST检测链路归一化增益估计值。
log.selftestQuadratureRatio(k) = st.selftestQuadratureRatio; % 记录SELFTEST正交残差比例估计值。
log.selftestSampleCount(k) = st.selftestSampleCount; % 记录SELFTEST同步相关累计样本数。
log.phaseValid(k) = nav.phaseValid; % 记录本拍相位与能量联合有效标志。
log.pllFrozen(k) = nav.pllFrozen; % 记录本拍DPLL有效性冻结标志。
log.antiWindupActive(k) = nav.antiWindupActive; % 记录本拍任一控制环抗饱和动作标志。
log.kalmanUpdated(k) = nav.kalmanUpdated; % 记录本拍Kalman是否采用测量更新。
log.selftestActive(k) = nav.selftestActive; % 记录本拍前端是否真实叠加SELFTEST载波而不依赖拍末状态机编码。
log.selftestDone(k) = st.selftestDone; % 记录SELFTEST完成锁存标志。
log.selftestPassed(k) = st.selftestPassed; % 记录SELFTEST通过锁存标志。
log.selftestFailed(k) = st.selftestFailed; % 记录SELFTEST失败锁存标志。
end % 结束单拍日志记录函数。

function [y, saturated] = local_fixed(x, wordLength, fractionLength) % 执行有符号二进制定点舍入与饱和。
step = 2 ^ (-fractionLength); % 计算定点格式的最小量化步长。
minimum = -2 ^ (wordLength - fractionLength - 1); % 计算有符号定点数的最小可表示值。
maximum = 2 ^ (wordLength - fractionLength - 1) - step; % 计算有符号定点数的最大可表示值。
rounded = round(x / step) * step; % 将输入舍入到最近的定点量化格点。
[y, saturated] = local_clip(rounded, minimum, maximum); % 对舍入结果执行定点范围饱和。
end % 结束定点量化函数。

function [y, saturated] = local_clip(x, lower, upper) % 将标量或向量限制在给定上下界内。
y = min(max(x, lower), upper); % 执行逐元素上下界限制。
saturated = any(x(:) < lower(:)) || any(x(:) > upper(:)); % 判断任一元素是否发生限幅。
end % 结束通用限幅函数。

function y = local_wrap_pi(x) % 将任意相位包裹到负pi至正pi区间。
y = mod(x + pi, 2 * pi) - pi; % 利用模运算完成对称相位包裹。
end % 结束对称相位包裹函数。

function y = local_wrap_2pi(x) % 将任意相位包裹到零至二pi区间。
y = mod(x, 2 * pi); % 利用模运算完成非负相位包裹。
end % 结束非负相位包裹函数。
