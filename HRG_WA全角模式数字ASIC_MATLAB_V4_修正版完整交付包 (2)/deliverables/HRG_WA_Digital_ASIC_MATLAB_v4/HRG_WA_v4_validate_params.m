function report = HRG_WA_v4_validate_params(p, issueMessages) % 检查物理参数、数字时基、动态范围、控制器带宽和测试窗口的一致性。
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
if p.ctrl.energyLimit > p.dac.fullScale(1) || p.ctrl.quadLimit > p.dac.fullScale(2) % 检查PI数字限幅是否超过实际DAC物理量程。
    report.errors{end + 1} = '能量或正交数字控制限幅超过对应DAC满量程。'; % 记录数字控制范围与DAC不匹配错误。
end % 结束PI限幅与DAC范围检查。
if p.virtual.amplitudeDps * pi / 180 > p.dac.fullScale(3) % 检查虚拟进动命令是否超过执行通道范围。
    report.errors{end + 1} = '虚拟进动峰值超过第三路DAC满量程。'; % 记录虚拟进动通道范围错误。
end % 结束虚拟进动范围检查。
invariantMaximum = 2 ^ (p.asic.invariantWordLength - p.asic.invariantFractionLength - 1) - 2 ^ (-p.asic.invariantFractionLength); % 计算不变量有符号Q格式最大可表示值。
if p.protect.energyMax > invariantMaximum % 检查能量保护上限是否超出不变量定点范围。
    report.errors{end + 1} = 'energyMax超过不变量Q格式最大可表示值。'; % 记录不变量定点范围不足错误。
end % 结束不变量定点范围检查。
controlMaximum = 2 ^ (p.asic.controlWordLength - p.asic.controlFractionLength - 1) - 2 ^ (-p.asic.controlFractionLength); % 计算控制字有符号Q格式最大可表示值。
if max([p.ctrl.energyLimit, p.ctrl.quadLimit, p.dac.fullScale(3)]) > controlMaximum % 检查三路控制量是否超出控制字定点范围。
    report.errors{end + 1} = '至少一路控制量或执行量程超过控制字Q格式最大可表示值。'; % 记录控制字定点范围不足错误。
end % 结束控制字定点范围检查。
[~, suggestion] = HRG_WA_v4_autotune(p, false); % 计算当前物理量对应的控制器范围和动态裕量建议。
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
