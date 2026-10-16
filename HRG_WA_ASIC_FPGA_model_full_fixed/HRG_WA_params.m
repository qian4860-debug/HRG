function p = HRG_WA_params()
% HRG_WA_PARAMS  Whole-angle hemispherical resonator gyro envelope model parameters.
%
% 功能说明：
%   本函数集中定义半球谐振陀螺 HRG 在全角模式 Whole-Angle / Rate-Integrating
%   模式下的所有仿真参数。主脚本 run_HRG_WA_demo.m 会首先调用本函数，
%   然后把参数结构体 p 传递给状态方程 HRG_WA_rhs.m 和输出函数 HRG_WA_output.m。
%
% 模型特点：
%   1. 使用慢变量/包络模型，而不是直接积分 5 kHz 载波振动。
%      这样可以更快地观察全角模式的驻波进动、能量控制和正交控制效果。
%   2. 使用物理驻波角 theta 作为角度状态。
%      由于 HRG 工作在二阶四波腹模态，二次解调变量 S/R 中出现 sin(4*theta)
%      和 cos(4*theta)。因此由 S/R 反算角度时需要 atan2(S,R)/4。
%   3. 本文件只给出一组可稳定运行的参考参数，不代表某一具体器件的标定值。
%      实际论文或工程仿真时，应根据谐振子测试结果替换 Q 值、频率裂解、
%      阻尼不均匀、Bryan 因子和控制增益等参数。
%
% 单位约定：
%   角度统一使用 rad；时间使用 s；频率使用 Hz 或 rad/s；能量为归一化变量。
%
% 输出：
%   p  参数结构体，包含 sim、err、ctrl、drive、det 等子结构。

% -------------------------------------------------------------------------
% 1. 仿真时间参数
% -------------------------------------------------------------------------
p.sim.T  = 60;          % 总仿真时间，单位 s。默认仿真 60 s。
p.sim.dt = 1e-3;        % 建议最大积分步长/离散实现步长，单位 s。
                         % 本模型是慢变量模型，1 ms 通常足够观察角度与控制过程。

% -------------------------------------------------------------------------
% 2. 谐振子名义参数
% -------------------------------------------------------------------------
p.f0       = 5.0e3;             % 谐振频率，单位 Hz。这里取 5 kHz 作为典型值。
p.w0       = 2*pi*p.f0;         % 谐振角频率，单位 rad/s。
p.Qfactor  = 1.0e6;             % 机械品质因数 Q。Q 越大，机械阻尼越小。
p.tauAmp   = 2*p.Qfactor/p.w0;  % 振幅衰减时间常数，单位 s。
                                 % 对高 Q 谐振器，tauAmp 往往很大。
p.dampMean = 1/p.tauAmp;        % 平均振幅阻尼系数，单位 1/s。
p.cBryan   = 0.277;             % Bryan 进动因子/角度增益。
                                 % 全角输出关系：input_angle = -(theta-theta0-thetaVirt)/cBryan。
                                 % 该值必须通过转台标定获得，这里仅给示例值。

% -------------------------------------------------------------------------
% 3. 全角模式驻波初值和控制目标
% -------------------------------------------------------------------------
p.theta0 = 0;             % 初始物理驻波方位角，单位 rad。
p.E0     = 1.0;           % 目标归一化能量，E = a^2 + q^2。
p.Q0     = 0.0;           % 目标正交变量，Q = 2*a*q。理想全角模式希望 Q -> 0。

% -------------------------------------------------------------------------
% 4. 谐振子非理想特征参数
% -------------------------------------------------------------------------
% 阻尼不均匀会导致驻波角相关漂移，是全角模式死区和角度相关零偏的重要来源。
p.err.dTauInv   = 5e-4;          % 阻尼不均匀系数，单位 1/s。
p.err.thetaTau  = 15*pi/180;     % 阻尼主轴物理方位角，单位 rad。

% 频率裂解表示两个简并模态的固有频率不完全相同。
% 频率裂解会耦合到正交量 Q，并进一步引起驻波角漂移。
p.err.dOmega    = 2*pi*0.010;    % 频率裂解系数，单位 rad/s；此处示例为 0.010 Hz。
p.err.thetaOmega= 40*pi/180;     % 刚度/频率主轴物理方位角，单位 rad。

