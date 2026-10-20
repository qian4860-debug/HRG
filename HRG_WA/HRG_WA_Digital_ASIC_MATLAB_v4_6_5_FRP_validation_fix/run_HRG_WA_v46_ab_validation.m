function report = run_HRG_WA_v46_ab_validation(makePlots)
% 训练、oracle真值和验证集相互独立；A/B/C分别采用关闭、在线RLS和oracle冻结参数。
if nargin < 1, makePlots = false; end
pTrain = HRG_WA_v46_params();
pTrain.sim.makePlots = false; pTrain.analysis.autoRun = false; pTrain.frp.enable = true;
pTrain.frp.sequenceEnable = true; pTrain.frp.identificationEnable = true;
pTrain.frp.applyFrozenCompensation = false; pTrain.frp.maxCompensationAlpha = 0; % 训练期不允许补偿污染观测。
pTrain.frp.rlsLambda = 1.0; % 验证入口显式锁定无遗忘RLS，防止用户配置或旧参数文件重新覆盖。
pTrain.sim.duration = 28; pTrain.frp.forwardDps = 30; pTrain.frp.reverseDps = -30;
pTrain.frp.dwellSec = 12; pTrain.frp.transitionSec = 0.25; pTrain.frp.cycleCount = 1;
pTrain.input.rateFcn = @(t) 0*t; pTrain.sim.seed = 46101;
pTrain.env.temperatureFcn = @(t) 30 + 14*sin(2*pi*0.173*(t-2)+0.37); % 非同步温度往复激励使正反向平台都覆盖16至44摄氏度，避免温度与扫描方向共线。
pTrain = local_observable_frp_scenario(pTrain); % 使用独立验证可观测但仍处于接口小非理想范围的确定性检测误差。
truth = HRG_WA_v46_compute_frp_truth(pTrain);
train = HRG_WA_v46_simulate(pTrain);
assert(abs(train.params.frp.rlsLambda-1.0) <= eps, 'FRP训练实际遗忘因子不是1，参数可能被旧用户配置覆盖。');
assert(train.metrics.frpCoverageFraction >= 0.70 && truth.angleCoverageFraction >= 0.70, 'FRP训练或oracle角度覆盖不足，禁止用局部角扫参数执行独立整圆验证。');
thetaOnline = train.frpFinal.thetaHat;
trainCandidateMask = train.log.frpStable & train.log.mode == 3 & train.log.phaseValid & isfinite(train.log.compensatedRate) & abs(train.log.inputRate) <= 0.01*pi/180;
trainCandidateIndices = find(trainCandidateMask); trainUpdateIndices = trainCandidateIndices(1:max(round(train.params.frp.updateDecimation),1):end);
trainTheta = train.log.thetaEstimate(trainUpdateIndices); trainScanRate = train.log.kalmanThetaRate(trainUpdateIndices);
trainPhi = HRG_WA_v46_frp_basis(trainTheta, train.log.temperature(trainUpdateIndices), trainScanRate, train.params);
trainY = train.log.compensatedRate(trainUpdateIndices)-train.log.inputRate(trainUpdateIndices);
priorPrecision = eye(9)/train.params.frp.rlsDelta; % P0=delta*I对应批量正规方程中的P0逆先验。
thetaBatchTrain = (trainPhi'*trainPhi+priorPrecision)\(trainPhi'*trainY); % 使用与RLS完全相同的抽取样本、顺序无关正规方程和先验正则。
assert(numel(trainUpdateIndices)==train.frpFinal.updateCount, 'RLS等价批量样本数与在线更新计数不一致。');

