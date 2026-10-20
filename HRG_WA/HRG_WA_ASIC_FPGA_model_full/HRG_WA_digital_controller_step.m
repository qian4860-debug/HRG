function [uCmd, out, st] = HRG_WA_digital_controller_step(adc, p, st)
% HRG_WA_DIGITAL_CONTROLLER_STEP  One-sample FPGA/ASIC digital control algorithm.
%
% 功能说明：
%   该函数模拟 ASIC/FPGA 内部每个控制采样周期执行的数字逻辑：
%     1. ADC 数据读取；
%     2. 数字增益/偏置标定；
%     3. 定点量化；
%     4. CORDIC atan2 与 4θ 展相；
%     5. 全角输出角和角速度计算；
%     6. 能量环 PI；
%     7. 正交环 PI；
%     8. 状态机/故障检测/状态字更新；
%     9. 输出 fa/fq/virtualRate 控制字。
%
% 输入：
%   adc   4x1 ADC 数字输出浮点等效值 [E;Q;S;R]。
%   p     参数结构体。
%   st    数字控制状态。
%
% 输出：
%   uCmd  3x1 数字控制命令 [fa; fq; virtualRate]。
%   out   输出结构体，含测量值、角度、角速度、状态字和诊断。
%   st    更新后的数字控制状态。

Ts = p.iface.Ts;
st.k = st.k + 1;
st.diag.sampleCount = st.diag.sampleCount + 1;
st.modeTime = st.modeTime + Ts;

% -------------------------------------------------------------------------
% 1. 寄存器总控制和故障注入
% -------------------------------------------------------------------------
if ~p.reg.ctrl_enable
    st.mode = 0; % IDLE
end
if isfinite(p.fault.injectTime) && st.t >= p.fault.injectTime && strcmpi(p.fault.type,'loop_disable')
    st.mode = 0;
end

% -------------------------------------------------------------------------
% 2. 数字标定补偿
% -------------------------------------------------------------------------
E = adc(1); Q = adc(2); S = adc(3); R = adc(4);
if p.cal.enable
    E = p.cal.Egain*(E + p.cal.Eoffset);
    Q = p.cal.Qgain*(Q + p.cal.Qoffset);
    S = p.cal.Sgain*(S + p.cal.Soffset);
    R = p.cal.Rgain*(R + p.cal.Roffset);
end

% -------------------------------------------------------------------------
% 3. 输入测量定点量化
% -------------------------------------------------------------------------
fxSat = false;
if p.fx.enable
    [E, sat] = HRG_WA_fixed_quantize(E, p.fx.measWL, p.fx.measFL, true, p.fx.roundMode); fxSat = fxSat || sat;
    [Q, sat] = HRG_WA_fixed_quantize(Q, p.fx.measWL, p.fx.measFL, true, p.fx.roundMode); fxSat = fxSat || sat;
    [S, sat] = HRG_WA_fixed_quantize(S, p.fx.measWL, p.fx.measFL, true, p.fx.roundMode); fxSat = fxSat || sat;
    [R, sat] = HRG_WA_fixed_quantize(R, p.fx.measWL, p.fx.measFL, true, p.fx.roundMode); fxSat = fxSat || sat;
end

% -------------------------------------------------------------------------
% 4. CORDIC atan2，4θ 相位展开，驻波角估计
% -------------------------------------------------------------------------
phi = atan2(S,R); % 对应 4*theta，范围 [-pi,pi]

% 模拟 CORDIC 角度输出有限位宽。
qPhi = 2*pi/(2^p.cordic.angleBits);
phi = qPhi*round(phi/qPhi);

if st.k == 1
    st.phiPrev = phi;
end
dphi = HRG_WA_wrap_pi(phi - st.phiPrev);
st.phiPrev = phi;

% 连续驻波物理角 theta = unwrap(phi)/4。
st.thetaMeasPrev = st.thetaMeas;
st.thetaMeas = st.thetaMeas + 0.25*dphi;

% 角速度输出：theta_dot = diff(theta)/Ts，输入角速度 = -(theta_dot - virtRate)/cBryan。
thetaRate = (st.thetaMeas - st.thetaMeasPrev)/Ts;
rateRaw = -(thetaRate - st.ctrl.virtRate)/p.cBryan;

% 角度输出：输入转角 = -(theta-theta0-thetaVirt)/cBryan。
% 数字模型中 thetaVirt 由 virtualRate 命令积分实现。
st.angleOut = st.angleOut + rateRaw*Ts;

% 温度补偿和比例因子补偿。
Tnow = p.env.tempFcn(st.t);
scaleTemp = 1.0;
biasTemp = 0.0;
if p.env.enable && p.cal.temperatureEnable
    scaleTemp = 1 + p.env.tempCoeffScale*(Tnow - p.env.T0);
    biasTemp = p.env.tempCoeffBias*(Tnow - p.env.T0);
end
rateRaw = p.cal.scaleFactor*scaleTemp*rateRaw - p.cal.biasRate - biasTemp;

% 简单一阶输出平滑，模拟输出速率寄存器前的低通/平均。
alphaRate = 0.2;
st.rateFilt = (1-alphaRate)*st.rateFilt + alphaRate*rateRaw;
st.rateOut = st.rateFilt;

if p.fx.enable
    [st.angleOut, sat] = HRG_WA_fixed_quantize(st.angleOut, p.fx.angleWL, p.fx.angleFL, true, p.fx.roundMode); fxSat = fxSat || sat;
    [st.rateOut, sat]  = HRG_WA_fixed_quantize(st.rateOut,  p.fx.rateWL,  p.fx.rateFL,  true, p.fx.roundMode); fxSat = fxSat || sat;
