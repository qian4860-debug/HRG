function c=w7_config(profile,overrides)
% V7 is an additive branch; accepted V2--V6 sources and models are unchanged.
r=fileparts(mfilename('fullpath'));addpath(r,fullfile(fileparts(r),'layered'));
if nargin<1||isempty(profile),profile=fullfile(r,'profile.json');end
v=jsondecode(fileread(profile));
if nargin>=2
 for k=fieldnames(overrides).',assert(isfield(v,k{1}),'Unknown V7 field: %s',k{1});v.(k{1})=overrides.(k{1});end
end
c=wl_config(5);c.v7=v;c.v7.profile=profile;
c.head=wa_parameters(fullfile(fileparts(fileparts(r)),v.mechanicalProfile));
for k=fieldnames(v.headSimulation).',assert(isfield(c.head,k{1}));c.head.(k{1})=v.headSimulation.(k{1});end
for k=fieldnames(v.circuit).',assert(isfield(c,k{1}));c.(k{1})=v.circuit.(k{1});end
c.fir=c.fir(:)';c.inputRate=c.head.omega;
c.name='hrg_wa_v7_carrier';c.fsPlant=v.fsPlant;c.duration=v.duration;
c.tdmEnable=false; % Never stack the historical V6 drive-only gating.
c.rfOhm=v.(v.readoutMode).rfOhm;c.cfF=v.(v.readoutMode).cfF;c.pgaGain=v.(v.readoutMode).pgaGain;
c.head.energyLimit=20;c.head.quadLimit=2;
wn=2*pi*v.loopNaturalHz(:);zeta=v.dampingRatio;
c.head.energyKp=zeta*wn(1)/c.head.energyTarget;c.head.energyKi=wn(1)^2/(2*c.head.energyTarget);
c.head.quadKp=zeta*wn(2);c.head.quadKi=wn(2)^2/2;
c.head.pllKp=zeta*wn(3)/pi;c.head.pllKi=wn(3)^2/(2*pi);
% These are fixed nominal-design calibrations, never recomputed from plant truth.
s=2i*pi*c.head.f0;
H=(s*c.rfOhm*c.cfF)/(1+s*c.rfOhm*c.cfF);
H=H/(1+s/(2*pi*c.cvBandwidthHz))/(1+s/(2*pi*c.pgaBandwidthHz))/(1+s/(2*pi*c.antiAliasHz));
H=H*exp(-s*c.adcDelay/c.fsAdc);
if strcmp(v.tdmMode,'switched')
 alpha=1-exp(-1/(c.fsPlant*v.acquisitionTauS));
 H=H*alpha/(1-(1-alpha)*exp(-s/c.fsPlant));
end
c.v7.senseCalibration=1/H;
% Feedback h is expressed in measured NCO coordinates: rotate ONLY the sense path.
% Driver phase is handled explicitly by a fixed nominal actuator inverse.
a=pi*c.head.f0/c.fsAdc;
Hd=sin(a)/a*exp(-s*(c.dacDelay+.5)/c.fsAdc)/(1+s/(2*pi*c.driverBandwidthHz));
c.v7.driveCalibration=1/Hd;
c.knownPhaseCalibrationRad=0;c.virtualGainCalibration=1;
c.v7.nominalGram=eye(2)/2;
if strcmp(v.tdmMode,'switched')
 N=round(c.fsAdc*c.head.Ts);ta=(0:N-1)'/c.fsAdc;mask=zeros(N,1);
 for j=1:N,g=w7_switches(ta(j),c);mask(j)=g(4);end
 ph=2*pi*c.head.f0*(ta+c.adcDelay/c.fsAdc);
 b=[cos(ph),-sin(ph)];c.v7.nominalGram=b'*(mask.*b)/N;
 assert(rcond(c.v7.nominalGram)>.1,'Read window cannot resolve both quadratures');
end
c.measurementStatus=v.status;w7_validate(c);
end