pVal = HRG_WA_v46_params();
pVal.sim.duration = 14; pVal.sim.seed = 46201; pVal.sim.makePlots = false; pVal.analysis.autoRun = false;
pVal.res.thetaInitial = 31*pi/180;
pVal.env.temperatureFcn = @(t) 18 + 24*min(max((t-1)/12,0),1); % 使用训练温区内不同起点和斜率，检验插值泛化而非混入大范围外推误差。
pVal.input.rateFcn = @(t) ((t>=2 & t<5)*7 + (t>=5 & t<9)*(-11) + (t>=9)*16)*pi/180;
pVal.frp.enable = true; pVal.frp.sequenceEnable = false; pVal.frp.identificationEnable = false;
pVal.frp.applyFrozenCompensation = true; pVal.frp.initialCompensationAlpha = 1; pVal.frp.maxCompensationAlpha = 1;
pVal = local_observable_frp_scenario(pVal); % 验证保持同一器件误差，随机种子、初始角、温度轨迹和运动工况均独立。
pA = pVal; pA.frp.initialThetaHat = zeros(9,1);
pB = pVal; pB.frp.initialThetaHat = thetaOnline;
pC = pVal; pC.frp.initialThetaHat = truth.theta;
A = HRG_WA_v46_simulate(pA); B = HRG_WA_v46_simulate(pB); C = HRG_WA_v46_simulate(pC);
fullMask = A.log.mode == 3 & A.log.t >= 3 & ~A.log.frpActive;
mask = fullMask; settlingSec = 0.75; rateStepTimes = [5 9]; % 2秒阶跃已被t>=3自然排除；后续阶跃按显示/估计动态稳定时间剔除。
for i = 1:numel(rateStepTimes)
    mask = mask & ~(A.log.t >= rateStepTimes(i) & A.log.t < rateStepTimes(i)+settlingSec);
end
assert(sum(mask)>100, '独立验证稳态窗口样本不足。');
errorA = A.log.compensatedRate(mask)-A.log.inputRate(mask); errorB = B.log.compensatedRate(mask)-B.log.inputRate(mask); errorC = C.log.compensatedRate(mask)-C.log.inputRate(mask);
fullErrorA = A.log.compensatedRate(fullMask)-A.log.inputRate(fullMask); fullErrorB = B.log.compensatedRate(fullMask)-B.log.inputRate(fullMask); fullErrorC = C.log.compensatedRate(fullMask)-C.log.inputRate(fullMask);

