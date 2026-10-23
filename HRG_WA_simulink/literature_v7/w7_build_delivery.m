function report=w7_build_delivery()
% Save only new V7 models, then reopen each saved artifact to test its callback.
r=fileparts(mfilename('fullpath'));rows=struct('name',{},'scopes',{},'spectra',{},'compiled',{});
scenarios={'continuous','pir','switched','tia','electrostatic'};
for k=1:numel(scenarios)
 opt=struct;
 switch scenarios{k}
  case 'pir',opt.controlMode='PIR';
  case 'switched',opt.tdmMode='switched';
  case 'tia',opt.readoutMode='tia';
  case 'electrostatic',opt.actuationMode='electrostatic';
 end
 c=w7_config([],opt);c.name=['hrg_wa_v7_' scenarios{k}];name=w7_build(c,true);close_system(name,0);
 load_system(fullfile(r,'models',[name '.slx']));
 set_param(name,'SimulationCommand','update');
 scopes=find_system(name,'LookUnderMasks','all','BlockType','Scope');
 spectra=find_system(name,'LookUnderMasks','all','RegExp','on','Name','^Spectrum_(?!Channel_|Sample_).*');
 rows(end+1)=struct('name',name,'scopes',numel(scopes),'spectra',numel(spectra),'compiled',true); %#ok<AGROW>
 close_system(name,0);
end
c=w7_config([],struct('controlMode','PIR','startupEnable',false));c.name='hrg_wa_v7_pir_study';c.duration=40;
c.noiseEnable=false;c.adcBits=0;c.dacBits=0;c.iqFractionBits=0;c.controlFractionBits=0;
c.head.detect=eye(2);c.head.drive=eye(2);c.head.dgamma=.004;c.head.splitHz=.08;c.head.duffingHz=0;
name=w7_envelope(c,true);close_system(name,0);load_system(fullfile(r,'models',[name '.slx']));set_param(name,'SimulationCommand','update');close_system(name,0);
report=struct('carrierModels',rows,'envelopeModel',name,'reopenedAndCompiled',true);
report.environment=struct('matlab',version,'release',version('-release'),'simulink',ver('simulink'),'dsp',ver('dsp'));
wl_write_json(fullfile(r,'evidence','saved_models.json'),report);
end
