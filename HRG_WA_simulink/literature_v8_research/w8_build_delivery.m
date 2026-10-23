function report=w8_build_delivery()
% Build an instrumented artifact and check observer rates and noninterference.
r=fileparts(mfilename('fullpath'));addpath(r);w8_config();
path=fullfile(r,'models','hrg_wa_v8_carrier_2.slx');load_system(path);
c=getVariable(get_param('hrg_wa_v8_carrier_2','ModelWorkspace'),'v8_saved_configuration');
close_system('hrg_wa_v8_carrier_2',0);c.v8.calibrationSource='synthetic independent-reference fixture; w8_run_studies; not measured hardware';
c=w8_setup(c);c.duration=.02;
c.maxLogPoints=ceil(c.duration*c.fsPlant)+1;c.name='hrg_wa_v8_instrument_off';
c.observers=false;c.spectra=false;name=w8_build(c,'carrier',false);w8_setup(c);off=sim(name);close_system(name,0);
c.name='hrg_wa_v8_instrument_on';c.observers=true;c.spectra=true;
name=w8_build(c,'carrier',false);w8_setup(c);
feval(name,[],[],[],'compile');
spectra=find_system(name,'LookUnderMasks','all','RegExp','on','Name','^Spectrum_(?!Channel_|Sample_).*');
rates=struct('name',{},'sampleTimeS',{},'specifiedSampleRateHz',{},'units',{});
for j=1:numel(spectra)
 b=spectra{j};label=erase(get_param(b,'Name'),'Spectrum_');parent=get_param(b,'Parent');
 ts=get_param([parent '/Spectrum_Channel_' label],'CompiledSampleTime');if iscell(ts),ts=ts{1};end
 fs=str2double(get_param(b,'SampleRate'));assert(abs(ts(1)*fs-1)<1e-10);
 rates(end+1)=struct('name',label,'sampleTimeS',ts(1),'specifiedSampleRateHz',fs,'units',get_param(b,'SpectrumUnits'));
end
feval(name,[],[],[],'term');w8_setup(c);on=sim(name);
fields=who(off);fields=fields(startsWith(fields,'tap_'));maxError=0;
for j=1:numel(fields)
 a=off.(fields{j});b=on.(fields{j});assert(isequal(a.Time,b.Time));
 err=max(abs(a.Data(:)-b.Data(:)));maxError=max(maxError,err);
end
assert(maxError<=1e-12);close_system(name,0);
c.name='hrg_wa_v8_calibrated';c.duration=2;c.maxLogPoints=ceil(c.duration*c.fsPlant)+1;
name=w8_build(c,'carrier',true);close_system(name,0);
evalin('base','clear wl_c');load_system(fullfile(r,'models',[name '.slx']));
set_param(name,'SimulationCommand','update');scopes=numel(find_system(name,'BlockType','Scope'));
assert(scopes>=19&&numel(spectra)>=16);close_system(name,0);
report=struct('pass',true,'observerMaxDifference',maxError,'comparedTaps',numel(fields), ...
 'scopes',scopes,'spectra',numel(spectra),'rates',rates,'reopenedAndCompiled',true, ...
 'savedModel',[name '.slx'],'scope','Observer noninterference and discrete input sample rates; no hardware spectrum signoff');
wl_write_json(fullfile(r,'evidence','instrumentation.json'),report);
end