% 零速独立验证用于评价九参数加性零偏/谐波模型本身；另加负oracle参数直接检查补偿符号。
pZero = pVal; pZero.sim.duration = 12; pZero.sim.seed = 46202; pZero.res.thetaInitial = 67*pi/180;
pZero.env.temperatureFcn = @(t) 20 + 20*min(max((t-1)/10,0),1); pZero.input.rateFcn = @(t) 0*t;
pZero.virtual.enable = true; pZero.virtual.amplitudeDps = 38; pZero.virtual.frequencyHz = 0.04; pZero.virtual.phaseRad = -0.314; % 在3至12秒形成约280度单向独立角扫，同时保持在40度每秒DAC量程内。
pZeroA = pZero; pZeroA.frp.initialThetaHat = zeros(9,1);
pZeroB = pZero; pZeroB.frp.initialThetaHat = thetaOnline;
pZeroC = pZero; pZeroC.frp.initialThetaHat = truth.theta;
pZeroD = pZero; pZeroD.frp.initialThetaHat = -truth.theta;
zeroA = HRG_WA_v46_simulate(pZeroA); zeroB = HRG_WA_v46_simulate(pZeroB); zeroC = HRG_WA_v46_simulate(pZeroC); zeroD = HRG_WA_v46_simulate(pZeroD);
zeroMask = zeroA.log.mode == 3 & zeroA.log.t >= 3 & ~zeroA.log.frpActive;
assert(sum(zeroMask)>100, '零速独立验证有效样本不足。');
zeroErrorA = zeroA.log.compensatedRate(zeroMask)-zeroA.log.inputRate(zeroMask); zeroErrorB = zeroB.log.compensatedRate(zeroMask)-zeroB.log.inputRate(zeroMask);
zeroErrorC = zeroC.log.compensatedRate(zeroMask)-zeroC.log.inputRate(zeroMask); zeroErrorD = zeroD.log.compensatedRate(zeroMask)-zeroD.log.inputRate(zeroMask);
report.oracleTruth = truth; report.onlineTheta = thetaOnline; report.onlineThetaDps = thetaOnline*180/pi;
report.actualRlsLambda = train.params.frp.rlsLambda;
report.truthErrorRmsDps = sqrt(mean(((thetaOnline-truth.theta)*180/pi).^2));
report.batchTrainingThetaDps = thetaBatchTrain*180/pi; report.batchTrainingTruthErrorRmsDps = sqrt(mean(((thetaBatchTrain-truth.theta)*180/pi).^2));
report.onlineVsBatchRmsDps = sqrt(mean(((thetaOnline-thetaBatchTrain)*180/pi).^2));
report.equivalentBatchSampleCount = numel(trainUpdateIndices); report.onlineUpdateCount = train.frpFinal.updateCount;
report.onlineVsBatchMaxAbsDps = max(abs((thetaOnline-thetaBatchTrain)*180/pi));
report.maximumEquivalentBatchErrorDps = 0.01; report.rlsEquivalentPass = report.onlineVsBatchRmsDps <= report.maximumEquivalentBatchErrorDps;
report.validation.scenario = 'unseen seed, 31 deg initial angle, 18..42 C in-domain ramp, nonzero piecewise rates, 0.75 s post-step exclusion';
report.validation.sampleCount = sum(mask); report.validation.settlingExclusionSec = settlingSec;
report.validation.rmsOffDps = sqrt(mean(errorA.^2))*180/pi; report.validation.rmsOnlineDps = sqrt(mean(errorB.^2))*180/pi; report.validation.rmsOracleDps = sqrt(mean(errorC.^2))*180/pi;
report.validation.fullWindowRmsOffDps = sqrt(mean(fullErrorA.^2))*180/pi; report.validation.fullWindowRmsOnlineDps = sqrt(mean(fullErrorB.^2))*180/pi; report.validation.fullWindowRmsOracleDps = sqrt(mean(fullErrorC.^2))*180/pi;
report.validation.rmsOnDps = report.validation.rmsOnlineDps; % 保留V4.6.1字段名兼容既有分析脚本。
report.validation.improvementFraction = 1-report.validation.rmsOnDps/max(report.validation.rmsOffDps,eps);
report.validation.oracleImprovementFraction = 1-report.validation.rmsOracleDps/max(report.validation.rmsOffDps,eps);
[biasOffDps, rateLevelsDps] = local_plateau_bias_rms(A.log.compensatedRate(mask)-A.log.inputRate(mask), A.log.inputRate(mask));
[biasOnlineDps, ~] = local_plateau_bias_rms(B.log.compensatedRate(mask)-B.log.inputRate(mask), B.log.inputRate(mask));
[biasOracleDps, ~] = local_plateau_bias_rms(C.log.compensatedRate(mask)-C.log.inputRate(mask), C.log.inputRate(mask));
report.validation.rateLevelsDps = rateLevelsDps;
report.validation.systematicBiasRmsOffDps = biasOffDps;
report.validation.systematicBiasRmsOnlineDps = biasOnlineDps;
report.validation.systematicBiasRmsOracleDps = biasOracleDps;
report.validation.systematicImprovementFraction = 1-biasOnlineDps/max(biasOffDps,eps);
report.validation.systematicOracleImprovementFraction = 1-biasOracleDps/max(biasOffDps,eps);
report.validation.maxCorrectionOffDps = max(abs(A.log.frpCorrectionDps(mask))); report.validation.maxCorrectionOnDps = max(abs(B.log.frpCorrectionDps(mask)));
report.validation.maxCorrectionOracleDps = max(abs(C.log.frpCorrectionDps(mask)));
report.validation.maxOutputDifferenceDps = max(abs((B.log.compensatedRate(mask)-A.log.compensatedRate(mask))*180/pi));
report.validation.compensationPathActive = report.validation.maxCorrectionOnDps > 1e-6 && report.validation.maxOutputDifferenceDps > 1e-6;
report.validation.oraclePathActive = report.validation.maxCorrectionOracleDps > 1e-6;
report.validation.minimumImprovementFraction = 0.05; % 零速加性模型仍以全样本RMS至少改善百分之五验收。
report.validation.minimumSystematicImprovementFraction = 0.05; % 非零速率用各稳态平台均值的RMS评价可标定系统误差，避免宽带随机噪声掩盖补偿效果。
report.validation.maximumRmsDegradationFraction = 0.01; % 同时要求全样本RMS不得恶化超过百分之一，防止仅优化均值而放大噪声。
report.validation.nonzeroNavigationOraclePass = report.validation.oraclePathActive && report.validation.systematicOracleImprovementFraction >= report.validation.minimumSystematicImprovementFraction && report.validation.rmsOracleDps <= (1+report.validation.maximumRmsDegradationFraction)*report.validation.rmsOffDps;
report.validation.nonzeroNavigationOnlinePass = report.validation.compensationPathActive && report.validation.systematicImprovementFraction >= report.validation.minimumSystematicImprovementFraction && report.validation.rmsOnlineDps <= (1+report.validation.maximumRmsDegradationFraction)*report.validation.rmsOffDps;
report.validation.nonzeroNavigationPass = report.validation.nonzeroNavigationOraclePass && report.validation.nonzeroNavigationOnlinePass;

