function c=wl_config(stage)
% All circuit values are assumptions until replaced by measured head data.
if nargin<1,stage=5;end
assert(ismember(stage,2:6));
r=fileparts(fileparts(mfilename('fullpath')));addpath(r);
c.stage=stage;c.name=sprintf('hrg_wa_v%d',stage);
c.head=wa_parameters();c.head.Ts=.001;c.head.initialEnergy=1;c.head.initialQuadRatio=0;c.head.rateTau=1/(2*pi*45);
if stage==2,c.head.splitHz=0;c.head.dgamma=0;c.head.duffingHz=0;c.head.detect=eye(2);c.head.detectPhase=[0;0];c.head.drive=eye(2);end
c.fsAdc=40000;c.fsPlant=400000;c.duration=1;c.seed=20261021;
c.massKg=1e-6;c.displacementM=1e-7;c.gapM=5e-6;
c.c0F=1e-12;c.cfF=1e-12;c.rfOhm=1e9;c.biasV=10;
c.cvBandwidthHz=30000;c.pgaBandwidthHz=30000;c.pgaGain=1;
c.cvEnVrtHz=10e-9;c.cvInArtHz=10e-15;c.temperatureK=298.15;
c.pgaNoiseVrtHz=10e-9;c.afeOffsetV=[0;0];c.afeLimitV=1.8;
c.adcBits=18;c.adcFsV=2;c.adcOffsetV=[0;0];c.adcGain=[1;1];
c.adcInlCubic=0;c.jitterRmsS=2e-9;c.channelSkewS=0;c.adcDelay=1;
c.adcArchitecture='nyquist';c.cicStages=3;c.fir=[1 2 3 2 1]/9;
c.dacBits=16;c.dacFsV=2;c.dacDelay=1;c.dacInlCubic=0;
c.dacArchitecture='nyquist';
c.driveNPerV=1e-7;c.driverBandwidthHz=50000;c.driverGain=[1;1];
c.driverSlewVPerS=2e5;c.driverNoiseVrtHz=20e-9;c.driverLimitV=1.8;
c.feedthroughF=0;c.pipelineCtrl=0;c.iqFractionBits=0;c.controlFractionBits=0;
c.antiAliasHz=18000;c.noiseEnable=stage>=3;c.circuitEnable=stage>=3;
c.kalman=stage>=5;c.online=false;c.frp=false;c.calibrationPermit=false;
c.frpSequence=false;c.frpFreeze=false;c.frpTheta=zeros(9,1);
c.matrixApply=false;c.compensationApply=false;c.temperatureCompensate=false;
c.temperatureBiasCoefficients=[0;0;0];c.zeroRateCertified=false;
c.virtualRate=0;c.inputRate=c.head.omega;c.inputFrequencyHz=0;
c.inputRateAmplitude=0;c.temperatureC=25;c.temperatureRampCPerS=0;
c.observers=true;c.spectra=true;c.maxLogPoints=80000;
c.sdmLeak=.9999;c.sdmReferenceV=2;c.tdmEnable=stage>=6;
c.knownPhaseCalibrationRad=0;c.virtualGainCalibration=1;c.learnStartS=.25;
if stage>=4,c.pipelineCtrl=3;c.iqFractionBits=22;c.controlFractionBits=22;end
if stage>=6,c.feedthroughF=2e-15;end
if stage==2
 c.adcBits=0;c.dacBits=0;c.adcDelay=0;c.dacDelay=0;
 c.cvBandwidthHz=inf;c.pgaBandwidthHz=inf;c.antiAliasHz=inf;c.driverBandwidthHz=inf;
end
if stage>=3
 % Frozen nominal design calibration, independently adjustable from actual poles.
 f=c.head.f0;
 c.knownPhaseCalibrationRad=atan(1/(2*pi*f*c.rfOhm*c.cfF))-atan(f/c.cvBandwidthHz) ...
  -atan(f/c.pgaBandwidthHz)-atan(f/c.antiAliasHz)-atan(f/c.driverBandwidthHz) ...
  -2*pi*f*(c.adcDelay+c.dacDelay+.5)/c.fsAdc;
 s=1i*2*pi*f;H=(s*c.rfOhm*c.cfF)/(1+s*c.rfOhm*c.cfF);
 H=H/(1+s/(2*pi*c.cvBandwidthHz))/(1+s/(2*pi*c.pgaBandwidthHz))/(1+s/(2*pi*c.antiAliasHz))/(1+s/(2*pi*c.driverBandwidthHz));
 a=pi*f/c.fsAdc;H=H*sin(a)/a;
 c.virtualGainCalibration=1/abs(H); % Frozen nominal design calibration, not live plant truth.
end
c.measurementStatus='assumed';c.scope='Behavioral circuit interfaces, not transistor or bit-true RTL signoff';
wl_validate(c);
end
