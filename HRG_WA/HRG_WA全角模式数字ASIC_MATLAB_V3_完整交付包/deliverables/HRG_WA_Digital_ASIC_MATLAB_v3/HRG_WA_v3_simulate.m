function result = HRG_WA_v3_simulate(p) % 运行半球谐振陀螺全角模式与数字ASIC的多速率闭环行为仿真。
if nargin < 1 || isempty(p) % 判断调用者是否提供参数结构体。
    p = HRG_WA_v3_params(); % 未提供参数时加载标称参数。
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
st.thetaEstimate = p.res.thetaInitial; % 初始化连续驻波角估计。
st.thetaPrevious = p.res.thetaInitial; % 初始化上一拍驻波角估计。
st.phiPrevious = local_wrap_pi(4 * p.res.thetaInitial); % 初始化四倍角上一拍相位。
st.angleOutput = 0; % 初始化导航角度输出。
st.rateOutput = 0; % 初始化导航角速度输出。
st.afeState = [0; 0]; % 初始化两路模拟前端低通状态。
st.controlDelay = zeros(3, p.asic.pipelineDelayCtrl + 1); % 初始化三路控制命令流水线。
st.adcSaturationCount = 0; % 初始化ADC饱和计数器。
st.dacSaturationCount = 0; % 初始化DAC饱和计数器。
st.fixedSaturationCount = 0; % 初始化定点饱和计数器。
st.unwrapFaultCount = 0; % 初始化四倍角展开异常计数器。
st.consecutiveFaultCount = 0; % 初始化连续故障拍数计数器。
st.faultLatched = false; % 初始化故障锁存标志。
log = local_allocate_log(count, t); % 预分配全部仿真日志，避免循环中动态扩容。
for k = 1:count % 逐个执行控制周期的闭环仿真。
    tk = t(k); % 读取当前控制周期的时间。
    temperature = p.env.temperatureFcn(tk); % 计算当前环境温度。
    inputRate = p.input.rateFcn(tk); % 计算当前外部角速度输入。
    [demod, st, x, adcDiag] = local_frontend_block(tk, x, st, p, samplesPerCtrl, TsAdc, temperature); % 生成原始载波并完成AFE、ADC、NCO和正交解调。
    [inv, fixedSat] = local_invariants(demod, p); % 由四路正交分量计算E、Q、R、S和相位误差信号L。
    st.fixedSaturationCount = st.fixedSaturationCount + double(fixedSat); % 累加不变量定点饱和次数。
    [cmd, nav, st] = local_asic_control(tk, inv, st, p, temperature); % 执行DPLL、能量环、正交环、角度解算和状态机。
    [act, st, dacDiag] = local_dac_driver(cmd, st, p); % 执行控制字流水线、DAC量化和驱动非理想模型。
    st.adcSaturationCount = st.adcSaturationCount + double(adcDiag.saturated); % 累加ADC或AFE饱和次数。
    st.dacSaturationCount = st.dacSaturationCount + double(dacDiag.saturated); % 累加DAC或驱动饱和次数。
    log = local_log_sample(log, k, x, inv, demod, nav, cmd, act, st, temperature, inputRate); % 将当前拍的关键中间量写入预分配日志。
    if k < count % 判断当前拍之后是否还需要更新机械慢变量。
        x = local_plant_step(tk, x, act, inputRate, temperature, p, TsCtrl); % 以执行器实际输出推进谐振子慢变量。
    end % 结束机械状态更新判断。
end % 结束控制周期主循环。
log.inputAngle = cumtrapz(log.t, log.inputRate); % 对输入角速度积分得到参考输入角度。
metrics = HRG_WA_v3_metrics(log, p); % 计算闭环性能、饱和和故障指标。
result.log = log; % 把完整日志写入结果结构体。
result.metrics = metrics; % 把性能指标写入结果结构体。
result.params = p; % 把本次实际参数写入结果结构体以便复现。
result.regmap = HRG_WA_v3_regmap(p); % 把建议寄存器表写入结果结构体。
end % 结束多速率闭环仿真主函数。