report.validation.zeroRate.rmsOffDps = sqrt(mean(zeroErrorA.^2))*180/pi;
report.validation.zeroRate.rmsOnlineDps = sqrt(mean(zeroErrorB.^2))*180/pi;
report.validation.zeroRate.rmsOracleDps = sqrt(mean(zeroErrorC.^2))*180/pi;
report.validation.zeroRate.rmsOracleNegativeDps = sqrt(mean(zeroErrorD.^2))*180/pi;
report.validation.zeroRate.onlineImprovementFraction = 1-report.validation.zeroRate.rmsOnlineDps/max(report.validation.zeroRate.rmsOffDps,eps);
report.validation.zeroRate.oracleImprovementFraction = 1-report.validation.zeroRate.rmsOracleDps/max(report.validation.zeroRate.rmsOffDps,eps);
report.validation.zeroRate.oracleNegativeImprovementFraction = 1-report.validation.zeroRate.rmsOracleNegativeDps/max(report.validation.zeroRate.rmsOffDps,eps);
report.validation.zeroRate.maxCorrectionOnlineDps = max(abs(zeroB.log.frpCorrectionDps(zeroMask)));
report.validation.zeroRate.maxCorrectionOracleDps = max(abs(zeroC.log.frpCorrectionDps(zeroMask)));
report.validation.zeroRate.maxCorrectionOracleNegativeDps = max(abs(zeroD.log.frpCorrectionDps(zeroMask)));
report.validation.zeroRate.oraclePathActive = report.validation.zeroRate.maxCorrectionOracleDps > 1e-6;
report.validation.zeroRate.onlinePathActive = report.validation.zeroRate.maxCorrectionOnlineDps > 1e-6;
zeroDesiredCorrectionDps = -zeroErrorA*180/pi; zeroOracleCorrectionDps = zeroC.log.frpCorrectionDps(zeroMask); zeroOnlineCorrectionDps = zeroB.log.frpCorrectionDps(zeroMask);
report.validation.zeroRate.oracleCorrelation = local_correlation(zeroDesiredCorrectionDps, zeroOracleCorrectionDps);
report.validation.zeroRate.onlineCorrelation = local_correlation(zeroDesiredCorrectionDps, zeroOnlineCorrectionDps);
report.validation.zeroRate.signSeparationFraction = abs(report.validation.zeroRate.rmsOracleDps-report.validation.zeroRate.rmsOracleNegativeDps)/max(report.validation.zeroRate.rmsOffDps,eps);
report.validation.zeroRate.minimumSignSeparationFraction = 0.01; report.validation.zeroRate.minimumCorrelation = 0.20;
report.validation.zeroRate.signSignificant = report.validation.zeroRate.signSeparationFraction >= report.validation.zeroRate.minimumSignSeparationFraction;
report.validation.zeroRate.signCorrect = report.validation.zeroRate.signSignificant && report.validation.zeroRate.rmsOracleDps < report.validation.zeroRate.rmsOracleNegativeDps;
zeroTheta = mod(zeroA.log.thetaEstimate(zeroMask),2*pi); zeroBins = false(36,1); zeroBinIndex = min(floor(zeroTheta/(2*pi)*36)+1,36); zeroBins(unique(zeroBinIndex)) = true;
report.validation.zeroRate.angleCoverageFraction = mean(zeroBins);
report.validation.zeroRate.oracleModelPass = report.validation.zeroRate.oraclePathActive && report.validation.zeroRate.signCorrect && report.validation.zeroRate.oracleCorrelation >= report.validation.zeroRate.minimumCorrelation && report.validation.zeroRate.oracleImprovementFraction >= report.validation.minimumImprovementFraction;
report.validation.zeroRate.onlineEstimatorPass = report.validation.zeroRate.onlinePathActive && report.validation.zeroRate.onlineCorrelation >= report.validation.zeroRate.minimumCorrelation && report.validation.zeroRate.onlineImprovementFraction >= report.validation.minimumImprovementFraction;
report.validation.oracleModelPass = report.validation.zeroRate.oracleModelPass; % 九参数加性模型的基础验收以零速独立场景为准。
report.validation.onlineEstimatorPass = report.validation.zeroRate.onlineEstimatorPass;
report.validation.pass = report.rlsEquivalentPass && report.validation.oracleModelPass && report.validation.onlineEstimatorPass && report.validation.nonzeroNavigationPass;
if ~report.rlsEquivalentPass
    report.validation.failureCause = 'online RLS recursion differs from equivalent batch LS';
