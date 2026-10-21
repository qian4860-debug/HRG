function wl_validate(c)
assert(mod(c.fsAdc,1/c.head.Ts)==0 && mod(c.fsPlant,c.fsAdc)==0,'Integer clock ratios required');
assert(c.fsAdc>4*c.head.f0 && c.fsPlant>=20*c.head.f0,'Carrier sampling margin is inadequate');
assert(c.gapM>5*c.displacementM && c.massKg>0 && c.driveNPerV>0,'Invalid assumed head interface scales');
assert(c.rfOhm>0 && c.cfF>0 && c.c0F>0 && c.biasV>0,'Invalid C/V parameters');
assert(c.adcBits==0 || (c.adcBits>=2 && c.adcBits<=24),'Invalid ADC bits');
assert(c.dacBits==0 || (c.dacBits>=2 && c.dacBits<=24),'Invalid DAC bits');
assert(c.jitterRmsS*2*pi*c.head.f0<.05,'First-order jitter model requires small phase perturbations');
assert(ismember(c.adcArchitecture,{'nyquist','sigma_delta'}));
assert(ismember(c.dacArchitecture,{'nyquist','sigma_delta'}));
assert(c.pipelineCtrl>=0 && c.pipelineCtrl==fix(c.pipelineCtrl));
assert(c.duration>0 && c.head.Ts>0);
end
