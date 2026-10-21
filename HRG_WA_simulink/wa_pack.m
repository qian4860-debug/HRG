function v = wa_pack(p)
% Fixed interface shared by visible Simulink blocks; indices documented here.
wa_validate_parameters(p);
v = [p.f0;p.gamma;p.dgamma;p.dampingAxis;p.splitHz;p.stiffnessAxis; ... % 1:6
 p.bryan;p.detuningHz;p.duffingHz;p.temperatureCoeff;p.referenceTemperature; ... % 7:11
 p.detect(:);p.detectPhase(:);p.drive(:);p.detectCubic;p.iqBits;p.iqFullScale;1; ... % 12:25 (25 reserved)
 p.energyTarget;p.energyKp;p.energyKi;p.quadKp;p.quadKi;p.pllKp;p.pllKi; ... % 26:32
 p.energyLimit;p.quadLimit;p.pllLimitHz;p.antiWindup;p.loopEnable; ... % 33:37
 p.Ts;p.rateTau;p.energyThreshold;p.angleThreshold]; % 38:41
end