elseif ~report.validation.zeroRate.signSignificant
    report.validation.failureCause = 'oracle sign indeterminate; correction is weakly correlated with validation error';
elseif ~report.validation.zeroRate.signCorrect && report.validation.zeroRate.oracleNegativeImprovementFraction >= report.validation.minimumImprovementFraction
    report.validation.failureCause = 'oracle compensation sign inversion';
elseif ~report.validation.oracleModelPass
    report.validation.failureCause = 'zero-rate oracle model/time-alignment/generalization failure';
elseif ~report.validation.onlineEstimatorPass
    report.validation.failureCause = 'online RLS parameter estimation failure';
elseif ~report.validation.nonzeroNavigationPass
    report.validation.failureCause = 'nonzero-rate systematic bias is not improved or broadband RMS is degraded';
else
    report.validation.failureCause = 'none';
end
report.noDataLeakage = train.params.sim.seed ~= truth.seed && pVal.sim.seed ~= train.params.sim.seed && pZero.sim.seed ~= pVal.sim.seed && pZero.sim.seed ~= train.params.sim.seed && ~pVal.frp.identificationEnable && ~pZero.frp.identificationEnable;
fprintf('FRP lambda=%.6g, oracle residual=%.6g deg/s, online truth RMS=%.6g deg/s, batch truth RMS=%.6g deg/s, online-batch RMS=%.6g deg/s\n', report.actualRlsLambda, truth.residualRmsDps, report.truthErrorRmsDps, report.batchTrainingTruthErrorRmsDps, report.onlineVsBatchRmsDps);
fprintf('RLS equivalence: updates=%d/%d, maxAbs=%.6g deg/s\n', report.onlineUpdateCount, report.equivalentBatchSampleCount, report.onlineVsBatchMaxAbsDps);
fprintf('Independent A/B/C steady: OFF=%.6g, ONLINE=%.6g (%+.2f%%), ORACLE=%.6g (%+.2f%%) deg/s, corrOnline=%.6g, paths=%d/%d, NAVPASS=%d\n', report.validation.rmsOffDps, report.validation.rmsOnlineDps, 100*report.validation.improvementFraction, report.validation.rmsOracleDps, 100*report.validation.oracleImprovementFraction, report.validation.maxCorrectionOnDps, report.validation.compensationPathActive, report.validation.oraclePathActive, report.validation.nonzeroNavigationPass);
fprintf('Nonzero systematic plateau bias RMS: OFF=%.6g, ONLINE=%.6g (%+.2f%%), ORACLE=%.6g (%+.2f%%) deg/s\n', report.validation.systematicBiasRmsOffDps, report.validation.systematicBiasRmsOnlineDps, 100*report.validation.systematicImprovementFraction, report.validation.systematicBiasRmsOracleDps, 100*report.validation.systematicOracleImprovementFraction);
fprintf('Zero-rate A/B/C/D: OFF=%.6g, ONLINE=%.6g (%+.2f%%), ORACLE+=%.6g (%+.2f%%), ORACLE-=%.6g (%+.2f%%) deg/s, sign=%d, PASS=%d\n', report.validation.zeroRate.rmsOffDps, report.validation.zeroRate.rmsOnlineDps, 100*report.validation.zeroRate.onlineImprovementFraction, report.validation.zeroRate.rmsOracleDps, 100*report.validation.zeroRate.oracleImprovementFraction, report.validation.zeroRate.rmsOracleNegativeDps, 100*report.validation.zeroRate.oracleNegativeImprovementFraction, report.validation.zeroRate.signCorrect, report.validation.pass);
fprintf('Zero-rate diagnostics: coverage=%.3f, signSeparation=%.3f%%, corrOracle=%+.4f, corrOnline=%+.4f\n', report.validation.zeroRate.angleCoverageFraction, 100*report.validation.zeroRate.signSeparationFraction, report.validation.zeroRate.oracleCorrelation, report.validation.zeroRate.onlineCorrelation);
fprintf('Failure classification: %s\n', report.validation.failureCause);
if makePlots
    figure('Name','V4.6.5 independent FRP validation');
    subplot(2,1,1);
    plot(A.log.t(mask),errorA*180/pi,'Color',[.55 .55 .55]); hold on; plot(B.log.t(mask),errorB*180/pi,'b'); plot(C.log.t(mask),errorC*180/pi,'r'); grid on;
    xlabel('Time (s)'); ylabel('rate error (deg/s)'); title('Nonzero-rate navigation validation'); legend('A: correction OFF','B: online RLS','C: oracle');
    subplot(2,1,2);
    plot(zeroA.log.t(zeroMask),zeroErrorA*180/pi,'Color',[.55 .55 .55]); hold on; plot(zeroB.log.t(zeroMask),zeroErrorB*180/pi,'b'); plot(zeroC.log.t(zeroMask),zeroErrorC*180/pi,'r'); plot(zeroD.log.t(zeroMask),zeroErrorD*180/pi,'m'); grid on;
    xlabel('Time (s)'); ylabel('rate error (deg/s)'); title('Zero-rate additive harmonic and sign validation'); legend('OFF','online RLS','oracle +','oracle -');
