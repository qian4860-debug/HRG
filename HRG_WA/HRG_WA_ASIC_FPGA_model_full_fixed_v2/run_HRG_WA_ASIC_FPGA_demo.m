%% run_HRG_WA_ASIC_FPGA_demo
% 半球谐振陀螺全角模式 ASIC/FPGA 数字控制接口电路闭环仿真主脚本。
%
% 与 run_HRG_WA_demo.m 的区别：
%   run_HRG_WA_demo.m 主要验证全角模式慢变量机理；
%   本脚本进一步加入面向样机和 ASIC 的数字接口链路，包括：
%       1. AFE 检测前端增益/偏置/噪声/带宽/延迟；
%       2. ADC 位宽、量化、满量程和饱和；
%       3. 数字标定、定点量化、CORDIC atan2 和 4θ 展相；
%       4. 能量环、正交环、虚拟进动通道；
%       5. DAC/驱动位宽、延迟、噪声、饱和；
%       6. 寄存器配置、状态机、状态字和故障计数；
%       7. 性能指标统计和验收判断。
%
% 运行方式：
%   在 MATLAB 当前目录切换到本文件所在目录后，直接运行：
%       run_HRG_WA_ASIC_FPGA_demo

clear; clc; close all;
rng(2); % 固定随机数种子，便于复现实验结果。

% -------------------------------------------------------------------------
% 1. 参数初始化
% -------------------------------------------------------------------------
p = HRG_WA_params();

% 数字闭环从 STARTUP 状态开始，模拟上电后的启动、锁定、运行过程。
p.reg.mode = uint32(1);

% 使用固定步长，便于与 FPGA/ASIC 控制周期对齐。
Ts = p.iface.Ts;
t = (0:Ts:p.sim.T).';
N = length(t);

% 状态向量保持与原模型兼容：x = [E; Q; theta; iE; iQ; thetaVirt]
x = [p.E0; 0.01; p.theta0; 0; 0; 0];
st = HRG_WA_digital_init(p);

% -------------------------------------------------------------------------
% 2. 日志预分配
% -------------------------------------------------------------------------
log = struct();
log.t = t;
log.x = zeros(N,6);
log.E = zeros(N,1); log.Q = zeros(N,1); log.S = zeros(N,1); log.R = zeros(N,1);
log.adcE = zeros(N,1); log.adcQ = zeros(N,1); log.adcS = zeros(N,1); log.adcR = zeros(N,1);
log.angleOut = zeros(N,1); log.rateOut = zeros(N,1);
log.inputRate = zeros(N,1); log.inputAngle = zeros(N,1);
log.faCmd = zeros(N,1); log.fqCmd = zeros(N,1); log.virtCmd = zeros(N,1);
log.faAct = zeros(N,1); log.fqAct = zeros(N,1); log.virtAct = zeros(N,1);
log.mode = zeros(N,1); log.locked = false(N,1); log.statusWord = zeros(N,1,'uint32');
log.temperature = zeros(N,1);
log.diag.adcSatCount = zeros(N,1);
log.diag.dacSatCount = zeros(N,1);
log.diag.fxSatCount = zeros(N,1);
log.diag.angleJumpCount = zeros(N,1);
log.diag.EFaultCount = zeros(N,1);
log.diag.QFaultCount = zeros(N,1);
log.diag.dataReadyCount = zeros(N,1);

% 初始 DAC 输出为 0。
uAct = [0;0;0];

% -------------------------------------------------------------------------
% 3. 固定采样周期闭环仿真
% -------------------------------------------------------------------------
for k = 1:N
    tk = t(k);
    st.t = tk;

    % 3.1 由真实慢变量合成理想 E/Q/S/R。实际系统中这些变量来自 x/y 检测解调。
    Etrue = x(1);
    Qtrue = x(2);
    thetatrue = x(3);
    D = sqrt(max(Etrue^2 - Qtrue^2, 0));
    Strue = D*sin(4*thetatrue);
    Rtrue = D*cos(4*thetatrue);
    idealMeas = [Etrue; Qtrue; Strue; Rtrue];

    % 3.2 AFE + ADC 行为模型。
    [adc, st, adcDiag] = HRG_WA_adc_model(idealMeas, p, st);
    if adcDiag.sat
        st.diag.adcSatCount = st.diag.adcSatCount + 1;
    end

    % 3.3 数字控制器：标定、定点、CORDIC、状态机、PI 控制、状态字。
    [uCmd, dout, st] = HRG_WA_digital_controller_step(adc, p, st);

    % 3.4 DAC + 驱动接口模型。
    [uAct, st, dacDiag] = HRG_WA_dac_model(uCmd, p, st);
    if dacDiag.sat && st.mode == 3
        % 只把 RUN 阶段的 DAC 饱和计入性能故障。STARTUP/LOCK 阶段的
        % 开环补能和滤波建立可能产生短暂限幅，应作为启动瞬态而非运行故障。
        st.diag.dacSatCount = st.diag.dacSatCount + 1;
    end

    % 3.5 记录当前采样点。
    log.x(k,:) = x.';
    log.E(k) = Etrue; log.Q(k) = Qtrue; log.S(k) = Strue; log.R(k) = Rtrue;
    log.adcE(k) = adc(1); log.adcQ(k) = adc(2); log.adcS(k) = adc(3); log.adcR(k) = adc(4);
    log.angleOut(k) = dout.angle;
    log.rateOut(k) = dout.rate;
    log.inputRate(k) = p.inputOmegaFcn(tk);
    log.faCmd(k) = uCmd(1); log.fqCmd(k) = uCmd(2); log.virtCmd(k) = uCmd(3);
    log.faAct(k) = uAct(1); log.fqAct(k) = uAct(2); log.virtAct(k) = uAct(3);
    log.mode(k) = dout.mode; log.locked(k) = dout.locked; log.statusWord(k) = dout.statusWord;
    log.temperature(k) = dout.temperature;
    log.diag.adcSatCount(k) = st.diag.adcSatCount;
    log.diag.dacSatCount(k) = st.diag.dacSatCount;
    log.diag.fxSatCount(k) = st.diag.fxSatCount;
    log.diag.angleJumpCount(k) = st.diag.angleJumpCount;
    log.diag.EFaultCount(k) = st.diag.EFaultCount;
    log.diag.QFaultCount(k) = st.diag.QFaultCount;
    log.diag.dataReadyCount(k) = st.diag.dataReadyCount;

    % 3.6 用 DAC 实际输出驱动 HRG 慢变量 plant。
    if k < N
        rhs = @(tt,xx) HRG_WA_rhs_digital(tt, xx, p, uAct);
        x = HRG_WA_rk4_step(rhs, tk, x, Ts);
        x(1) = max(x(1), p.epsE); % 数值保护：能量不能为负。
    end
