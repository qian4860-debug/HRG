function st = HRG_WA_digital_init(p)
% HRG_WA_DIGITAL_INIT  Initialize FPGA/ASIC digital control state.
%
% 功能说明：
%   初始化数字控制器、AFE 延迟线、DAC 延迟线、CORDIC 展相、PI 积分器、状态机、
%   计数器和故障标志。该状态结构体 st 在 run_HRG_WA_ASIC_FPGA_demo.m 的每个
%   控制采样周期中被更新。

st.k = 0;                         % 控制采样计数器。
st.t = 0;                         % 当前时间。
st.mode = double(p.reg.mode);      % 状态机模式。
st.modeTime = 0;                  % 当前模式累计时间。
st.locked = false;                % 闭环锁定标志。

% AFE 一阶低通和延迟线状态。
st.afe.lpf = zeros(4,1);
st.afe.delay = repmat(zeros(4,1), 1, max(1,p.afe.delaySamples+1));

% CORDIC/atan2 连续展开状态。
st.phiPrev = 0;                   % 上一次 atan2(S,R) 输出的 4*theta 相位。
st.thetaMeas = p.theta0;          % 连续驻波角估计。
st.thetaMeasPrev = p.theta0;      % 上一拍驻波角估计。
st.angleOut = 0;                  % 积分角输出，单位 rad。
st.rateOut = 0;                   % 角速度输出，单位 rad/s。
st.rateFilt = 0;                  % 角速度低通滤波状态。

% PI 控制器积分器。
st.ctrl.iE = 0;
st.ctrl.iQ = 0;
st.ctrl.fa = 0;
st.ctrl.fq = 0;
st.ctrl.virtRate = 0;

% DAC/驱动输出延迟线。三路：fa、fq、virtRate。
st.dac.delay = repmat(zeros(3,1), 1, max(1,p.iface.pipelineDelaySamples+1));

% 故障和诊断计数。
st.diag.adcSatCount = 0;
st.diag.dacSatCount = 0;
st.diag.fxSatCount  = 0;
st.diag.angleJumpCount = 0;
st.diag.EFaultCount = 0;
st.diag.QFaultCount = 0;
st.diag.dataReadyCount = 0;
st.diag.sampleCount = 0;
st.diag.statusWord = uint32(0);
st.diag.faultLatched = false;

% 自检状态。
st.selftest.phase = 0;
st.selftest.response = 0;
end
