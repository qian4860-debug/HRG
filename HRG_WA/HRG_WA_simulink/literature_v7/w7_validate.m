function w7_validate(c)
wl_validate(c);v=c.v7;
assert(ismember(v.controlMode,{'PI','PIR'}));
assert(ismember(v.tdmMode,{'continuous','switched'}));
assert(ismember(v.actuationMode,{'linear','electrostatic'}));
assert(v.acquisitionTauS>0&&v.unloadTauS>0&&v.sampleCapF>0);
assert(numel(v.slotCycles)==4&&all(v.slotCycles>0)&&all(v.slotCycles==fix(v.slotCycles)));
assert(v.readBlankCycles>=0&&v.readBlankCycles<v.slotCycles(3));
assert(v.startupAmplitudePerS>0&&v.startupSwitchEnergy>0&&v.startupSwitchEnergy<c.head.energyTarget);
assert(v.startupTimeoutS>0&&v.resonantLeakRadS>0&&v.frequencyEstimateTauS>0);
assert(v.resonantMinimumRadS>0&&v.resonantMaximumRadS>v.resonantMinimumRadS);
assert(numel(v.resonantGain)==3&&all(v.resonantGain>=0));
assert(v.driveBiasV>0&&v.electrostaticForceScale>0);
assert(c.head.gamma>abs(c.head.dgamma)/2,'Damping matrix must be positive definite');
if strcmp(v.tdmMode,'switched')
 N=c.fsPlant/c.head.f0;F=sum(v.slotCycles)/c.head.f0;
 assert(abs(N-round(N))<1e-9,'TDM requires integer plant ticks per nominal carrier cycle');
 assert(abs(c.head.Ts/F-round(c.head.Ts/F))<1e-9,'Control frame must contain whole TDM frames');
 assert(abs(v.readBlankCycles*N-round(v.readBlankCycles*N))<1e-9,'Blank interval must align to plant ticks');
 assert(v.slotCycles(3)/c.head.f0>v.acquisitionTauS*5,'Read slot too short to settle');
end
end