end

% 输入角积分作为参考基准。
log.inputAngle = cumtrapz(log.t, log.inputRate);

% -------------------------------------------------------------------------
% 4. 性能统计与保存
% -------------------------------------------------------------------------
metrics = HRG_WA_performance_metrics(log, p);
HRG_WA_print_metrics(metrics);

reg = HRG_WA_regmap(p);
save('HRG_WA_ASIC_FPGA_result.mat','log','metrics','p','reg');

% -------------------------------------------------------------------------
% 5. 绘图：角度、角速度、能量/正交、控制量、数字状态
% -------------------------------------------------------------------------
figure('Name','ASIC/FPGA WA-HRG angle output');
plot(log.t, log.inputAngle*180/pi, '--','LineWidth',1.0); hold on;
plot(log.t, log.angleOut*180/pi, 'LineWidth',1.1);
grid on; xlabel('Time / s'); ylabel('Angle / deg');
legend('Input angle','Digital output angle','Location','best');

figure('Name','ASIC/FPGA WA-HRG rate output');
plot(log.t, log.inputRate*180/pi, '--','LineWidth',1.0); hold on;
plot(log.t, log.rateOut*180/pi, 'LineWidth',1.0);
grid on; xlabel('Time / s'); ylabel('Angular rate / deg/s');
legend('Input rate','Digital rate output','Location','best');

figure('Name','ASIC/FPGA angle and rate error');
subplot(2,1,1);
plot(log.t, (log.angleOut-log.inputAngle)*180/pi, 'LineWidth',1.0);
grid on; xlabel('Time / s'); ylabel('Angle error / deg');
subplot(2,1,2);
plot(log.t, (log.rateOut-log.inputRate)*180/pi, 'LineWidth',1.0);
grid on; xlabel('Time / s'); ylabel('Rate error / deg/s');

figure('Name','ASIC/FPGA energy and quadrature');
plot(log.t, log.E, 'LineWidth',1.0); hold on;
plot(log.t, log.Q, 'LineWidth',1.0);
grid on; xlabel('Time / s'); ylabel('Normalized variables');
legend('E true','Q true','Location','best');

figure('Name','ASIC/FPGA control interface');
plot(log.t, log.faCmd, 'LineWidth',1.0); hold on;
plot(log.t, log.fqCmd, 'LineWidth',1.0);
plot(log.t, log.faAct, '--','LineWidth',1.0);
plot(log.t, log.fqAct, '--','LineWidth',1.0);
grid on; xlabel('Time / s'); ylabel('Control value');
legend('fa cmd','fq cmd','fa actual','fq actual','Location','best');

figure('Name','ASIC/FPGA status and temperature');
subplot(3,1,1);
stairs(log.t, log.mode, 'LineWidth',1.0); grid on;
ylabel('FSM mode'); xlabel('Time / s');
subplot(3,1,2);
plot(log.t, double(log.statusWord), 'LineWidth',1.0); grid on;
ylabel('Status word'); xlabel('Time / s');
subplot(3,1,3);
plot(log.t, log.temperature, 'LineWidth',1.0); grid on;
ylabel('Temperature / degC'); xlabel('Time / s');

if ~isempty(metrics.allan.tau)
    figure('Name','ASIC/FPGA Allan deviation from zero-rate segments');
    loglog(metrics.allan.tau, metrics.allan.adev*180/pi, 'o-','LineWidth',1.0);
    grid on; xlabel('\tau / s'); ylabel('Allan deviation / deg/s');
end