function log = local_allocate_log(count, t) % 预分配控制域日志结构体。
log.t = t; % 保存控制域时间向量。
names = {'energy','quad','thetaTrue','thetaEstimate','Cx','Sx','Cy','Sy','E','Q','R','S','L','phaseError','ncoFrequencyHz','angleOutput','rateOutput','inputRate','inputAngle','energyCmd','quadCmd','virtualCmd','energyAct','quadAct','virtualAct','temperature','mode','statusWord','adcSatCount','dacSatCount','fixedSatCount','unwrapFaultCount'}; % 定义需要预分配的数值字段名称。
for i = 1:numel(names) % 遍历全部数值日志字段。
    log.(names{i}) = zeros(count, 1); % 为当前字段分配列向量。
end % 结束日志字段预分配循环。
log.locked = false(count, 1); % 单独预分配逻辑型锁定标志。
end % 结束日志预分配函数。

function [demod, st, x, diag] = local_frontend_block(t0, x, st, p, samplesPerCtrl, TsAdc, temperature) % 生成一个控制周期的原始载波并完成数字正交解调。
sumCx = 0; % 初始化X通道同相累加器。
sumSx = 0; % 初始化X通道正交累加器。
sumCy = 0; % 初始化Y通道同相累加器。
sumSy = 0; % 初始化Y通道正交累加器。
saturated = false; % 初始化本控制周期的AFE或ADC饱和标志。
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
    if p.afe.enable % 判断是否启用AFE非理想模型。
        analog = p.afe.crossMatrix * analog + p.afe.offset; % 加入通道增益、串扰和直流偏置。
        st.afeState = alphaAfe * st.afeState + (1 - alphaAfe) * analog; % 通过一阶低通模拟AFE有限带宽。
        analog = st.afeState + p.afe.noiseSigma .* randn(2, 1); % 加入AFE等效输入白噪声。
    end % 结束AFE非理想模型判断。
    if p.fault.enable && tn >= p.fault.time && strcmpi(p.fault.type, 'afe_offset') % 判断是否到达AFE偏置故障注入时刻。
        analog = analog + p.fault.magnitude * [1; -1]; % 向两检测通道注入反向偏置故障。
    end % 结束AFE偏置故障注入判断。
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
    st.fixedSaturationCount = st.fixedSaturationCount + double(sat1 || sat2 || sat3 || sat4); % 统计解调数据路径的定点饱和。
end % 结束解调定点量化判断。
diag.saturated = saturated; % 输出本控制周期的模拟与ADC饱和诊断。
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

function [cmd, nav, st] = local_asic_control(tk, inv, st, p, temperature) % 执行数字ASIC的DPLL、控制环、全角解算、补偿和状态管理。
Ts = p.sim.TsCtrl; % 读取数字控制周期。
phaseDenominator = max(inv.E, p.asic.phaseValidThreshold); % 构造归一化相位误差的安全分母。
phaseError = -inv.L / phaseDenominator; % 按相位鉴别器极性得到归一化频率相位误差。
st.pllIntegratorHz = st.pllIntegratorHz + phaseError * Ts; % 对相位误差进行离散积分。
[st.pllIntegratorHz, pllIntSat] = local_clip(st.pllIntegratorHz, -p.pll.integratorLimitHz / max(p.pll.kiHz, eps), p.pll.integratorLimitHz / max(p.pll.kiHz, eps)); % 限制锁相环积分器防止失锁时累积过大。
frequencyCorrection = p.pll.kpHz * phaseError + p.pll.kiHz * st.pllIntegratorHz; % 计算NCO频率校正量。
[frequencyCorrection, pllOutSat] = local_clip(frequencyCorrection, -p.pll.frequencyLimitHz, p.pll.frequencyLimitHz); % 限制NCO频率校正范围。
st.ncoFrequencyHz = p.res.f0 + frequencyCorrection; % 更新下一个采样块使用的NCO频率控制字。
st.fixedSaturationCount = st.fixedSaturationCount + double(pllIntSat || pllOutSat); % 统计锁相环内部限幅事件。
phaseMagnitude = hypot(inv.R, inv.S); % 计算四倍角矢量幅值。
phaseValid = phaseMagnitude > p.asic.phaseValidThreshold; % 根据矢量幅值判断CORDIC输入是否有效。
phi = atan2(inv.S, inv.R); % 用反正切等效CORDIC得到范围为负pi到正pi的四倍角相位。
angleQuantum = 2 * pi / 2 ^ p.asic.angleBits; % 计算CORDIC相位输出的量化步长。
phi = round(phi / angleQuantum) * angleQuantum; % 对CORDIC相位结果施加有限位宽量化。
if phaseValid % 判断本拍相位是否可用于连续展开。
    deltaPhi = local_wrap_pi(phi - st.phiPrevious); % 计算相邻采样拍之间的最小四倍角相位增量。
    st.phiPrevious = phi; % 保存本拍四倍角相位供下一拍使用。
