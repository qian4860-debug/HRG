function xdot = HRG_WA_rhs_digital(t, x, p, uAct)
% HRG_WA_RHS_DIGITAL  Plant slow-variable RHS driven by external digital controls.
%
% 功能说明：
%   HRG_WA_rhs.m 内部自带理想 PI 控制，适合快速验证全角模式机理；本函数则把
%   fa/fq/virtRate 作为外部输入，适合 FPGA/ASIC 数字控制闭环仿真。
%
% 状态向量仍保持与原模型兼容：
%   x = [E; Q; theta; iE; iQ; thetaVirt]
% 其中 iE/iQ 在本函数中不再作为控制积分器使用，仅保留以兼容原数据结构。
%
% 输入 uAct：
%   uAct(1) = fa_act      DAC/驱动实际作用到能量通道的控制量。
%   uAct(2) = fq_act      DAC/驱动实际作用到正交通道的控制量。
%   uAct(3) = virtRateAct 实际虚拟进动角速度，单位 rad/s。

if nargin < 4 || isempty(uAct)
    uAct = [0;0;0];
end

E     = x(1);
Q     = x(2);
theta = x(3);

fa = uAct(1);
fq = uAct(2);
virtRate = uAct(3);

Omega = p.inputOmegaFcn(t);

% 温度对零偏和标度因数的等效影响。这里把温度标度误差作用于输入角速度项，
% 把温度零偏作用为额外等效角速度。
Tnow = p.env.tempFcn(t);
scaleTemp = 1.0;
biasTemp = 0.0;
if p.env.enable
    scaleTemp = 1 + p.env.tempCoeffScale*(Tnow - p.env.T0);
    biasTemp = p.env.tempCoeffBias*(Tnow - p.env.T0);
end
OmegaEff = scaleTemp*Omega + biasTemp;

% 驱动泄漏误差：复用原模型的紧凑投影形式，但控制量来自数字链路。
driveRateErr = 0.0;
if p.drive.enable
    den = sqrt(max(2*p.w0*E, p.epsE));
    driveRateErr = p.drive.Gd/den * ( ...
        -sin(2*theta - 2*p.drive.alphaD) * ...
          (fa*cos(2*theta)*cos(p.drive.phiX) + fq*sin(2*theta)*sin(p.drive.phiX)) ...
        +p.drive.gY*cos(2*theta - 2*p.drive.betaD) * ...
          (fa*sin(2*theta)*cos(p.drive.phiY) - fq*cos(2*theta)*sin(p.drive.phiY)) );
end

% 环境振动/扰动。为保证可重复性，主脚本会固定 rng。
noiseE = 0; noiseQ = 0; noiseTheta = 0;
if p.env.enable
    noiseE = 0.1*p.env.vibrationSigma*randn;
    noiseQ = 1.0*p.env.vibrationSigma*randn;
    noiseTheta = 0.02*p.env.vibrationSigma*randn;
end

E_dot = -2*p.dampMean*E ...
        -p.err.dTauInv*cos(4*(theta - p.err.thetaTau))*E ...
        +fa + noiseE;

Q_dot = -2*p.dampMean*Q ...
        -2*p.err.dOmega*E*sin(4*(theta - p.err.thetaOmega)) ...
        +fq + noiseQ;

theta_dot = -p.cBryan*OmegaEff ...
            +virtRate ...
            +0.5*p.err.dTauInv*sin(4*(theta - p.err.thetaTau)) ...
            +0.5*p.err.dOmega*cos(4*(theta - p.err.thetaOmega))*Q/max(E,p.epsE) ...
            +driveRateErr + noiseTheta;

xdot = zeros(6,1);
xdot(1) = E_dot;
xdot(2) = Q_dot;
xdot(3) = theta_dot;
xdot(4) = 0;
xdot(5) = 0;
xdot(6) = virtRate;
end
