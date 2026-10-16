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
p.adc.enableDither = false; p.adc.jitterRms = 0; p.frp.enable = true; p.frp.sequenceEnable = true;
p.frp.identificationEnable = false; p.frp.applyFrozenCompensation = false; p.frp.initialThetaHat = zeros(9,1);
p.frp.initialCompensationAlpha = 0; p.frp.maxCompensationAlpha = 0;
p.advanced.physicalFrp.enable = false; p.advanced.phaseSelfCal.enable = false; p.advanced.nonlinearityCorrection.enable = false;
r = HRG_WA_v46_simulate(p);
mask = r.log.frpStable & r.log.mode == 3 & isfinite(r.log.compensatedRate);
theta = r.log.thetaEstimate(mask); scanRate = r.log.kalmanThetaRate(mask);
Phi = HRG_WA_v46_frp_basis(theta, r.log.temperature(mask), scanRate, p);
y = r.log.compensatedRate(mask) - r.log.inputRate(mask);
designRank = rank(Phi);
assert(size(Phi,1) >= 9 && designRank == 9, 'FRP oracle数据未达到九参数满列秩，不能定义唯一参数真值。');
ridge = 1e-12 * trace(Phi'*Phi)/9;
truth.theta = (Phi'*Phi + ridge*eye(9)) \ (Phi'*y);
truth.thetaDps = truth.theta * 180/pi;
truth.residualRmsDps = sqrt(mean((y-Phi*truth.theta).^2))*180/pi;
truth.conditionNumber = cond(Phi'*Phi + ridge*eye(9));
truth.sampleCount = size(Phi,1); truth.designRank = designRank; truth.seed = p.sim.seed;
truthBins = false(36,1); truthAngles = mod(theta,2*pi); truthBinIndex = min(floor(truthAngles/(2*pi)*36)+1,36); truthBins(unique(truthBinIndex)) = true;
truth.angleCoverageFraction = mean(truthBins);
truth.definition = 'independent noise-free full-angle oracle batch LS with unified scan-rate basis; online RLS and validation data are not used';
truth.physical = r.metrics.advanced;
end
