function report=wl_validate_spectrum()
% Observer-only regression against immutable 04050e4 model, not user files.
root=fileparts(mfilename('fullpath'));addpath(root);
folder=fullfile(root,'evidence','spectrum_fix');if ~isfolder(folder),mkdir(folder);end
reference=fullfile(root,'_work','spectrum_reference','hrg_wa_v5.slx');
assert(isfile(reference),'Extract baseline model from Git commit 04050e4 before this test');
c=wl_config(5);c.duration=.08;load_system(reference);wl_setup(c);
baseline=sim('hrg_wa_v5','StopTime','.08');close_system('hrg_wa_v5',0);
c.name='hrg_wa_v5_spectrum_fixed';wl_build(c);wl_setup(c);
checks=struct('name',{},'value',{},'limit',{},'pass',{});
feval(c.name,[],[],[],'compile');
spectra=find_system(c.name,'LookUnderMasks','all','RegExp','on','Name','^Spectrum_(?!Channel_|Sample_).*');
check('spectrum_count',abs(numel(spectra)-16),0);settings=struct([]);
for k=1:numel(spectra)
 b=spectra{k};label=erase(get_param(b,'Name'),'Spectrum_');parent=get_param(b,'Parent');
 selector=[parent '/Spectrum_Channel_' label];Ts=get_param(selector,'CompiledSampleTime');
 if iscell(Ts),Ts=Ts{1};end
 expected=1/str2double(get_param(b,'SampleRate'));
 check([label '_actual_sampling'],abs(Ts(1)-expected),expected*1e-10);
 unit=get_param(b,'SpectrumUnits');voltage=ismember(label,{'cv_ideal','cv_actual','pga','anti_alias','sample_hold','adc','dac_requested','dac','driver'});
 if voltage,ok=strcmp(unit,'dBV');else,ok=strcmp(unit,'dBFS')&&str2double(get_param(b,'FullScale'))==1;end
 check([label '_physical_units'],double(~ok),0);
 settings(k).node=label;settings(k).compiledSampleTimeS=Ts(1);settings(k).unit=unit;
end
feval(c.name,[],[],[],'term');
out=sim(c.name,'StopTime','.08');names=who(out);names=names(startsWith(names,'tap_'));
for k=1:numel(names)
 a=out.(names{k});b=baseline.(names{k});
 check([names{k} '_observer_nonintrusive'],max(abs(a.Data(:)-b.Data(:))),1e-10);
end
% Independent PSD checks: coherent-tone frequency, Parseval energy, DC removal.
fs=1000;t=(0:1023)'/fs;x=2+sin(2*pi*125*t);
[f,P,m]=wl_native_psd(t,x);[~,i]=max(P);
check('PSD_known_tone_Hz',abs(f(i)-125),1e-9);
check('PSD_known_tone_variance',abs(sum(P)*m.binSpacingHz-.5),1e-12);
[~,P]=wl_native_psd(t,ones(size(t)));check('PSD_removed_constant',max(P),0);
[~,~,m]=wl_native_psd((0:2000)'/1000,cos(2*pi*.123*(0:2000)'/1000));
check('two_seconds_cannot_resolve_slow_rotation',double(m.binSpacingHz<=.123),0);
check('PSD_does_not_claim_isolated_noise',double(m.noiseIsolated),0);
[f,P,m]=wl_native_psd(out.tap_driver.Time,out.tap_driver.Data);[~,i]=max(P(:,1));
check('driver_native_PSD_carrier_Hz',abs(f(i)-c.head.f0),m.binSpacingHz);
fig=wl_view_results(out,c);check('replay_nineteen_tabs',abs(numel(findall(fig,'Type','uitab'))-19),0);
tab=findall(fig,'Type','uitab','Tag','tap_iq');check('IQ_quality_axes',abs(numel(findall(tab,'Type','axes'))-3),0);
tab=findall(fig,'Type','uitab','Tag','tap_driver');axesList=findall(tab,'Type','axes');
for k=1:numel(axesList)
 if contains(axesList(k).YLabel.String,'PSD')
  check('driver_PSD_voltage_density_label',double(~contains(axesList(k).YLabel.String,'V^2/Hz')),0);
  exportgraphics(axesList(k),fullfile(folder,'driver_psd.png'));
 end
end
close(fig);close_system(c.name,0);
report=struct('checks',checks,'pass',all([checks.pass]),'instruments',settings, ...
 'baselineCommit','04050e4','durationS',.08,'note','Discrete sample time checked on each actual selector wired directly into its spectrum analyzer. Desktop DSP windows are not opened by this batch test.');
wl_write_json(fullfile(folder,'scoreboards.json'),report);assert(report.pass,'Spectrum regression failed');
fprintf('PASS %d sampling, units, observer-equivalence and PSD checks.\n',numel(checks));
    function check(name,value,limit)
     ok=isfinite(value)&&value<=limit;checks(end+1)=struct('name',name,'value',value,'limit',limit,'pass',ok);
     fprintf('%s %.9g <= %.9g : %d\n',name,value,limit,ok);
    end
end
