function b=w7_budget(c)
% Reproducible SI requirements; allocations are scenarios, not product specs.
if nargin<1,c=w7_config();end
v=c.v7;w=2*pi*c.head.f0;k=1.380649e-23;T=c.temperatureK;
m=c.massKg;A=c.displacementM;Q=c.head.Q;B=c.head.bryan;
b.status=c.measurementStatus;b.omegaRadS=w;b.gammaPerS=w/(2*Q);
b.stiffnessNPerM=m*w*w;b.energyJ=.5*m*w*w*A*A;
b.capacitancePeakF=c.c0F*A/c.gapM;b.currentPeakA=c.biasV*w*b.capacitancePeakF;
s=1i*w;Z=c.rfOhm/(1+s*c.rfOhm*c.cfF);
Hafe=1/(1+s/(2*pi*c.cvBandwidthHz))/(1+s/(2*pi*c.pgaBandwidthHz))/(1+s/(2*pi*c.antiAliasHz));
b.readoutPeakV=b.currentPeakA*abs(Z)*c.pgaGain*abs(Hafe);
b.readoutPhaseRad=angle(s*Z*Hafe);
b.holdForceN=m*w*w*A/Q;b.holdVoltageV=b.holdForceN/c.driveNPerV;
b.startForceN=2*m*w*b.gammaPerS*A/(-expm1(-b.gammaPerS*v.budget.startupTimeS));
b.startVoltageV=b.startForceN/c.driveNPerV;
b.driveDuty=1;if strcmp(v.tdmMode,'switched'),b.driveDuty=v.slotCycles(1)/sum(v.slotCycles);end
b.startSwitchedPeakV=b.startVoltageV/b.driveDuty;
b.noiseGainMagnitude=abs(1+s*(c.c0F+c.cfF)*c.rfOhm)/abs(1+s*c.rfOhm*c.cfF);
b.readoutNoiseVrtHz=sqrt((b.noiseGainMagnitude*c.cvEnVrtHz)^2+abs(Z)^2*(c.cvInArtHz^2+4*k*T/c.rfOhm));
b.totalWhiteNoiseAllowanceVrtHz=2*B*b.readoutPeakV*v.budget.angleRmsRad/sqrt(2*v.budget.noiseBandwidthHz);
delta=2*c.adcFsV/2^c.adcBits;b.adcStepV=delta;
b.adcWhiteAngleRmsRad=delta/(2*B*b.readoutPeakV)*sqrt(v.budget.noiseBandwidthHz/(3*c.fsAdc));
b.adcIdealBitsCeiling=ceil(log2(2*c.adcFsV/(2*B*b.readoutPeakV*v.budget.angleRmsRad)*sqrt(v.budget.noiseBandwidthHz/(3*c.fsAdc))));
b.dacHoldPeakCodes=b.holdVoltageV/(2*c.dacFsV/2^c.dacBits);
b.residualGainMismatchAllowance=4*B*v.budget.angleRmsRad;
b.cicGroupDelayS=c.cicStages*(c.fsAdc*c.head.Ts-1)/(2*c.fsAdc);
b.firGroupDelayS=(numel(c.fir)-1)*c.head.Ts/2;
b.digitalAndConverterDelayS=b.cicGroupDelayS+b.firGroupDelayS+(c.pipelineCtrl+1)*c.head.Ts+(c.adcDelay+c.dacDelay+.5)/c.fsAdc;
b.delay30DegreeCrossoverHz=1/(12*b.digitalAndConverterDelayS);
z=1i*w/c.fsPlant;P=1+z+z^2/2+z^3/6+z^4/24;
b.numericalDampingPerS=-c.fsPlant*log(abs(P));b.numericalDampingFraction=b.numericalDampingPerS/b.gammaPerS;
b.electrostaticVoltageGradientNPerV=2*v.electrostaticForceScale*c.c0F*v.driveBiasV/c.gapM;
b.electrostaticSofteningNPerM=2*v.electrostaticForceScale*c.c0F*v.driveBiasV^2/c.gapM^2;
b.qualifications={'white ADC assumption requires coherent-quantizer tests', ...
 'switched noise needs cyclostationary analysis, not simply 1/duty scaling', ...
 'TIA/charge use the same full transimpedance law in different frequency regimes', ...
 'bandwidth is specified ENBW, not the default chain measured ENBW', ...
 'startup formula is resonant constant-force bound; not capture range', ...
 'phase calibration is frozen nominal, not live truth compensation'};
end
