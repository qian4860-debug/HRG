function xdot = HRG_WA_rhs(t, x, p)
% HRG_WA_RHS  Right-hand side of the whole-angle HRG slow-variable model.
%
% 功能说明：
%   本函数给出半球谐振陀螺 HRG 全角模式的慢变量状态方程。
%   ode45 或 Simulink MATLAB Function 模块每调用一次本函数，就会根据当前状态 x、
%   当前时间 t 和参数 p 计算状态导数 xdot。
%
% 状态向量定义：
%   x(1) = E          谐振能量，E = a^2 + q^2。
%   x(2) = Q          正交变量，Q = 2*a*q。
%   x(3) = theta      物理驻波方位角，单位 rad。
%   x(4) = iE         能量误差积分量，用于能量 PI 控制。
%   x(5) = iQ         正交误差积分量，用于正交 PI 控制。
%   x(6) = thetaVirt  命令虚拟进动角的积分量，单位 rad。
%
% 主要输出关系：
%   input_angle_est = -(theta - theta0 - thetaVirt)/cBryan
%
% 模型物理含义：
%   1. E_dot 描述谐振能量的自然衰减、阻尼不均匀调制和补能控制。
%   2. Q_dot 描述正交变量的自然衰减、频率裂解激励和正交控制。
%   3. theta_dot 描述驻波在输入角速度、虚拟进动、阻尼不均匀、频率裂解、
%      驱动误差共同作用下的进动角速度。
%
% 输入：
%   t  当前仿真时间，单位 s。
%   x  6x1 状态向量。
%   p  参数结构体，由 HRG_WA_params.m 生成。
%
% 输出：
%   xdot 6x1 状态导数向量。

% -------------------------------------------------------------------------
% 1. 从状态向量中取出各个慢变量
% -------------------------------------------------------------------------
E     = x(1);    % 谐振能量，理想情况下应稳定在 p.E0 附近。
Q     = x(2);    % 正交变量，理想情况下应被控制到 0 附近。
theta = x(3);    % 物理驻波方位角，全角模式的角度信息就包含在该变量中。
iE    = x(4);    % 能量误差积分状态。
iQ    = x(5);    % 正交误差积分状态。

% -------------------------------------------------------------------------
% 2. 读取当前输入角速度和虚拟进动命令
% -------------------------------------------------------------------------
Omega = p.inputOmegaFcn(t);          % 输入角速度，单位 rad/s。
virtRate = p.ctrl.virtualRateFcn(t); % 命令虚拟驻波进动角速度，单位 rad/s。

% -------------------------------------------------------------------------
% 3. 能量 PI 控制和正交 PI 控制
% -------------------------------------------------------------------------
% 能量误差：希望 E -> p.E0。
eE = p.E0 - E;

% 正交误差：希望 Q -> p.Q0，通常 p.Q0=0。
eQ = p.Q0 - Q;

% fa 为沿主波方向的补能控制量，直接进入 E_dot。
fa = p.ctrl.KpE*eE + p.ctrl.KiE*iE;

% fq 为沿正交方向的控制量，直接进入 Q_dot。
fq = p.ctrl.KpQ*eQ + p.ctrl.KiQ*iQ;

% -------------------------------------------------------------------------
% 4. 驱动链路误差投影到驻波角速度通道
% -------------------------------------------------------------------------
% 真实系统中，fa 和 fq 需要通过驱动电极施加到谐振子上。
% 若 X/Y 驱动通道存在增益不一致、相位延迟或力轴不正交，则一部分本应作用于
% 能量/正交通道的控制力会泄漏到 theta_dot，表现为角速度漂移。
%
% 下面的 compact model 不是电极场的完整有限元模型，而是全角模式控制仿真中
% 常用的等效泄漏模型，适合分析驱动误差对角输出的影响。
driveRateErr = 0.0;
if p.drive.enable
    % den 与振动能量相关。能量越大，同样的驱动力引起的等效角速度误差越小。
    den = sqrt(max(2*p.w0*E, p.epsE));

    % 由 X/Y 驱动通道误差产生的等效驻波角速度误差。
    % alphaD、betaD 表示力轴安装误差；phiX、phiY 表示相位延迟；gY 表示 Y 通道增益偏差。
    driveRateErr = p.drive.Gd/den * ( ...
        -sin(2*theta - 2*p.drive.alphaD) * ...
          (fa*cos(2*theta)*cos(p.drive.phiX) + fq*sin(2*theta)*sin(p.drive.phiX)) ...
        +p.drive.gY*cos(2*theta - 2*p.drive.betaD) * ...
          (fa*sin(2*theta)*cos(p.drive.phiY) - fq*cos(2*theta)*sin(p.drive.phiY)) );
end

% -------------------------------------------------------------------------
% 5. 全角模式慢变量动力学
% -------------------------------------------------------------------------
% E_dot：
%   -2*dampMean*E                         平均阻尼导致能量衰减；
%   -dTauInv*cos(4*(theta-thetaTau))*E    阻尼不均匀引起能量随驻波角周期变化；
%   +fa                                   能量控制补偿。
E_dot = -2*p.dampMean*E ...
        -p.err.dTauInv*cos(4*(theta - p.err.thetaTau))*E ...
        +fa;

% Q_dot：
%   -2*dampMean*Q                         正交分量自然衰减；
%   -2*dOmega*E*sin(4*(theta-thetaOmega))  频率裂解激励正交分量；
%   +fq                                   正交控制补偿。
Q_dot = -2*p.dampMean*Q ...
        -2*p.err.dOmega*E*sin(4*(theta - p.err.thetaOmega)) ...
        +fq;

% theta_dot：
%   -cBryan*Omega                         理想 Bryan 进动项，输入角速度使驻波反向进动；
%   +virtRate                             人为施加的虚拟进动/旋转调制；
%   +0.5*dTauInv*sin(...)                 阻尼不均匀造成的角相关漂移；
%   +0.5*dOmega*cos(...)*Q/E              频率裂解通过正交量 Q 耦合成角漂移；
%   +driveRateErr                         驱动链路误差造成的等效角速度误差。
theta_dot = -p.cBryan*Omega ...
            +virtRate ...
            +0.5*p.err.dTauInv*sin(4*(theta - p.err.thetaTau)) ...
            +0.5*p.err.dOmega*cos(4*(theta - p.err.thetaOmega))*Q/max(E,p.epsE) ...
            +driveRateErr;

% -------------------------------------------------------------------------
% 6. 组装状态导数
% -------------------------------------------------------------------------
xdot = zeros(6,1);
xdot(1) = E_dot;       % 能量状态导数。
xdot(2) = Q_dot;       % 正交状态导数。
xdot(3) = theta_dot;   % 驻波角状态导数。
xdot(4) = eE;          % 积分器状态：iE_dot = eE。
xdot(5) = eQ;          % 积分器状态：iQ_dot = eQ。
xdot(6) = virtRate;    % 虚拟进动角积分：thetaVirt_dot = virtRate。
end