end

% -------------------------------------------------------------------------
% 5. 状态机：IDLE / STARTUP / LOCK / RUN / FAULT
% -------------------------------------------------------------------------
% 0=IDLE, 1=STARTUP, 2=LOCK, 3=RUN, 5=FAULT
if st.mode == 0 && p.reg.ctrl_enable
    st.mode = 1;
    st.modeTime = 0;
end

if st.mode == 1 && st.modeTime >= p.fsm.startupTime
    st.mode = 2;
    st.modeTime = 0;
end

if st.mode == 2
    energyOk = abs(E - p.E0) <= p.fsm.energyLockTol*p.E0;
    timeOk = st.modeTime >= p.fsm.lockTime;
    if energyOk && timeOk
        st.mode = 3;
        st.modeTime = 0;
        st.locked = true;
    end
end

% -------------------------------------------------------------------------
% 6. 能量/正交 PI 控制，含限幅和抗积分饱和
% -------------------------------------------------------------------------
eE = p.E0 - E;
eQ = p.Q0 - Q;

fa = 0; fq = 0; virtRate = 0;
if st.mode == 1
    % 启动阶段采用开环补能，避免低幅值下闭环误判。
    fa = p.fsm.startupFa;
    fq = 0;
elseif st.mode == 2 || st.mode == 3
    if p.ctrl.enableDigitalELoop
        iE_try = st.ctrl.iE + eE*Ts;
        [iE_try, iESat] = HRG_WA_clip(iE_try, -p.ctrl.iELimit, p.ctrl.iELimit);
        fa_try = p.ctrl.KpE*eE + p.ctrl.KiE*iE_try;
        [fa, faSat] = HRG_WA_clip(fa_try, -p.ctrl.faLimit, p.ctrl.faLimit);
        if ~(p.ctrl.enableAntiWindup && faSat)
            st.ctrl.iE = iE_try;
        end
        fxSat = fxSat || iESat || faSat;
    end
    if p.ctrl.enableDigitalQLoop
        iQ_try = st.ctrl.iQ + eQ*Ts;
        [iQ_try, iQSat] = HRG_WA_clip(iQ_try, -p.ctrl.iQLimit, p.ctrl.iQLimit);
        fq_try = p.ctrl.KpQ*eQ + p.ctrl.KiQ*iQ_try;
        [fq, fqSat] = HRG_WA_clip(fq_try, -p.ctrl.fqLimit, p.ctrl.fqLimit);
        if ~(p.ctrl.enableAntiWindup && fqSat)
            st.ctrl.iQ = iQ_try;
        end
        fxSat = fxSat || iQSat || fqSat;
    end
    if p.ctrl.enableVirtualRate
        virtRate = p.ctrl.virtualRateFcn(st.t);
    end
end

% 故障状态强制控制为 0。
if st.mode == 5
    fa = 0; fq = 0; virtRate = 0;
end

% 输出控制定点量化。
if p.fx.enable
    [fa, sat] = HRG_WA_fixed_quantize(fa, p.fx.ctrlWL, p.fx.ctrlFL, true, p.fx.roundMode); fxSat = fxSat || sat;
    [fq, sat] = HRG_WA_fixed_quantize(fq, p.fx.ctrlWL, p.fx.ctrlFL, true, p.fx.roundMode); fxSat = fxSat || sat;
end

st.ctrl.fa = fa;
st.ctrl.fq = fq;
st.ctrl.virtRate = virtRate;
uCmd = [fa; fq; virtRate];

% -------------------------------------------------------------------------
% 7. 故障检测与状态字
% -------------------------------------------------------------------------
angleJump = abs(dphi) > pi/2;
EFault = (E < 0.2*p.E0) || (E > 1.8*p.E0);
QFault = abs(Q) > 0.3;

if fxSat, st.diag.fxSatCount = st.diag.fxSatCount + 1; end
if angleJump, st.diag.angleJumpCount = st.diag.angleJumpCount + 1; end
if EFault, st.diag.EFaultCount = st.diag.EFaultCount + 1; end
if QFault, st.diag.QFaultCount = st.diag.QFaultCount + 1; end

if EFault || QFault || angleJump
    st.diag.faultLatched = true;
    if st.mode == 3
        % RUN 阶段出现严重故障则进入 FAULT。
        st.mode = 5;
    end
end

status = uint32(0);
if mod(st.k, p.iface.dataReadyDecim)==0
    status = bitor(status, uint32(1));
    st.diag.dataReadyCount = st.diag.dataReadyCount + 1;
end
if st.locked, status = bitor(status, bitshift(uint32(1),1)); end
if st.diag.adcSatCount>0, status = bitor(status, bitshift(uint32(1),2)); end
if st.diag.dacSatCount>0, status = bitor(status, bitshift(uint32(1),3)); end
if EFault, status = bitor(status, bitshift(uint32(1),4)); end
if QFault, status = bitor(status, bitshift(uint32(1),5)); end
if angleJump, status = bitor(status, bitshift(uint32(1),6)); end
if st.mode==5, status = bitor(status, bitshift(uint32(1),7)); end
st.diag.statusWord = status;

out = struct();
out.E = E; out.Q = Q; out.S = S; out.R = R;
out.phi = phi; out.theta = st.thetaMeas;
out.angle = st.angleOut; out.rate = st.rateOut; out.rateRaw = rateRaw;
out.fa = fa; out.fq = fq; out.virtRate = virtRate;
out.mode = st.mode; out.locked = st.locked; out.statusWord = status;
out.fxSat = fxSat; out.temperature = Tnow;
out.eE = eE; out.eQ = eQ;
end