else % 处理驻波幅值不足导致的无效相位。
    deltaPhi = 0; % 无效相位期间冻结连续驻波角估计。
end % 结束相位有效性判断。
unwrapFault = abs(deltaPhi) > p.asic.unwrapLimit; % 检查四倍角相邻增量是否超过无歧义展开门限。
if unwrapFault % 判断是否发生四倍角展开异常。
    deltaPhi = 0; % 异常时冻结本拍角度，防止整周跳变污染导航输出。
    st.unwrapFaultCount = st.unwrapFaultCount + 1; % 累加展开异常次数。
end % 结束四倍角展开异常处理。
st.thetaPrevious = st.thetaEstimate; % 保存更新前的连续驻波角。
st.thetaEstimate = st.thetaEstimate + 0.25 * deltaPhi; % 将连续四倍角增量除以四得到物理驻波角。
thetaRate = (st.thetaEstimate - st.thetaPrevious) / Ts; % 对连续驻波角做一阶差分得到驻波角速度。
virtualRateCommand = 0; % 初始化零均值虚拟进动命令。
if p.virtual.enable % 判断是否启用周期虚拟进动。
    virtualRateCommand = p.virtual.amplitudeDps * pi / 180 * sin(2 * pi * p.virtual.frequencyHz * tk + p.virtual.phaseRad); % 生成零均值正弦虚拟进动速率。
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
compensatedRate = rawRate + harmonicCorrection - temperatureBiasHat; % 合成全角角速度输出的谐波与温度补偿。
rateAlpha = 1 - exp(-2 * pi * p.ctrl.rateLpfHz * Ts); % 计算角速度输出一阶低通系数。
st.rateOutput = st.rateOutput + rateAlpha * (compensatedRate - st.rateOutput); % 更新滤波后的导航角速度输出。
st.angleOutput = st.angleOutput + st.rateOutput * Ts; % 对补偿后角速度积分得到连续导航角度输出。
st.modeTime = st.modeTime + Ts; % 累加当前状态驻留时间。
if st.mode == 1 && st.modeTime >= p.ctrl.startupTime % 判断起振阶段是否达到最短时间。
    st.mode = uint8(2); % 从STARTUP切换到ACQUIRE。
    st.modeTime = 0; % 清零新状态驻留计时器。
