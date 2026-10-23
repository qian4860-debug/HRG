function report=w7_run_validation()
% Actual runs; no fitting away angle drift and no inherited paper performance.
r=fileparts(mfilename('fullpath'));addpath(r);folder=fullfile(r,'evidence');
if ~isfolder(folder),mkdir(folder);end
cleanup=onCleanup(@()bdclose('all')); %#ok<NASGU>
unit=w7_validate_scoreboards();cases=struct('name',{},'metrics',{},'finite',{});
for k=1:4
 opt=struct('startupEnable',false);
 if k==2,opt.tdmMode='switched';end
 if k==3,opt.readoutMode='tia';end
 if k==4,opt.actuationMode='electrostatic';end
 c=w7_config([],opt);c.duration=.08;c.noiseEnable=false;c.observers=false;c.spectra=false;
 if k==4,c.duration=1.5;end
 c.name=sprintf('hrg_wa_v7_case%d',k);[out,c]=w7_sim(c,false);
 m=w7_metrics(out,c);names={'continuous','switched','tia','electrostatic'};
 cases(end+1)=struct('name',names{k},'metrics',m,'finite',m.finite); %#ok<AGROW>
 export(out,c,names{k});close_system(c.name,0);
end
% Actual zero-state startup, independent of demodulator fill-up.
c=w7_config();c.duration=2;c.noiseEnable=false;c.observers=false;c.spectra=false;
c.head.initialEnergy=0;c.head.initialQuadRatio=0;c.inputRate=0;c.head.splitHz=0;c.head.dgamma=0;c.head.duffingHz=0;
c.head.detect=eye(2);c.head.drive=eye(2);c.name='hrg_wa_v7_cold_start';
[out,c]=w7_sim(c,false);b=wl_acceptance_budget(c);b.buildTolerance=.05;b.holdS=.05;
m=w7_metrics(out,c,b);cases(end+1)=struct('name','zero_state_startup','metrics',m,'finite',m.finite);
export(out,c,'zero_state_startup');close_system(c.name,0);
% PI/PIR: same public-input controller and same mechanical/AFE model.
pair=struct;
for mode={'PI','PIR'}
 c=w7_config([],struct('controlMode',mode{1},'startupEnable',false));
 c.duration=40;c.noiseEnable=false;c.adcBits=0;c.dacBits=0;c.iqFractionBits=0;c.controlFractionBits=0;
 c.head.detect=eye(2);c.head.drive=eye(2);c.head.dgamma=.004;c.head.splitHz=.08;c.head.duffingHz=0;
 c.name=['hrg_wa_v7_' lower(mode{1})];name=w7_envelope(c,false);out=sim(name);
 iq=out.tap_iq;z=iq.Data(:,1:2)+1i*iq.Data(:,3:4);E=sum(abs(z).^2,2);Q=2*imag(conj(z(:,1)).*z(:,2));
 sel=iq.Time>=20;rr=Q./max(E,eps);errE=E/c.head.energyTarget-1;
 pair.(mode{1})=struct('energyRms',sqrt(mean(errE(sel).^2)),'quadratureRms',sqrt(mean(rr(sel).^2)), ...
  'recordS',c.duration,'steadyStartS',20,'finite',all(isfinite(z(:))));
 writematrix([iq.Time,E,rr],fullfile(folder,[lower(mode{1}) '_envelope.csv']));
 cmd=out.tap_v7_controller;writematrix([cmd.Time,cmd.Data],fullfile(folder,[lower(mode{1}) '_controller.csv']));
 close_system(name,0);
end
pair.quadratureRatio=pair.PIR.quadratureRms/pair.PI.quadratureRms;
pair.energyRatio=pair.PIR.energyRms/pair.PI.energyRms;
report=struct('date','2026-10-23','unitPass',unit.pass,'cases',cases,'PI_PIR',pair, ...
 'scope','short carrier runs plus 40s averaged comparison; no ARW, long-term bias, all-temperature or transistor signoff', ...
 'functionalPass',unit.pass&&all([cases.finite])&&pair.PI.finite&&pair.PIR.finite);
wl_write_json(fullfile(folder,'validation.json'),report);
wl_write_json(fullfile(folder,'budget_charge.json'),w7_budget(w7_config()));
wl_write_json(fullfile(folder,'budget_tia.json'),w7_budget(w7_config([],struct('readoutMode','tia'))));
wl_write_json(fullfile(folder,'budget_switched.json'),w7_budget(w7_config([],struct('tdmMode','switched'))));
assert(report.functionalPass,'V7 functional validation failed');
fprintf('Actual V7 runs complete. PIR/PI Q residual ratio = %.6g.\n',pair.quadratureRatio);
 function export(out,c,label)
  nav=out.tap_navigation;iq=out.tap_iq;cmd=out.tap_v7_controller;
  writematrix([nav.Time nav.Data],fullfile(folder,[label '_navigation.csv']));
  writematrix([iq.Time iq.Data],fullfile(folder,[label '_iq.csv']));
  writematrix([cmd.Time cmd.Data],fullfile(folder,[label '_controller.csv']));
  q=out.tap_head_displacement;vel=out.tap_head_velocity;
  energy=sum(q.Data.^2+(vel.Data/(2*pi*c.head.f0)).^2,2);
  idx=1:round(c.fsPlant*c.head.Ts):numel(q.Time);
  writematrix([q.Time(idx) energy(idx)],fullfile(folder,[label '_mechanical_energy.csv']));
  nodes={'head_displacement','head_velocity','cv_actual','pga','sample_hold','adc','mixer','dac_requested','dac','driver','force'};
  if strcmp(c.v7.tdmMode,'switched'),nodes=[nodes {'v7_timing','v7_acquisition','v7_electrode_voltage'}];end
  for j=1:numel(nodes)
   ts=out.(['tap_' nodes{j}]);sel=ts.Time>=c.duration-8/c.head.f0;
   writematrix([ts.Time(sel) ts.Data(sel,:)],fullfile(folder,[label '_' nodes{j} '_tail.csv']));
  end
  % Every case stores all actual config fields, representing complex numbers explicitly.
  x=rmfield(c,'legacyP');x.v7.senseCalibration=[real(c.v7.senseCalibration),imag(c.v7.senseCalibration)];
  x.v7.driveCalibration=[real(c.v7.driveCalibration),imag(c.v7.driveCalibration)];
  x.v7.complexEncoding='[real, imaginary]';wl_write_json(fullfile(folder,[label '_configuration.json']),x);
 end
end