% -------------------------------------------------------------------------
% 5. 能量控制和正交控制 PI 增益
% -------------------------------------------------------------------------
% 在慢变量模型中，fa 直接作用于 E_dot，fq 直接作用于 Q_dot。
% 若接入真实电极模型，需要再经过力分配和驱动线性化。
p.ctrl.KpE = 2.5;     % 能量控制比例增益。增大可加快能量收敛，但过大可能振荡。
p.ctrl.KiE = 0.3;     % 能量控制积分增益。用于消除稳态能量误差。
p.ctrl.KpQ = 8.0;     % 正交控制比例增益。用于快速抑制 Q。
p.ctrl.KiQ = 2.0;     % 正交控制积分增益。用于消除稳态正交残差。

% -------------------------------------------------------------------------
% 6. 虚拟进动/旋转调制设置
% -------------------------------------------------------------------------
% 全角模式可通过给驻波施加已知虚拟进动，使阻尼不均匀等角相关误差被周期平均。
% thetaVirt 是该命令角速度的积分量，最终输出角会减去 thetaVirt。
% 默认关闭虚拟进动，即虚拟进动角速度为 0。
p.ctrl.virtualRateFcn = @(t) 0.0;   % 命令的驻波虚拟进动角速度，单位 rad/s。

% -------------------------------------------------------------------------
% 7. 输入角速度函数
% -------------------------------------------------------------------------
% 这里给出一段分段转台角速度：
%   0  - 5  s:  0 deg/s
%   5  - 35 s: +20 deg/s
%   35 - 50 s: -10 deg/s
%   50 - 60 s:  0 deg/s
% 角速度输入为壳体相对于惯性空间的输入角速度 Omega。
p.inputOmegaFcn = @(t) ((t>=5 && t<35)*20 + (t>=35 && t<50)*(-10))*pi/180;

% -------------------------------------------------------------------------
% 8. 驱动链路误差模型
% -------------------------------------------------------------------------
% 该部分模拟驱动放大器、电极力轴、通道相位等不理想因素。
% enable=false 时只保留机械谐振子误差，不加入驱动泄漏误差。
p.drive.enable = true;          % 是否启用驱动链路误差。
p.drive.Gd     = 1.0;           % 驱动误差总尺度因子，用于统一放大/缩小驱动泄漏影响。
p.drive.gY     = 1.01;          % Y 驱动通道相对 X 通道的增益。1.01 表示 Y 通道高 1%。
p.drive.phiX   = 0.3*pi/180;    % X 驱动通道相位延迟，单位 rad。
p.drive.phiY   = -0.2*pi/180;   % Y 驱动通道相位延迟，单位 rad。
p.drive.alphaD = 0.5*pi/180;    % X 驱动力轴安装/电极方位误差，单位 rad。
p.drive.betaD  = -0.4*pi/180;   % Y 驱动力轴安装/电极方位误差，单位 rad。

% -------------------------------------------------------------------------
% 9. 检测和 ADC 模型
% -------------------------------------------------------------------------
% 本示例中控制器使用真实慢变量 E、Q 进行闭环，检测噪声只加在输出变量上，
% 这样便于先验证全角模式核心机理。若要研究闭环噪声，应把带噪 Em/Qm
% 接入控制器计算。
p.det.enableNoise = true;   % 是否在输出解调变量中加入噪声和量化误差。
p.det.sigmaE = 1e-4;        % 能量检测噪声标准差。
p.det.sigmaQ = 1e-4;        % 正交检测噪声标准差。
p.det.sigmaSR = 1e-4;       % S/R 二次解调变量噪声标准差。
p.det.adcBits = 20;         % ADC 等效位宽。
p.det.fullScale = 2.0;      % ADC 满量程幅值，量化步长由 2*fullScale/2^adcBits 给出。



% -------------------------------------------------------------------------
% 11. 面向 FPGA/ASIC 数字控制接口电路的扩展仿真参数
% -------------------------------------------------------------------------
% 下面这些字段不改变原慢变量模型接口；原 run_HRG_WA_demo.m 仍可直接运行。
% 新脚本 run_HRG_WA_ASIC_FPGA_demo.m 会使用这些字段，把机械模型、检测链路、
% ADC、数字解调、CORDIC、PI 控制、DAC、寄存器配置、状态机和性能统计连接起来。

% 11.1 数字控制主时钟/采样周期
p.iface.fsCtrl      = 1000;             % 数字控制更新频率，单位 Hz。FPGA/ASIC 中通常对应控制环采样率。
p.iface.Ts          = 1/p.iface.fsCtrl; % 数字控制采样周期，单位 s。
p.iface.pipelineDelaySamples = 2;       % 数字控制到 DAC 生效的流水线延迟，单位采样点。
p.iface.dataReadyDecim = 1;             % 输出数据 ready 降采样比。1 表示每个控制周期输出一次。
p.iface.enableLogOverflow = true;       % 是否统计定点/接口饱和事件。

