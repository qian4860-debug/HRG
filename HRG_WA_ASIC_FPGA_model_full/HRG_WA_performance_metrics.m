function m = HRG_WA_performance_metrics(log, p)
% HRG_WA_PERFORMANCE_METRICS  Compute functional/performance indicators.
%
% 功能说明：
%   面向 ASIC 数字控制接口电路和 FPGA 样机验证，本函数从闭环仿真 log 中提取
%   一组应覆盖的功能和性能指标，包括角度误差、角速度误差、能量稳定、正交抑制、
%   数字饱和、锁定时间、状态机状态、数据 ready 计数和 Allan 方差。

idx = log.t > max(1, 0.1*p.sim.T);
if ~any(idx)
    idx = true(size(log.t));
end

angleErr = log.angleOut - log.inputAngle;
rateErr  = log.rateOut - log.inputRate;

m = struct();
m.finalInputAngleDeg = log.inputAngle(end)*180/pi;
m.finalOutputAngleDeg = log.angleOut(end)*180/pi;
m.finalAngleErrorDeg = angleErr(end)*180/pi;
m.rmsAngleErrorDeg = sqrt(mean(angleErr(idx).^2))*180/pi;
m.rmsRateErrorDps = sqrt(mean(rateErr(idx).^2))*180/pi;
m.maxAbsRateErrorDps = max(abs(rateErr(idx)))*180/pi;
m.meanE = mean(log.E(idx));
m.stdE = std(log.E(idx));
m.maxAbsQ = max(abs(log.Q(idx)));
m.lockTime = NaN;
lockIdx = find(log.locked,1,'first');
if ~isempty(lockIdx)
    m.lockTime = log.t(lockIdx);
end
m.adcSatCount = log.diag.adcSatCount(end);
m.dacSatCount = log.diag.dacSatCount(end);
m.fxSatCount = log.diag.fxSatCount(end);
m.angleJumpCount = log.diag.angleJumpCount(end);
m.EFaultCount = log.diag.EFaultCount(end);
m.QFaultCount = log.diag.QFaultCount(end);
m.dataReadyCount = log.diag.dataReadyCount(end);
m.finalStatusWord = log.statusWord(end);

% 用零速段估计零偏和噪声。默认输入 profile 中 0-5s 与 50-60s 为零速。
zeroIdx = abs(log.inputRate) < 1e-12 & log.t > 1;
if any(zeroIdx)
    m.zeroRateBiasDps = mean(log.rateOut(zeroIdx))*180/pi;
    m.zeroRateNoiseStdDps = std(log.rateOut(zeroIdx))*180/pi;
    allan = HRG_WA_allan_dev(log.rateOut(zeroIdx), p.iface.fsCtrl);
    m.allan = allan;
    if ~isempty(allan.adev)
        m.minAllanDps = min(allan.adev)*180/pi;
    else
        m.minAllanDps = NaN;
    end
else
    m.zeroRateBiasDps = NaN;
    m.zeroRateNoiseStdDps = NaN;
    m.allan = struct('tau',[],'adev',[]);
    m.minAllanDps = NaN;
end

% 简单验收判断。
m.passAngleRms = m.rmsAngleErrorDeg <= p.perf.angleRmsLimitDeg;
m.passRateRms = m.rmsRateErrorDps <= p.perf.rateRmsLimitDps;
m.passEnergy = abs(m.meanE - p.E0) <= p.perf.energyMeanTol*p.E0;
m.passQuadrature = m.maxAbsQ <= p.perf.quadratureMaxLimit;
m.passAdcSat = m.adcSatCount <= p.perf.adcSatMax;
m.passDacSat = m.dacSatCount <= p.perf.dacSatMax;
m.passAll = m.passAngleRms && m.passRateRms && m.passEnergy && ...
            m.passQuadrature && m.passAdcSat && m.passDacSat;
end
