function result = HRG_WA_run_coverage_tests()
% HRG_WA_RUN_COVERAGE_TESTS  Functional/performance coverage regression for HRG ASIC/FPGA model.
%
% 功能说明：
%   该函数用于 FPGA 原型和 ASIC 数字控制接口电路前期建模阶段的回归测试。
%   它自动运行多组工况，覆盖理想链路、误差链路、低 ADC 位宽、DAC 饱和、
%   温度变化、故障注入和环路关闭等场景，并输出每组性能指标。
%
% 输出：
%   result  结构体数组，包含 caseName、metrics 和 pass 标志。
%
% 注意：
%   每个 case 默认运行 60 s，全部用 MATLAB 解释执行会花费一定时间。需要快速验证时，
%   可把 p.sim.T 改小，或只运行 run_HRG_WA_ASIC_FPGA_demo.m。

caseNames = { ...
    'ideal_float', ...
    'nominal_fixed_asic', ...
    'adc_14bit_stress', ...
    'dac_saturation_stress', ...
    'temperature_ramp', ...
    'afe_offset_fault', ...
    'loop_disable_fault'};

result = struct('caseName',{},'metrics',{},'pass',{});

for i = 1:length(caseNames)
    rng(10+i);
    p = HRG_WA_params();
    p.reg.mode = uint32(1);
    p.sim.T = 20; % 回归测试缩短到 20 s，提高速度。

    switch caseNames{i}
        case 'ideal_float'
            p.fx.enable = false;
            p.afe.enable = false;
            p.det.enableNoise = false;
            p.adc.bits = 24;
            p.dac.bits = 24;
            p.drive.enable = false;
            p.env.enable = false;
            p.err.dTauInv = 0;
            p.err.dOmega = 0;
        case 'nominal_fixed_asic'
            % 使用默认参数。
        case 'adc_14bit_stress'
            p.adc.bits = 14;
            p.fx.measWL = 18;
            p.fx.measFL = 14;
        case 'dac_saturation_stress'
            p.dac.fullScaleFa = 0.04;
            p.dac.fullScaleFq = 0.04;
            p.ctrl.faLimit = p.dac.fullScaleFa;
            p.ctrl.fqLimit = p.dac.fullScaleFq;
        case 'temperature_ramp'
            p.env.tempFcn = @(t) 25 + 40*t/p.sim.T;
            p.env.tempCoeffScale = 80e-6;
            p.env.tempCoeffBias = 0.05*pi/180/3600;
        case 'afe_offset_fault'
            p.fault.injectTime = 8;
            p.fault.type = 'afe_offset';
            p.fault.magnitude = 0.02;
        case 'loop_disable_fault'
            p.fault.injectTime = 8;
            p.fault.type = 'loop_disable';
            p.fault.magnitude = 0;
    end

    log = local_run_case(p);
    metrics = HRG_WA_performance_metrics(log, p);
    result(i).caseName = caseNames{i}; %#ok<AGROW>
    result(i).metrics = metrics; %#ok<AGROW>
    result(i).pass = metrics.passAll; %#ok<AGROW>

    fprintf('[%02d/%02d] %-24s PASS=%d, RMS angle=%.4f deg, RMS rate=%.4f deg/s, ADC sat=%d, DAC sat=%d\n', ...
        i, length(caseNames), caseNames{i}, metrics.passAll, metrics.rmsAngleErrorDeg, ...
        metrics.rmsRateErrorDps, metrics.adcSatCount, metrics.dacSatCount);
end

save('HRG_WA_coverage_result.mat','result');
end

function log = local_run_case(p)
% LOCAL_RUN_CASE  Compact copy of the digital closed-loop simulation without plotting.
Ts = p.iface.Ts;
t = (0:Ts:p.sim.T).';
N = length(t);
x = [p.E0; 0.01; p.theta0; 0; 0; 0];
st = HRG_WA_digital_init(p);
uAct = [0;0;0];

log.t = t;
log.E = zeros(N,1); log.Q = zeros(N,1); log.S = zeros(N,1); log.R = zeros(N,1);
log.angleOut = zeros(N,1); log.rateOut = zeros(N,1);
log.inputRate = zeros(N,1); log.inputAngle = zeros(N,1);
log.locked = false(N,1); log.statusWord = zeros(N,1,'uint32');
log.diag.adcSatCount = zeros(N,1); log.diag.dacSatCount = zeros(N,1);
log.diag.fxSatCount = zeros(N,1); log.diag.angleJumpCount = zeros(N,1);
log.diag.EFaultCount = zeros(N,1); log.diag.QFaultCount = zeros(N,1);
log.diag.dataReadyCount = zeros(N,1);

for k = 1:N
    tk = t(k);
    st.t = tk;
    Etrue = x(1); Qtrue = x(2); theta = x(3);
    D = sqrt(max(Etrue^2 - Qtrue^2,0));
    idealMeas = [Etrue; Qtrue; D*sin(4*theta); D*cos(4*theta)];
    [adc, st, adcDiag] = HRG_WA_adc_model(idealMeas, p, st);
    if adcDiag.sat, st.diag.adcSatCount = st.diag.adcSatCount + 1; end
    [uCmd, dout, st] = HRG_WA_digital_controller_step(adc, p, st);
    [uAct, st, dacDiag] = HRG_WA_dac_model(uCmd, p, st);
    if dacDiag.sat && st.mode == 3, st.diag.dacSatCount = st.diag.dacSatCount + 1; end

    log.E(k)=Etrue; log.Q(k)=Qtrue; log.S(k)=idealMeas(3); log.R(k)=idealMeas(4);
    log.angleOut(k)=dout.angle; log.rateOut(k)=dout.rate;
    log.inputRate(k)=p.inputOmegaFcn(tk); log.locked(k)=dout.locked; log.statusWord(k)=dout.statusWord;
    log.diag.adcSatCount(k)=st.diag.adcSatCount;
    log.diag.dacSatCount(k)=st.diag.dacSatCount;
    log.diag.fxSatCount(k)=st.diag.fxSatCount;
    log.diag.angleJumpCount(k)=st.diag.angleJumpCount;
    log.diag.EFaultCount(k)=st.diag.EFaultCount;
    log.diag.QFaultCount(k)=st.diag.QFaultCount;
    log.diag.dataReadyCount(k)=st.diag.dataReadyCount;

    if k < N
        rhs = @(tt,xx) HRG_WA_rhs_digital(tt, xx, p, uAct);
        x = HRG_WA_rk4_step(rhs, tk, x, Ts);
        x(1) = max(x(1), p.epsE);
    end
end
log.inputAngle = cumtrapz(log.t, log.inputRate);
end
