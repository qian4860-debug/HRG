function m = HRG_WA_performance_metrics(log, p)
% HRG_WA_PERFORMANCE_METRICS  Compute functional/performance indicators.
%
% 功能说明：
%   面向 ASIC 数字控制接口电路和 FPGA 样机验证，本函数从闭环仿真 log 中提取
%   一组应覆盖的功能和性能指标，包括角度误差、角速度误差、能量稳定、正交抑制、
%   数字饱和、锁定时间、状态机状态、数据 ready 计数和 Allan 方差。
%
% 修改说明：
%   角速度输出由角度差分得到，理想阶跃输入的切换时刻会因为一拍延迟、
%   CORDIC/滤波流水线和速率低通产生瞬态尖峰。该尖峰用于观察动态响应，
%   但不应作为稳态速率 RMS 性能判据。因此这里把性能统计窗口分成：
%       idxAngle   ：角度、能量、正交等导航性能统计窗口；
%       idxRate    ：速率 RMS/最大误差稳态统计窗口，额外排除阶跃边沿；
%       zeroIdx    ：零速噪声/Allan 统计窗口，排除锁定前和阶跃后过渡。

% -------------------------------------------------------------------------
% 1. 锁定时间和基础统计窗口
% -------------------------------------------------------------------------
lockIdx = find(log.locked,1,'first');
if ~isempty(lockIdx)
    lockTime = log.t(lockIdx);
else
    lockTime = NaN;
end

postLockIgnore = 0;
if isfield(p,'perf') && isfield(p.perf,'postLockIgnoreTime')
    postLockIgnore = p.perf.postLockIgnoreTime;
end

% 角度/能量/正交默认只评价进入 RUN 且滤波器建立后的数据。
if ~isnan(lockTime)
    idxAngle = log.locked & (log.t > lockTime + postLockIgnore);
else
    idxAngle = log.t > max(1, 0.1*p.sim.T);
end
if ~any(idxAngle)
    idxAngle = log.t > max(1, 0.1*p.sim.T);
end
if ~any(idxAngle)
    idxAngle = true(size(log.t));
end

% 速率稳态指标在 idxAngle 基础上排除默认输入 profile 的阶跃切换边沿。
idxRate = idxAngle;
if isfield(p,'perf') && isfield(p.perf,'rateStepTimes') && isfield(p.perf,'rateStepExcludeWindow')
    for ii = 1:numel(p.perf.rateStepTimes)
        idxRate = idxRate & abs(log.t - p.perf.rateStepTimes(ii)) > p.perf.rateStepExcludeWindow;
    end
end
if ~any(idxRate)
    idxRate = idxAngle;
end

% -------------------------------------------------------------------------
% 2. 误差计算
% -------------------------------------------------------------------------
angleErr = log.angleOut - log.inputAngle;
rateErr  = log.rateOut - log.inputRate;

m = struct();
m.finalInputAngleDeg = log.inputAngle(end)*180/pi;
m.finalOutputAngleDeg = log.angleOut(end)*180/pi;
m.finalAngleErrorDeg = angleErr(end)*180/pi;
m.rmsAngleErrorDeg = sqrt(mean(angleErr(idxAngle).^2))*180/pi;
m.rmsRateErrorDps = sqrt(mean(rateErr(idxRate).^2))*180/pi;
m.maxAbsRateErrorDps = max(abs(rateErr(idxRate)))*180/pi;
m.maxAbsRateErrorAllDps = max(abs(rateErr(idxAngle)))*180/pi;
m.meanE = mean(log.E(idxAngle));
m.stdE = std(log.E(idxAngle));
m.maxAbsQ = max(abs(log.Q(idxAngle)));
m.lockTime = lockTime;
m.adcSatCount = log.diag.adcSatCount(end);
m.dacSatCount = log.diag.dacSatCount(end);
m.fxSatCount = log.diag.fxSatCount(end);
m.angleJumpCount = log.diag.angleJumpCount(end);
m.EFaultCount = log.diag.EFaultCount(end);
m.QFaultCount = log.diag.QFaultCount(end);
m.dataReadyCount = log.diag.dataReadyCount(end);
m.finalStatusWord = log.statusWord(end);

% -------------------------------------------------------------------------
% 3. 零速噪声和 Allan deviation
% -------------------------------------------------------------------------
% 零速段必须排除锁定前以及速率阶跃后的滤波过渡，否则会把输出滤波器的
% 过渡响应误判为零速噪声。
zeroIdx = abs(log.inputRate) < 1e-12;
if ~isnan(lockTime)
    zeroIdx = zeroIdx & log.locked & (log.t > lockTime + postLockIgnore);
else
    zeroIdx = zeroIdx & (log.t > 1);
end
if isfield(p,'perf') && isfield(p.perf,'rateStepTimes') && isfield(p.perf,'rateStepExcludeWindow')
    for ii = 1:numel(p.perf.rateStepTimes)
        zeroIdx = zeroIdx & abs(log.t - p.perf.rateStepTimes(ii)) > p.perf.rateStepExcludeWindow;
    end
end

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

% -------------------------------------------------------------------------
% 4. 验收判断
% -------------------------------------------------------------------------
m.passAngleRms = m.rmsAngleErrorDeg <= p.perf.angleRmsLimitDeg;
m.passRateRms = m.rmsRateErrorDps <= p.perf.rateRmsLimitDps;
m.passEnergy = abs(m.meanE - p.E0) <= p.perf.energyMeanTol*p.E0;
m.passQuadrature = m.maxAbsQ <= p.perf.quadratureMaxLimit;
m.passAdcSat = m.adcSatCount <= p.perf.adcSatMax;
m.passDacSat = m.dacSatCount <= p.perf.dacSatMax;
m.passAll = m.passAngleRms && m.passRateRms && m.passEnergy && ...
            m.passQuadrature && m.passAdcSat && m.passDacSat;
end