end
end

function [biasRmsDps, rateLevelsDps] = local_plateau_bias_rms(errorRad, inputRateRad)
% 按独立稳态转速平台计算均值误差RMS，分离可标定系统误差与宽带随机噪声。
rateLevelsRad = unique(inputRateRad(:));
plateauBiasRad = zeros(size(rateLevelsRad));
for i = 1:numel(rateLevelsRad)
    plateauBiasRad(i) = mean(errorRad(inputRateRad == rateLevelsRad(i)));
end
biasRmsDps = sqrt(mean(plateauBiasRad.^2))*180/pi;
rateLevelsDps = rateLevelsRad*180/pi;
end

function p = local_observable_frp_scenario(p)
% 构造幅值受限且可由独立角扫辨识的检测链确定性误差；不改变控制器、噪声或验收门限。
p.afe.crossMatrix = [1.020 0.015; -0.012 0.980];
p.afe.assemblyAngleRad = 0.45*pi/180;
p.afe.phaseDelayRad = [0.35; -0.28]*pi/180;
p.afe.gainTempCoeff = [140; -110]*1e-6;
p.afe.phaseTempCoeffRad = [30; -25]*1e-6;
p.afe.quadraticNonlinearity = [0.0012; -0.0010];
p.afe.cubicNonlinearity = [0.0006; -0.0005];
end

function value = local_correlation(a,b)
% 无需Statistics Toolbox的有限样本Pearson相关系数。
a = a(:); b = b(:); valid = isfinite(a) & isfinite(b); a = a(valid); b = b(valid);
if numel(a)<3, value = NaN; return; end
a = a-mean(a); b = b-mean(b); denominator = sqrt(sum(a.^2)*sum(b.^2));
if denominator<=eps, value = 0; else, value = sum(a.*b)/denominator; end
end
