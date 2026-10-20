function truth = HRG_WA_v46_compute_frp_truth(baseParameters)
% 用独立、无噪声、无在线补偿的oracle数据集生成九维FRP参数参考真值。
if nargin < 1 || isempty(baseParameters)
    baseParameters = HRG_WA_v46_params();
end
p = baseParameters;
p.sim.seed = baseParameters.sim.seed + 7919;
p.sim.makePlots = false; p.analysis.autoRun = false;
p.afe.noiseSigma(:) = 0; p.dac.noiseSigma(:) = 0;
p.res.phaseNoiseRad = 0; p.res.processEnergyNoise = 0; p.res.processQuadNoise = 0; p.res.processThetaNoise = 0;
p.adc.enableDither = false; p.frp.enable = true; p.frp.sequenceEnable = true;
p.frp.identificationEnable = false; p.frp.applyFrozenCompensation = false; p.frp.initialThetaHat = zeros(9,1);
p.frp.initialCompensationAlpha = 0; p.frp.maxCompensationAlpha = 0;
p.advanced.physicalFrp.enable = false; p.advanced.phaseSelfCal.enable = false; p.advanced.nonlinearityCorrection.enable = false;
r = HRG_WA_v46_simulate(p);
mask = r.log.frpStable & r.log.mode == 3 & isfinite(r.log.compensatedRate);
theta = r.log.thetaEstimate(mask); dT = (r.log.temperature(mask)-p.env.referenceTemperature)/20; direction = r.log.frpDirection(mask);
Phi = [ones(sum(mask),1), sin(4*theta), cos(4*theta), sin(8*theta), cos(8*theta), dT, dT.*sin(4*theta), dT.*cos(4*theta), direction];
y = r.log.compensatedRate(mask) - r.log.inputRate(mask);
assert(size(Phi,1) >= 9 && rank(Phi) >= 8, 'FRP oracle数据的秩或样本数不足。');
ridge = 1e-12 * trace(Phi'*Phi)/9;
truth.theta = (Phi'*Phi + ridge*eye(9)) \ (Phi'*y);
truth.thetaDps = truth.theta * 180/pi;
truth.residualRmsDps = sqrt(mean((y-Phi*truth.theta).^2))*180/pi;
truth.conditionNumber = cond(Phi'*Phi + ridge*eye(9));
truth.sampleCount = size(Phi,1); truth.seed = p.sim.seed;
truth.definition = 'independent noise-free oracle batch LS; online RLS and validation data are not used';
truth.physical = r.metrics.advanced;
end