% 11.2 模拟检测前端 AFE 行为模型
p.afe.enable        = true;              % 是否启用 AFE 增益、偏置、串扰、噪声和带宽限制。
p.afe.gain         = [1.000; 1.000; 1.000; 1.000]; % E/Q/S/R 四路前端增益。
p.afe.offset       = [0; 0; 0; 0];       % E/Q/S/R 四路前端直流偏置。
p.afe.cross        = eye(4);             % 四路串扰矩阵。非对角项可模拟通道耦合。
p.afe.noiseSigma   = [3e-5; 3e-5; 5e-5; 5e-5]; % 前端等效输入噪声标准差。
p.afe.fullScale    = 2.0;                % 前端输出满量程，超过该范围发生模拟饱和。
p.afe.bandwidthHz  = 300;                % AFE 等效一阶低通带宽，用于模拟前端相位延迟。
p.afe.delaySamples = 1;                  % 额外采样延迟，用于模拟检测链路延迟/CDC 缓冲。

% 11.3 ADC 模型
p.adc.bits         = 18;                 % ADC 位宽。ASIC 方案中可据此评估接口位宽需求。
p.adc.fullScale    = 2.0;                % ADC 正负满量程。
p.adc.enableDither = false;              % 是否添加 0.5 LSB 均匀抖动，避免量化极限环。
p.adc.jitterRms    = 20e-9;              % 采样时钟 RMS 抖动，慢变量模型中折算为小噪声项。
p.adc.saturationDetect = true;           % 是否统计 ADC 饱和。

% 11.4 数字固定点模型
p.fx.enable        = true;                % 是否启用数字定点量化。关闭后为浮点算法仿真。
p.fx.roundMode     = 'nearest';           % 量化方式：nearest 或 floor。
p.fx.measWL        = 24;                  % 测量变量字长。
p.fx.measFL        = 20;                  % 测量变量小数位。
p.fx.ctrlWL        = 24;                  % 控制变量字长。
p.fx.ctrlFL        = 18;                  % 控制变量小数位。
p.fx.intWL         = 32;                  % PI 积分器字长。
p.fx.intFL         = 24;                  % PI 积分器小数位。
p.fx.rateWL        = 32;                  % 角速度输出字长。
p.fx.rateFL        = 20;                  % 角速度输出小数位。
p.fx.angleWL       = 40;                  % 积分角度输出字长。
p.fx.angleFL       = 24;                  % 积分角度输出小数位。

% 11.5 CORDIC/NCO/解调角度链路
p.cordic.angleBits = 24;                  % atan2/CORDIC 输出相位位数，对应 2*pi/2^N 分辨率。
p.cordic.iterations= 24;                  % CORDIC 迭代次数，仅用于资源估算和报告。
p.cordic.latencySamples = 4;              % CORDIC 流水线延迟，单位采样点。
p.nco.phaseBits    = 32;                  % NCO 相位累加器位宽。
p.nco.lutBits      = 14;                  % 正弦/余弦查找表地址位宽。
p.nco.phaseNoiseRms= 0;                   % NCO 相位噪声 RMS，单位 rad。慢变量模型默认不启用。

% 11.6 DAC/驱动接口模型
p.dac.bits         = 16;                  % DAC 或 PWM/ΣΔ 等效输出位宽。
p.dac.fullScaleFa  = 0.25;                % 能量控制 DAC 满量程。
p.dac.fullScaleFq  = 0.25;                % 正交控制 DAC 满量程。
p.dac.fullScaleVirt= 5*pi/180;            % 虚拟进动速率满量程，单位 rad/s。
p.dac.enableDither = false;               % 是否加入 DAC 半 LSB 抖动。
p.dac.zeroOrderHold= true;                % 数字控制输出在采样周期内保持。
p.dac.noiseSigma   = [1e-5; 1e-5; 1e-7];  % DAC/驱动输出等效噪声。
p.dac.gain         = [1.000; 1.000; 1.000];% DAC/驱动通道增益。
p.dac.offset       = [0; 0; 0];           % DAC/驱动通道偏置。