end % 结束STARTUP状态转移判断。
energyLocked = abs(inv.E - p.res.energyTarget) <= p.ctrl.energyLockTolerance * p.res.energyTarget; % 判断能量是否进入锁定窗口。
quadLocked = abs(inv.Q) <= p.ctrl.quadLockTolerance; % 判断正交量是否进入锁定窗口。
phaseLocked = abs(phaseError) <= p.pll.lockPhaseError; % 判断频率相位误差是否进入锁定窗口。
if st.mode == 2 && st.modeTime >= p.ctrl.acquireTime && energyLocked && quadLocked && phaseLocked % 判断捕获阶段是否满足进入运行态的全部条件。
    st.mode = uint8(3); % 从ACQUIRE切换到RUN。
    st.modeTime = 0; % 清零RUN状态驻留计时器。
    st.locked = true; % 锁存闭环已锁定标志。
    st.angleOutput = 0; % 在进入RUN时清零导航角度参考。
    st.rateOutput = 0; % 在进入RUN时清零速率滤波残差。
end % 结束ACQUIRE到RUN的状态转移判断。
energyError = p.res.energyTarget - inv.E; % 计算能量控制误差。
quadError = -inv.Q; % 计算正交控制误差。
energyCommand = 0; % 初始化能量控制命令。
quadCommand = 0; % 初始化正交控制命令。
if st.mode == 1 % 判断当前是否处于开环起振阶段。
    energyCommand = p.ctrl.startupDrive; % 在STARTUP阶段施加固定开环能量驱动。
elseif st.mode == 2 || st.mode == 3 % 判断当前是否处于闭环捕获或运行阶段。
    st.energyIntegrator = st.energyIntegrator + energyError * Ts; % 更新能量PI积分器。
    st.quadIntegrator = st.quadIntegrator + quadError * Ts; % 更新正交PI积分器。
    [st.energyIntegrator, energyIntSat] = local_clip(st.energyIntegrator, -p.ctrl.integratorLimit, p.ctrl.integratorLimit); % 对能量积分器进行限幅。
    [st.quadIntegrator, quadIntSat] = local_clip(st.quadIntegrator, -p.ctrl.integratorLimit, p.ctrl.integratorLimit); % 对正交积分器进行限幅。
    energyCommand = p.ctrl.energyKp * energyError + p.ctrl.energyKi * st.energyIntegrator; % 计算能量PI控制输出。
    quadCommand = p.ctrl.quadKp * quadError + p.ctrl.quadKi * st.quadIntegrator; % 计算正交PI控制输出。
    [energyCommand, energyOutSat] = local_clip(energyCommand, -p.ctrl.energyLimit, p.ctrl.energyLimit); % 对能量控制输出进行限幅。
    [quadCommand, quadOutSat] = local_clip(quadCommand, -p.ctrl.quadLimit, p.ctrl.quadLimit); % 对正交控制输出进行限幅。
    st.fixedSaturationCount = st.fixedSaturationCount + double(energyIntSat || quadIntSat || energyOutSat || quadOutSat); % 统计控制器积分与输出限幅事件。
end % 结束能量与正交闭环控制判断。
if p.fault.enable && tk >= p.fault.time && strcmpi(p.fault.type, 'loop_disable') % 判断是否触发控制环关闭故障。
    energyCommand = 0; % 故障后关闭能量驱动命令。
    quadCommand = 0; % 故障后关闭正交抑制命令。
end % 结束控制环关闭故障处理。
if p.asic.fixedEnable % 判断是否对控制输出施加定点字长限制。
    [energyCommand, sat1] = local_fixed(energyCommand, p.asic.controlWordLength, p.asic.controlFractionLength); % 量化能量控制命令。
    [quadCommand, sat2] = local_fixed(quadCommand, p.asic.controlWordLength, p.asic.controlFractionLength); % 量化正交控制命令。
    [virtualRateCommand, sat3] = local_fixed(virtualRateCommand, p.asic.controlWordLength, p.asic.controlFractionLength); % 量化虚拟进动命令。
    st.fixedSaturationCount = st.fixedSaturationCount + double(sat1 || sat2 || sat3); % 统计控制字定点饱和次数。
