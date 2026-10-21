function c=wl_setup(c)
if nargin<1,c=wl_config(5);end
wl_validate(c);root=fileparts(mfilename('fullpath'));addpath(root,fileparts(root),fullfile(root,'legacy'));
legacyRoot=fullfile(fileparts(fileparts(root)),'HRG_WA_Digital_ASIC_MATLAB_v4_6_5_FRP_validation_fix');addpath(legacyRoot);
p=c.head;p.drive=eye(2);p.detect=eye(2);p.detectPhase=[0;0];p.detectCubic=0;p.iqBits=0;
pv=wa_pack(p);z=wa_initial(p);w=2*pi*p.f0;
detectGain=c.biasV*c.c0F/c.gapM*c.displacementM/c.cfF*c.pgaGain;
forceGain=c.driveNPerV/(c.massKg*c.displacementM);
Ad=[cos(4*p.dampingAxis) sin(4*p.dampingAxis);sin(4*p.dampingAxis) -cos(4*p.dampingAxis)];
Ak=[cos(4*p.stiffnessAxis) sin(4*p.stiffnessAxis);sin(4*p.stiffnessAxis) -cos(4*p.stiffnessAxis)];
wn=2*pi*(p.f0+p.detuningHz+p.f0*p.temperatureCoeff*(c.temperatureC-25));
v.wl_D=2*p.gamma*eye(2)+p.dgamma*Ad;v.wl_K=wn^2*eye(2)-wn*2*pi*p.splitHz*Ak;
v.wl_J=[0 -1;1 0];v.wl_c=c;v.wl_p=pv;v.wl_q0=real(z);v.wl_v0=-w*imag(z);
v.wl_Ta=1/c.fsAdc;v.wl_Tp=1/c.fsPlant;v.wl_Tc=p.Ts;v.wl_stop=c.duration;
v.wl_detectGain=detectGain;v.wl_forceGain=forceGain;v.wl_hToV=2*w/forceGain;
v.wl_R=round(c.fsAdc*p.Ts);v.wl_boxcar=ones(1,v.wl_R)/v.wl_R;v.wl_fir=c.fir;
v.wl_cvTau=c.rfOhm*c.cfF;v.wl_mass=c.massKg;v.wl_scale=c.displacementM;
v.wl_cvGain=c.biasV/c.cfF;
% Independent, specified white sources. One-sided ASD -> discrete sample RMS.
k=1.380649e-23;f=p.f0;zf=c.rfOhm/sqrt(1+(2*pi*f*v.wl_cvTau)^2);
noiseGain=(c.c0F+c.cfF)/c.cfF;
c.cvEquivalentNoiseVrtHz=sqrt((noiseGain*c.cvEnVrtHz)^2+zf^2*(c.cvInArtHz^2+4*k*c.temperatureK/c.rfOhm));
v.wl_cvNoiseVariance=(c.noiseEnable*c.cvEquivalentNoiseVrtHz)^2*c.fsPlant/2;
v.wl_pgaNoiseVariance=(c.noiseEnable*c.pgaNoiseVrtHz)^2*c.fsPlant/2;
v.wl_driverNoiseVariance=(c.noiseEnable*c.driverNoiseVrtHz)^2*c.fsPlant/2;
v.wl_jitterVariance=(c.noiseEnable*c.jitterRmsS)^2;
v.wl_brownVariance=4*k*c.temperatureK*(2*p.gamma*c.massKg)*c.fsPlant/2/(c.massKg*c.displacementM)^2*c.noiseEnable;
lp=HRG_WA_v46_params();lp.sim.TsCtrl=p.Ts;lp.sim.fsCtrl=1/p.Ts;
lp.res.f0=p.f0;lp.res.bryan=p.bryan;lp.res.energyTarget=p.energyTarget;
lp.kalman.enable=c.kalman;lp.calib.enable=c.online;lp.calib.startTime=c.learnStartS;
lp.frp.enable=c.frp;lp.frp.sequenceEnable=c.frpSequence;lp.frp.startTime=c.learnStartS;
lp.frp.forwardDps=120;lp.frp.reverseDps=-120;lp.frp.dwellSec=12;lp.frp.cycleCount=1;
lp.frp.initialThetaHat=c.frpTheta;lp.frp.applyFrozenCompensation=c.frpFreeze;
lp.frp.identificationEnable=~c.frpFreeze;lp.calib.maxCompensationAlpha=.1;
lp.calib.compensationStartUpdates=500;lp.calib.compensationRampUpdates=1000;
c.legacyP=lp;v.wl_c=c;
for field=fieldnames(v).',assignin('base',field{1},v.(field{1}));end
end