% 11.7 控制器限幅、抗积分饱和和状态机
p.ctrl.faLimit      = p.dac.fullScaleFa;  % 能量控制限幅。
p.ctrl.fqLimit      = p.dac.fullScaleFq;  % 正交控制限幅。
p.ctrl.iELimit      = 1.0;                % 能量 PI 积分器限幅。
p.ctrl.iQLimit      = 1.0;                % 正交 PI 积分器限幅。
p.ctrl.enableAntiWindup = true;           % 控制输出饱和时是否冻结积分器。
p.ctrl.enableDigitalELoop = true;         % 数字能量环使能。
p.ctrl.enableDigitalQLoop = true;         % 数字正交环使能。
p.ctrl.enableVirtualRate = true;          % 数字虚拟进动通道使能。
p.fsm.startupTime   = 0.5;                % STARTUP 开环补能时间，单位 s。
p.fsm.lockTime      = 1.0;                % LOCK 阶段时间，单位 s。
p.fsm.startupFa     = 0.08;               % 启动阶段开环补能控制量。
p.fsm.energyLockTol = 0.10;               % 能量进入目标值 ±10% 认为可进入 RUN。

% 11.8 寄存器/总线接口模型
p.reg.ctrl_enable       = true;            % 总控制使能位。
p.reg.mode             = uint32(3);        % 0=IDLE, 1=STARTUP, 2=LOCK, 3=RUN。
p.reg.int_enable       = true;             % 中断使能。
p.reg.clear_fault      = false;            % 故障清除位。
p.reg.selftest_enable  = false;            % 内建自检注入使能。
p.reg.output_word_bits = 32;               % 输出数据寄存器宽度。
p.reg.bus_word_bits    = 32;               % 寄存器总线字宽。
p.reg.crc_enable       = false;            % 输出帧 CRC 使能，行为模型中仅记录配置。

% 11.9 标定参数和补偿开关
p.cal.enable             = true;            % 是否启用数字标定补偿。
p.cal.Egain             = 1.0;              % E 通道数字增益补偿。
p.cal.Qgain             = 1.0;              % Q 通道数字增益补偿。
p.cal.Sgain             = 1.0;              % S 通道数字增益补偿。
p.cal.Rgain             = 1.0;              % R 通道数字增益补偿。
p.cal.Eoffset           = 0.0;              % E 通道数字零偏补偿。
p.cal.Qoffset           = 0.0;              % Q 通道数字零偏补偿。
p.cal.Soffset           = 0.0;              % S 通道数字零偏补偿。
p.cal.Roffset           = 0.0;              % R 通道数字零偏补偿。
p.cal.scaleFactor       = 1.0;              % 角度/角速度比例因子补偿。
p.cal.biasRate          = 0.0;              % 角速度零偏补偿，单位 rad/s。
p.cal.temperatureEnable = true;             % 是否启用温度补偿模型。

% 11.10 温度、供电、振动和故障注入
p.env.enable            = true;             % 是否启用环境参数模型。
p.env.T0                = 25;               % 参考温度，单位 degC。
p.env.tempFcn           = @(t) 25 + 10*(t>20).*(1-exp(-(t-20)/20)); % 温度阶跃/缓变示例。
p.env.tempCoeffBias     = 0.02*pi/180/3600; % 零偏温度系数，单位 rad/s/degC。
p.env.tempCoeffScale    = 20e-6;            % 标度因数温度系数，单位 1/degC。
p.env.supplyNoiseSigma  = 1e-5;             % 电源噪声折算到控制/检测通道的尺度。
p.env.vibrationSigma    = 2e-5;             % 外部振动折算到 E/Q/theta 的小扰动尺度。
p.fault.injectTime      = inf;              % 故障注入时刻。inf 表示默认不注入。
p.fault.type            = 'none';            % none/adc_stuck/dac_saturate/afe_offset/loop_disable。
p.fault.magnitude       = 0.0;               % 故障幅值。

% 11.11 样机性能指标验收阈值示例
p.perf.angleRmsLimitDeg       = 1.0;         % 该激励下角度 RMS 误差参考阈值。
p.perf.rateRmsLimitDps        = 0.1;         % 角速度 RMS 误差参考阈值。
p.perf.energyMeanTol          = 0.02;        % E 均值允许偏离目标值比例。
p.perf.quadratureMaxLimit     = 0.05;        % |Q| 最大值参考阈值。
p.perf.adcSatMax              = 0;           % ADC 饱和次数阈值。
p.perf.dacSatMax              = 10;          % DAC 饱和次数阈值。

% -------------------------------------------------------------------------
% 10. 数值保护量
% -------------------------------------------------------------------------
p.epsE = 1e-9;              % 防止 E 过小时出现除零或 sqrt 负数的保护值。
end
