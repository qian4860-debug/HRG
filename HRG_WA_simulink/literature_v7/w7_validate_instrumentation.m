function report=w7_validate_instrumentation()
% Verify actual compiled signal rates, units and nonintrusive observers.
c=w7_config([],struct('tdmMode','switched','startupEnable',false));c.duration=.02;c.noiseEnable=false;
c.observers=false;c.spectra=false;c.name='hrg_wa_v7_no_observers';[reference,c]=w7_sim(c,false);close_system(c.name,0);
c.observers=true;c.spectra=true;c.name='hrg_wa_v7_with_observers';name=w7_build(c,false);
checks=struct('name',{},'error',{},'limit',{},'pass',{});
feval(name,[],[],[],'compile');
spectra=find_system(name,'LookUnderMasks','all','RegExp','on','Name','^Spectrum_(?!Channel_|Sample_).*');
check('switched_spectrum_count',abs(numel(spectra)-18),0);
for j=1:numel(spectra)
 b=spectra{j};label=erase(get_param(b,'Name'),'Spectrum_');parent=get_param(b,'Parent');
 ts=get_param([parent '/Spectrum_Channel_' label],'CompiledSampleTime');if iscell(ts),ts=ts{1};end
 expected=1/str2double(get_param(b,'SampleRate'));
 check([label '_compiled_rate'],abs(ts(1)-expected),expected*1e-10);
 voltage=ismember(label,{'cv_ideal','cv_actual','pga','anti_alias','sample_hold','adc','dac_requested','dac','driver','v7_acquisition','v7_electrode_voltage'});
 unit=get_param(b,'SpectrumUnits');
 if voltage,ok=strcmp(unit,'dBV');else,ok=strcmp(unit,'dBFS')&&str2double(get_param(b,'FullScale'))==1;end
 check([label '_units'],double(~ok),0);
end
feval(name,[],[],[],'term');w7_setup(c);observed=sim(name);
names=who(reference);names=names(startsWith(names,'tap_'));
for j=1:numel(names)
 a=reference.(names{j});b=observed.(names{j});
 check([names{j} '_timestamps'],max(abs(a.Time-b.Time)),1e-12);
 check([names{j} '_nonintrusive'],max(abs(a.Data(:)-b.Data(:))),1e-12);
end
close_system(name,0);
report=struct('checks',checks,'pass',all([checks.pass]),'spectra',numel(spectra));
wl_write_json(fullfile(fileparts(mfilename('fullpath')),'evidence','instrument_scoreboard.json'),report);
assert(report.pass,'V7 instrumentation regression failed');
 function check(n,e,l),checks(end+1)=struct('name',n,'error',e,'limit',l,'pass',isfinite(e)&&e<=l);end
end
