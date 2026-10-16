function y = HRG_WA_output(t, x, p, addNoise)
% HRG_WA_OUTPUT  Compute demodulated variables and gyro outputs.
%
% 功能说明：
%   本函数根据 HRG_WA_rhs.m 积分得到的慢变量状态 x，生成可观察的全角模式输出量，
%   包括二次解调变量 E/Q/S/R/L、驻波角估计、输入角估计、角速度估计以及控制量。
%
% 为什么需要本函数：
%   HRG_WA_rhs.m 只负责状态方程积分，不直接输出测量量。
%   在真实系统中，x/y 检测信号需要经过同步解调、低通滤波、二次解调和 atan2
%   才能得到驻波角。本函数用慢变量直接合成等效解调变量，便于验证算法。
%
% 输入：
%   t         当前仿真时间，单位 s。
%   x         6x1 状态向量，含 E、Q、theta、积分状态和 thetaVirt。
%   p         参数结构体。
%   addNoise  是否在输出解调变量中叠加检测噪声和 ADC 量化误差。
%
% 输出结构体 y 字段：
%   E,Q,S,R,L             解调变量，若 addNoise=true 则为带噪/量化后的变量。
%   theta_wrapped         由 atan2(S,R)/4 得到的包裹驻波角，范围受 atan2 限制。
%   angle_est             由真实 theta 直接计算的输入角估计，单位 rad。
%   rate_est              由 theta_dot 反推的输入角速度估计，单位 rad/s。
%   inputOmega            当前输入角速度，单位 rad/s。
%   fa,fq                 能量和正交控制量。
%   theta_true            状态中的真实驻波角。

% 如果调用者没有传入 addNoise，则默认不加噪声。
if nargin < 4
    addNoise = false;
end

% -------------------------------------------------------------------------
% 1. 从状态向量中读取慢变量
% -------------------------------------------------------------------------
E     = x(1);    % 谐振能量。
Q     = x(2);    % 正交变量。
theta = x(3);    % 真实物理驻波角。
thetaVirt = x(6);% 虚拟进动积分角。
Omega = p.inputOmegaFcn(t); % 当前输入角速度。

% -------------------------------------------------------------------------
% 2. 合成二次解调变量 S/R
% -------------------------------------------------------------------------
% D = a^2 - q^2 是主波和正交波能量差。
% 由于 E = a^2 + q^2，Q = 2*a*q，因此 D = sqrt(E^2 - Q^2)。
% 为避免数值噪声导致 E^2-Q^2 为微小负数，这里使用 max(...,0) 保护。
D = sqrt(max(E^2 - Q^2, 0));

% HRG 二阶四波腹模态下，驻波物理角 theta 在 S/R 中表现为 4*theta。
% 后处理中必须使用 unwrap(atan2(S,R))/4 才能得到连续角度。
S = D*sin(4*theta);
R = D*cos(4*theta);

% L 在完整同步解调中通常用于锁相/频率跟踪。
% 本慢变量示例没有显式建 PLL，因此置为 0。
L = 0.0;

% -------------------------------------------------------------------------
% 3. 构造测量变量副本，必要时加入检测噪声和 ADC 量化
% -------------------------------------------------------------------------
Em = E;
Qm = Q;
Sm = S;
Rm = R;
Lm = L;

if addNoise && p.det.enableNoise
    % 加性高斯白噪声，等效表示电容检测、前端放大器和解调链路噪声。
    Em = Em + p.det.sigmaE*randn;
    Qm = Qm + p.det.sigmaQ*randn;
    Sm = Sm + p.det.sigmaSR*randn;
    Rm = Rm + p.det.sigmaSR*randn;

    % 可选均匀量化器，模拟 ADC 或数字化后解调变量的有限位宽。
    % fullScale 表示正负满量程幅值，因此总范围为 2*fullScale。
    qstep = 2*p.det.fullScale/(2^p.det.adcBits);
    Em = qstep*round(Em/qstep);
    Qm = qstep*round(Qm/qstep);
    Sm = qstep*round(Sm/qstep);
    Rm = qstep*round(Rm/qstep);
end

% -------------------------------------------------------------------------
% 4. 由 S/R 反算包裹驻波角
% -------------------------------------------------------------------------
% atan2(S,R) 输出范围为 [-pi,pi]，所以 theta_wrapped 只是单点包裹角。
% 若要得到连续驻波角，必须在主程序中对 atan2(S,R) 先 unwrap，再除以 4。
theta_wrapped = 0.25*atan2(Sm,Rm);

% -------------------------------------------------------------------------
% 5. 重新计算控制量，便于记录和画图
% -------------------------------------------------------------------------
% 这里使用真实 E/Q 和积分状态计算控制量，与 HRG_WA_rhs.m 保持一致。
eE = p.E0 - E;
eQ = p.Q0 - Q;
fa = p.ctrl.KpE*eE + p.ctrl.KiE*x(4);
fq = p.ctrl.KpQ*eQ + p.ctrl.KiQ*x(5);

% -------------------------------------------------------------------------
% 6. 角速度和角度输出
% -------------------------------------------------------------------------
% 角速度估计：调用状态方程得到 theta_dot，再扣除虚拟进动项，最后除以 Bryan 因子。
% 注意符号：理想关系为 theta_dot = -cBryan*Omega。
xdot = HRG_WA_rhs(t,x,p);
rate_est = -(xdot(3) - p.ctrl.virtualRateFcn(t))/p.cBryan;

% 角度估计：由驻波角相对初始角的变化量得到输入转角，同时扣除虚拟进动积分。
angle_est = -(theta - p.theta0 - thetaVirt)/p.cBryan;

% -------------------------------------------------------------------------
% 7. 打包输出结构体
% -------------------------------------------------------------------------
y = struct('E',Em,'Q',Qm,'S',Sm,'R',Rm,'L',Lm, ...
           'theta_wrapped',theta_wrapped, ...
           'angle_est',angle_est,'rate_est',rate_est, ...
           'inputOmega',Omega,'fa',fa,'fq',fq, ...
           'theta_true',theta);
end
