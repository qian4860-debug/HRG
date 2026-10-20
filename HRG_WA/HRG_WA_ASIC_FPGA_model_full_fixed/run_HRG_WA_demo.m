%% run_HRG_WA_demo
% Whole-angle hemispherical resonator gyro simulatable envelope model.
%
% 功能说明：
%   这是半球谐振陀螺 HRG 全角模式可仿真模型的主运行脚本。
%   直接在 MATLAB 命令窗口运行本文件，即可完成：
%       1. 参数初始化；
%       2. 慢变量状态方程积分；
%       3. 二次解调变量 E/Q/S/R 合成；
%       4. 驻波角 unwrap 解算；
%       5. 输入角和模型输出角对比；
%       6. 能量、正交量和控制量绘图；
%       7. 保存仿真结果 HRG_WA_demo_result.mat。
%
% 文件调用关系：
%   run_HRG_WA_demo.m  ->  HRG_WA_params.m
%                       ->  HRG_WA_rhs.m
%                       ->  HRG_WA_output.m
%
% 保持文件名和函数名不变时，该脚本可直接作为整套模型入口。

% -------------------------------------------------------------------------
% 1. 清理工作区并固定随机种子
% -------------------------------------------------------------------------
clear; clc; close all;

% 固定随机种子后，每次运行加入的检测噪声序列一致，便于复现实验结果。
rng(1);

% -------------------------------------------------------------------------
% 2. 读取全角 HRG 模型参数
% -------------------------------------------------------------------------
p = HRG_WA_params();

% -------------------------------------------------------------------------
% 3. 设置状态初值
% -------------------------------------------------------------------------
% 状态向量 x = [E; Q; theta; iE; iQ; thetaVirt]
%   E         初始能量，取目标值 p.E0；
%   Q         初始正交量，这里故意给 0.01，用于观察正交控制收敛；
%   theta     初始驻波角；
%   iE/iQ     PI 控制积分器初值；
%   thetaVirt 虚拟进动积分初值。
x0 = [p.E0; 0.01; p.theta0; 0; 0; 0];

% -------------------------------------------------------------------------
% 4. 使用 ode45 积分慢变量状态方程
% -------------------------------------------------------------------------
% RelTol/AbsTol 控制积分精度；MaxStep 限制最大步长，避免过稀采样影响画图和误差计算。
opts = odeset('RelTol',1e-8,'AbsTol',1e-10,'MaxStep',p.sim.dt);
[t,x] = ode45(@(t,x) HRG_WA_rhs(t,x,p), [0 p.sim.T], x0, opts);

% -------------------------------------------------------------------------
% 5. 预分配输出数组
% -------------------------------------------------------------------------
% N 为 ode45 返回的采样点数量。预分配可以提高 MATLAB 执行效率。
N = length(t);
E = zeros(N,1); Q = zeros(N,1); S = zeros(N,1); R = zeros(N,1);
angle_est = zeros(N,1); rate_est = zeros(N,1); inputOmega = zeros(N,1);
fa = zeros(N,1); fq = zeros(N,1);

% -------------------------------------------------------------------------
% 6. 逐点计算输出量和等效解调变量
% -------------------------------------------------------------------------
for k = 1:N
    % 第四个参数 true 表示在输出变量中加入检测噪声和 ADC 量化误差。
    % 若希望观察理想输出，可改为 false。
    y = HRG_WA_output(t(k), x(k,:).', p, true);

    % 记录解调变量。
    E(k) = y.E; Q(k) = y.Q; S(k) = y.S; R(k) = y.R;

    % 记录由状态直接得到的角度/角速度估计，以及输入角速度。
    angle_est(k) = y.angle_est;
    rate_est(k) = y.rate_est;
    inputOmega(k) = y.inputOmega;

    % 记录控制量。
    fa(k) = y.fa; fq(k) = y.fq;
end

% -------------------------------------------------------------------------
% 7. 从二次解调变量 S/R 独立重构驻波角和输入角
% -------------------------------------------------------------------------
% S/R 对应 sin(4*theta), cos(4*theta)。
% 因此连续驻波角 = unwrap(atan2(S,R))/4。
theta_from_demod = unwrap(atan2(S,R))/4;

% 全角模式输出角：输入转角 = -(驻波角变化量 - 虚拟进动角)/Bryan 因子。
% x(:,6) 为 thetaVirt，即虚拟进动角积分。
angle_from_demod = -(theta_from_demod - theta_from_demod(1) - x(:,6))/p.cBryan;

% 输入角由输入角速度积分得到，作为对比基准。
inputAngle = cumtrapz(t,inputOmega);

% 输出角误差。
angleError = angle_from_demod - inputAngle;

% -------------------------------------------------------------------------
% 8. 打印关键仿真指标
% -------------------------------------------------------------------------
fprintf('Final input angle       = %.3f deg\n', inputAngle(end)*180/pi);
fprintf('Final model angle       = %.3f deg\n', angle_from_demod(end)*180/pi);
fprintf('Final angle error       = %.4f deg\n', angleError(end)*180/pi);
fprintf('RMS angle error         = %.4f deg\n', rms(angleError)*180/pi);
fprintf('Max |Q|                 = %.4g\n', max(abs(Q)));
fprintf('Mean E after 10 s       = %.6f\n', mean(E(t>10)));

% -------------------------------------------------------------------------
% 9. 绘制输入角和全角模式解调输出角
% -------------------------------------------------------------------------
figure('Name','WA-HRG angle output');
plot(t,inputAngle*180/pi,'--','LineWidth',1.0); hold on;
plot(t,angle_from_demod*180/pi,'LineWidth',1.2);
grid on; xlabel('Time / s'); ylabel('Angle / deg');
legend('Input angle','WA-HRG demodulated angle','Location','best');

% -------------------------------------------------------------------------
% 10. 绘制输入角速度和模型角速度输出
% -------------------------------------------------------------------------
figure('Name','WA-HRG rate output');
plot(t,inputOmega*180/pi,'--','LineWidth',1.0); hold on;
plot(t,rate_est*180/pi,'LineWidth',1.0);
grid on; xlabel('Time / s'); ylabel('Angular rate / deg/s');
legend('Input rate','Model rate output','Location','best');

% -------------------------------------------------------------------------
% 11. 绘制能量和正交变量
% -------------------------------------------------------------------------
% E 应在控制作用下稳定在 1 附近；Q 应被正交控制压制到 0 附近。
figure('Name','Energy and quadrature');
plot(t,E,'LineWidth',1.0); hold on;
plot(t,Q,'LineWidth',1.0);
grid on; xlabel('Time / s'); ylabel('Normalized variables');
legend('E','Q','Location','best');

% -------------------------------------------------------------------------
% 12. 绘制控制变量
% -------------------------------------------------------------------------
% fa 为能量补偿控制量，fq 为正交控制量。
figure('Name','Control variables');
plot(t,fa,'LineWidth',1.0); hold on;
plot(t,fq,'LineWidth',1.0);
grid on; xlabel('Time / s'); ylabel('Control variable');
legend('f_a','f_q','Location','best');

% -------------------------------------------------------------------------
% 13. 保存仿真数据
% -------------------------------------------------------------------------
% 保存后可在 MATLAB 中继续分析 Allan 方差、角度误差频谱、参数敏感性等。
save('HRG_WA_demo_result.mat','t','x','E','Q','S','R','inputOmega', ...
     'inputAngle','angle_from_demod','rate_est','fa','fq','p');