end % 结束控制字定点量化判断。
instantFault = st.mode == 3 && (inv.E < p.protect.energyMin || inv.E > p.protect.energyMax || abs(inv.Q) > p.protect.quadMax || unwrapFault); % 汇总RUN状态下的能量、正交和展开异常。
if instantFault % 判断本拍是否存在瞬时故障。
    st.consecutiveFaultCount = st.consecutiveFaultCount + 1; % 累加连续故障拍数。
else % 处理本拍没有瞬时故障的情况。
    st.consecutiveFaultCount = 0; % 清零连续故障拍数。
end % 结束瞬时故障计数判断。
if st.consecutiveFaultCount >= p.protect.consecutiveFaults % 判断连续故障是否达到锁存门限。
    st.mode = uint8(6); % 将状态机切换到FAULT状态。
    st.faultLatched = true; % 锁存故障标志供软件读取。
end % 结束故障锁存判断。
if st.mode == 6 % 判断当前是否处于FAULT状态。
    energyCommand = 0; % FAULT状态强制关闭能量控制输出。
    quadCommand = 0; % FAULT状态强制关闭正交控制输出。
    virtualRateCommand = 0; % FAULT状态强制关闭虚拟进动输出。
end % 结束FAULT状态安全输出处理。
cmd = [energyCommand; quadCommand; virtualRateCommand]; % 组成三路ASIC控制字向量。
statusWord = uint32(0); % 初始化32位状态字。
statusWord = bitset(statusWord, 1, mod(round(tk / Ts), p.asic.outputDecimation) == 0); % 设置bit0数据就绪标志。
statusWord = bitset(statusWord, 2, st.locked); % 设置bit1闭环锁定标志。
statusWord = bitset(statusWord, 3, st.adcSaturationCount > 0); % 设置bit2 ADC饱和历史标志。
statusWord = bitset(statusWord, 4, st.dacSaturationCount > 0); % 设置bit3 DAC饱和历史标志。
statusWord = bitset(statusWord, 5, st.fixedSaturationCount > 0); % 设置bit4定点饱和历史标志。
statusWord = bitset(statusWord, 6, st.unwrapFaultCount > 0); % 设置bit5四倍角展开异常历史标志。
statusWord = bitset(statusWord, 7, phaseValid); % 设置bit6相位矢量有效标志。
statusWord = bitset(statusWord, 8, st.faultLatched); % 设置bit7故障锁存标志。
nav.theta = st.thetaEstimate; % 输出连续驻波角估计。
nav.angle = st.angleOutput; % 输出连续导航角度。
nav.rate = st.rateOutput; % 输出滤波后的导航角速度。
nav.rawRate = rawRate; % 输出补偿前角速度供诊断。
nav.phaseError = phaseError; % 输出归一化频率相位误差。
nav.statusWord = statusWord; % 输出32位数字接口状态字。
end % 结束数字ASIC控制与导航解算函数。

function [act, st, diag] = local_dac_driver(cmd, st, p) % 模拟控制流水线、DAC量化、驱动增益和饱和。
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
diag.saturated = saturated || satDriver; % 输出DAC与驱动级综合饱和标志。
end % 结束DAC与驱动行为模型函数。

function x = local_plant_step(tk, x, act, inputRate, temperature, p, Ts) % 以慢变量平均方程推进HRG谐振子状态。
energyDrive = act(1); % 读取能量执行通道实际作用量。
quadDrive = act(2); % 读取正交执行通道实际作用量。
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
log.angleOutput(k) = nav.angle; % 记录导航角度输出。
log.rateOutput(k) = nav.rate; % 记录导航角速度输出。
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
log.adcSatCount(k) = st.adcSaturationCount; % 记录累计ADC饱和次数。
log.dacSatCount(k) = st.dacSaturationCount; % 记录累计DAC饱和次数。
log.fixedSatCount(k) = st.fixedSaturationCount; % 记录累计定点饱和或控制限幅次数。
log.unwrapFaultCount(k) = st.unwrapFaultCount; % 记录累计四倍角展开异常次数。
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

