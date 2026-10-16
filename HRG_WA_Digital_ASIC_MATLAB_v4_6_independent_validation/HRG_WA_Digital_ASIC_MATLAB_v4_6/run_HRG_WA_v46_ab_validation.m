function report = run_HRG_WA_v46_ab_validation(makePlots)
% 训练、oracle真值和验证集三者相互独立；A/B仅改变冻结补偿参数。
if nargin < 1, makePlots = false; end
pTrain = HRG_WA_v46_params();
pTrain.sim.makePlots = false; pTrain.analysis.autoRun = false; pTrain.frp.enable = true;
pTrain.frp.sequenceEnable = true; pTrain.frp.identificationEnable = true;
pTrain.frp.applyFrozenCompensation = false; pTrain.frp.maxCompensationAlpha = 0; % 训练期不允许补偿污染观测。
pTrain.input.rateFcn = @(t) 0*t; pTrain.sim.seed = 46101;
truth = HRG_WA_v46_compute_frp_truth(pTrain);
train = HRG_WA_v46_simulate(pTrain);
thetaOnline = train.frpFinal.thetaHat;

pVal = HRG_WA_v46_params();
pVal.sim.duration = 14; pVal.sim.seed = 46201; pVal.sim.makePlots = false; pVal.analysis.autoRun = false;
pVal.res.thetaInitial = 31*pi/180;
pVal.env.temperatureFcn = @(t) 8 + 37*min(max((t-1)/12,0),1);
pVal.input.rateFcn = @(t) ((t>=2 & t<5)*7 + (t>=5 & t<9)*(-11) + (t>=9)*16)*pi/180;
pVal.frp.enable = true; pVal.frp.sequenceEnable = false; pVal.frp.identificationEnable = false;
pVal.frp.applyFrozenCompensation = true; pVal.frp.initialCompensationAlpha = 1; pVal.frp.maxCompensationAlpha = 1;
pA = pVal; pA.frp.initialThetaHat = zeros(9,1);
pB = pVal; pB.frp.initialThetaHat = thetaOnline;
A = HRG_WA_v46_simulate(pA); B = HRG_WA_v46_simulate(pB);
mask = A.log.mode == 3 & A.log.t >= 3 & ~A.log.frpActive;
errorA = A.log.compensatedRate(mask)-A.log.inputRate(mask); errorB = B.log.compensatedRate(mask)-B.log.inputRate(mask);
report.oracleTruth = truth; report.onlineTheta = thetaOnline; report.onlineThetaDps = thetaOnline*180/pi;
report.truthErrorRmsDps = sqrt(mean(((thetaOnline-truth.theta)*180/pi).^2));
report.validation.scenario = 'unseen seed, 31 deg initial angle, 8..45 C ramp, nonzero piecewise rates';
report.validation.sampleCount = sum(mask); report.validation.rmsOffDps = sqrt(mean(errorA.^2))*180/pi; report.validation.rmsOnDps = sqrt(mean(errorB.^2))*180/pi;
report.validation.improvementFraction = 1-report.validation.rmsOnDps/max(report.validation.rmsOffDps,eps);
report.validation.maxCorrectionOffDps = max(abs(A.log.frpCorrectionDps(mask))); report.validation.maxCorrectionOnDps = max(abs(B.log.frpCorrectionDps(mask)));
report.validation.maxOutputDifferenceDps = max(abs((B.log.compensatedRate(mask)-A.log.compensatedRate(mask))*180/pi));
report.validation.compensationPathActive = report.validation.maxCorrectionOnDps > 1e-6 && report.validation.maxOutputDifferenceDps > 1e-6;
report.validation.minimumImprovementFraction = 0.05; % 独立验证至少改善百分之五，拒绝把数值噪声当成有效补偿。
report.validation.pass = report.validation.compensationPathActive && report.validation.improvementFraction >= report.validation.minimumImprovementFraction;
report.noDataLeakage = train.params.sim.seed ~= truth.seed && pVal.sim.seed ~= train.params.sim.seed && ~pVal.frp.identificationEnable;
fprintf('FRP oracle residual=%.6g deg/s, online truth RMS=%.6g deg/s\n', truth.residualRmsDps, report.truthErrorRmsDps);
fprintf('Independent A/B: OFF=%.6g deg/s, ON=%.6g deg/s, improvement=%+.2f%%, corrON=%.6g deg/s, path=%d, PASS=%d\n', report.validation.rmsOffDps, report.validation.rmsOnDps, 100*report.validation.improvementFraction, report.validation.maxCorrectionOnDps, report.validation.compensationPathActive, report.validation.pass);
if makePlots
    figure('Name','V4.6 independent FRP A/B');
    plot(A.log.t(mask),errorA*180/pi,'Color',[.55 .55 .55]); hold on; plot(B.log.t(mask),errorB*180/pi,'b'); grid on;
    xlabel('Time (s)'); ylabel('rate error (deg/s)'); legend('A: frozen correction OFF','B: frozen correction ON');
end
end
