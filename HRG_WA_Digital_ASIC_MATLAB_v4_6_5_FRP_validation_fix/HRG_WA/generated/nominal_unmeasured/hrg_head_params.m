function [p,u] = hrg_head_params(mode)
% Generated head profile. Add the model directory and this folder to MATLAB path.
% mode=rtl disables algorithms outside the implemented RTL boundary.
if nargin<1, mode='rtl'; end
assert(any(strcmp(mode,{'rtl','model'})), 'mode must be rtl or model');
u = HRG_WA_v46_user_config();
u.res.f0 = 5000;
u.res.Q = 2000000;
u.res.bryan = 0.27700000000000002;
u.res.energyTarget = 1;
u.res.energyInitial = 0.25;
u.res.quadInitial = 0.014999999999999999;
u.res.thetaInitialDeg = 8;
u.res.dampingAnisotropy = 0.00025000000000000001;
u.res.dampingAxisDeg = 17;
u.res.frequencySplitHz = 0.0080000000000000002;
u.res.stiffnessAxisDeg = 41;
u.res.duffingHzPerEnergy = 0.014999999999999999;
u.afe.crossMatrix = [1 0.0030000000000000001; -0.002 1];
u.afe.offset = [0.00080000000000000004; -0.00050000000000000001];
u.afe.phaseDelayDeg = [0; 0];
u.drive.crossMatrix = [1 0; 0 1];
u.dac.gain = [1; 0.995; 1.002];
u.dac.offset = [0.00020000000000000001; -0.00020000000000000001; 0];
u.ctrl.energyKp = 2.3999999999999999;
u.ctrl.energyKi = 0.34999999999999998;
u.ctrl.quadKp = 7;
u.ctrl.quadKi = 1.3999999999999999;
u.sim.fsAdc = 40000;
u.sim.fsCtrl = 1000;
u.asic.pipelineDelayCtrl = 3;
u.ctrl.energyLimit = 0.55000000000000004;
u.ctrl.quadLimit = 0.45000000000000001;
u.ctrl.integratorLimit = 1.5;
u.ctrl.energySlewPerSec = 2;
u.ctrl.quadSlewPerSec = 4;
u.ctrl.energyBackCalculationGain = 3;
u.ctrl.quadBackCalculationGain = 8;
u.ctrl.actuatorTrackingGain = 10;
u.ctrl.slewTrackingGain = 10;
u.ctrl.startupDrive = 0.34999999999999998;
u.ctrl.startupTime = 0.25;
u.ctrl.acquireTime = 0.5;
u.ctrl.energyLockTolerance = 0.080000000000000002;
u.ctrl.quadLockTolerance = 0.029999999999999999;
u.pll.kpHz = 8;
u.pll.kiHz = 35;
u.pll.integratorLimitHz = 800;
u.pll.frequencyLimitHz = 1200;
u.pll.backCalculationGain = 12;
u.pll.lockPhaseError = 0.025000000000000001;
u.pll.energyValidThreshold = 0.080000000000000002;
u.asic.phaseValidThreshold = 0.080000000000000002;
u.dac.fullScaleEnergy = 0.59999999999999998;
u.dac.fullScaleQuad = 0.5;
u.dac.fullScaleVirtualDps = 40;
u.asic.unwrapLimit = 2.5132741228718345;
u.ctrl.rateLpfHz = 45;
u.virtual.enable = false;
u.virtual.amplitudeDps = 0;
u.virtual.frequencyHz = 0;
u.virtual.phaseRad = 1.5707963267948966;
u.asic.bitTrueEnable = true;
u.tune.autoApply = false;
if strcmp(mode,'rtl')
 u.kalman.enable=false; u.calib.enable=false; u.frp.enable=false;
 u.comp.enableHarmonic=false; u.comp.enableTemperature=false; u.selftest.enable=false;
end
p = HRG_WA_v46_params(u);
p.meta.headId = 'nominal_unmeasured';
p.meta.headConfigurationSha256 = '8d4d1a44d9dca199cc0b88f42a6e488e34de158c1a740d38e4fcd8cf2563a161';
% SPI uses the rounded values below; real model gains above retain physical units.
p.head.spiWords = uint32([157286 22938 458752 91750 16777216 0 536870912 65884 0 297426485 264448425]);
p.head.energyHold = 0.015707969665527344;
p.head.quadHold = 0;
p.head.enableMask = 63;
p.head.measurementStatus = 'assumed';
end
