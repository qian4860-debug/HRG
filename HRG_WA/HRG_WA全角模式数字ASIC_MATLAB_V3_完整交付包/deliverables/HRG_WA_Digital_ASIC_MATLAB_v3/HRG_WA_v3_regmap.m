function reg = HRG_WA_v3_regmap(p) % 生成面向32位APB或AXI-Lite接口的建议寄存器表。
if nargin < 1 || isempty(p) % 判断调用者是否传入参数。
    p = HRG_WA_v3_params(); % 未传入参数时加载标称配置。
end % 结束默认参数判断。
entry = @(address, name, access, reset, description) struct('address', uint32(address), 'name', name, 'access', access, 'reset', reset, 'description', description); % 定义单个寄存器描述构造器。
reg = repmat(entry(0, '', '', uint32(0), ''), 24, 1); % 预分配二十四个寄存器描述项。
reg(1) = entry(hex2dec('0000'), 'CTRL', 'RW', uint32(0), 'bit0全局使能，bit1能量环，bit2正交环，bit3虚拟进动，bit4自检'); % 定义全局控制寄存器。
reg(2) = entry(hex2dec('0004'), 'MODE', 'RW', uint32(p.fsm.initialMode), '1启动，2捕获，3运行，5自检，6故障'); % 定义状态机控制寄存器。
reg(3) = entry(hex2dec('0008'), 'STATUS', 'RO', uint32(0), '数据就绪、锁定、饱和、相位有效及故障锁存标志'); % 定义状态寄存器。
reg(4) = entry(hex2dec('000C'), 'IRQ_MASK', 'RW', uint32(0), '中断屏蔽位'); % 定义中断屏蔽寄存器。
reg(5) = entry(hex2dec('0010'), 'FAULT_CLEAR', 'WO', uint32(0), '写1清除允许软件复位的故障锁存'); % 定义故障清除寄存器。
reg(6) = entry(hex2dec('0020'), 'PLL_KP', 'RW', single(p.pll.kpHz), 'DPLL比例增益的定点或浮点等效值'); % 定义DPLL比例增益寄存器。
reg(7) = entry(hex2dec('0024'), 'PLL_KI', 'RW', single(p.pll.kiHz), 'DPLL积分增益的定点或浮点等效值'); % 定义DPLL积分增益寄存器。
reg(8) = entry(hex2dec('0028'), 'ENERGY_KP', 'RW', single(p.ctrl.energyKp), '能量环比例增益'); % 定义能量环比例增益寄存器。
reg(9) = entry(hex2dec('002C'), 'ENERGY_KI', 'RW', single(p.ctrl.energyKi), '能量环积分增益'); % 定义能量环积分增益寄存器。
reg(10) = entry(hex2dec('0030'), 'QUAD_KP', 'RW', single(p.ctrl.quadKp), '正交环比例增益'); % 定义正交环比例增益寄存器。
reg(11) = entry(hex2dec('0034'), 'QUAD_KI', 'RW', single(p.ctrl.quadKi), '正交环积分增益'); % 定义正交环积分增益寄存器。
reg(12) = entry(hex2dec('0040'), 'ENERGY_REF', 'RW', single(p.res.energyTarget), '归一化驻波能量目标值'); % 定义能量目标寄存器。
reg(13) = entry(hex2dec('0044'), 'VIRTUAL_RATE', 'RW', single(0), '虚拟进动角速度控制字'); % 定义虚拟进动寄存器。
reg(14) = entry(hex2dec('0050'), 'NCO_FCW', 'RO', uint32(0), 'NCO频率控制字'); % 定义NCO频率控制字寄存器。
reg(15) = entry(hex2dec('0054'), 'CORDIC_PHASE', 'RO', uint32(0), '量化后的四倍角CORDIC结果'); % 定义CORDIC相位寄存器。
reg(16) = entry(hex2dec('0060'), 'E_OUT', 'RO', uint32(0), '能量不变量定点输出'); % 定义能量输出寄存器。
reg(17) = entry(hex2dec('0064'), 'Q_OUT', 'RO', uint32(0), '正交不变量定点输出'); % 定义正交输出寄存器。
reg(18) = entry(hex2dec('0068'), 'R_OUT', 'RO', uint32(0), '余弦四倍角不变量输出'); % 定义R输出寄存器。
reg(19) = entry(hex2dec('006C'), 'S_OUT', 'RO', uint32(0), '正弦四倍角不变量输出'); % 定义S输出寄存器。
reg(20) = entry(hex2dec('0070'), 'ANGLE_LO', 'RO', uint32(0), '四十八位连续角度累加器低三十二位'); % 定义角度低字寄存器。
reg(21) = entry(hex2dec('0074'), 'ANGLE_HI', 'RO', uint32(0), '四十八位连续角度累加器高十六位'); % 定义角度高字寄存器。
reg(22) = entry(hex2dec('0078'), 'RATE_OUT', 'RO', uint32(0), '补偿并低通后的角速度输出'); % 定义角速度输出寄存器。
reg(23) = entry(hex2dec('0080'), 'SAT_COUNT', 'RO', uint32(0), 'ADC、DAC和定点饱和计数'); % 定义饱和计数寄存器。
reg(24) = entry(hex2dec('0084'), 'SAMPLE_COUNT', 'RO', uint32(0), '控制域采样计数器'); % 定义采样计数寄存器。
end % 结束寄存器表生成函数。

