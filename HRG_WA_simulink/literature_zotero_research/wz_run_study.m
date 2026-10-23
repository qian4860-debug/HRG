function report=wz_run_study(reuseCarrier)
if nargin<1,reuseCarrier=false;end
r=fileparts(mfilename('fullpath'));addpath(r,fullfile(fileparts(r),'literature_v8_research'));
folder=fullfile(r,'evidence');if ~isfolder(folder),mkdir(folder);end
old=fullfile(fileparts(r),'literature_v8_research');
load_system(fullfile(old,'models','hrg_wa_v8_carrier_2.slx'));
c=getVariable(get_param('hrg_wa_v8_carrier_2','ModelWorkspace'),'v8_saved_configuration');
close_system('hrg_wa_v8_carrier_2',0);c=wz_setup(c);
checks=struct('name',{},'error',{},'limit',{},'pass',{});rng(20261024);
unrounded=c;unrounded.iqFractionBits=0;err=0;quantizedErr=0;
for k=1:6000
 a=1.8*rand(2,1);phase=2*pi*rand(2,1);d=a.*exp(1i*phase)/c.v7.senseCalibration;
 u=[real(d);imag(d)];err=max(err,max(abs(wz_iq(u,unrounded)-w8_iq(u,unrounded))));
 quantizedErr=max(quantizedErr,max(abs(wz_iq(u,c)-w8_iq(u,c))));
end
check('IQ_before_rounding_6000_samples',err,2e-14);
check('IQ_after_rounding_6000_samples',quantizedErr,2^-c.iqFractionBits);
bound=c.v8.maximumCalibratedAmplitude;b=c.v8.cubicCoefficient(:);
d=(bound+b.*bound.^3).*exp(1i*[.31;-.2]);d=(c.v8.senseInverse\d)/c.v7.senseCalibration;
u=[real(d);imag(d)];check('calibration_range_boundary_matches',max(abs(wz_iq(u,c)-w8_iq(u,c))),0);

% Pure geometric-angle tests: multiple wraps, negative motion, known virtual input,
% and explicit failure after a missing valid frame. Truth is used only here.
navErr=0;
for rate=[500 -500]
 s=[];omega=rate*pi/180;
 for k=0:4999
  t=k*c.head.Ts;theta=.1-c.head.bryan*omega*t;
  iq=[cos(2*theta);sin(2*theta);0;0];[s,y]=wz_navigation_tick(t,iq,true,0,s,c);
  navErr=max(navErr,abs(y(1)-omega*t));assert(y(3)==1);
 end
end
check('multiple_phase_wraps_both_directions',navErr,1e-9);
s=[];theta=.1;virtual=.2;
for k=0:999
 t=k*c.head.Ts;iq=[cos(2*theta);sin(2*theta);0;0];
 [s,y]=wz_navigation_tick(t,iq,true,virtual,s,c);theta=theta-c.head.bryan*virtual*c.head.Ts;
end
check('known_virtual_rotation_removed',abs(y(1)),1e-10);
[s,~]=wz_navigation_tick(1,iq,false,virtual,s,c);
[s,y]=wz_navigation_tick(1+c.head.Ts,iq,true,virtual,s,c);
check('gap_latches_continuity_invalid',double(y(3)~=0||s(8)~=1),0);

% Same actual carrier, exact capacitor, converters and synthetic calibration as
% the sealed V8 case. Only the guarded inverse and an observation branch differ.
c.name='hrg_wa_wz_carrier';c.observers=false;c.spectra=false;c.duration=1;
cache=fullfile(fileparts(r),'layered','_work','zotero_bridge','wz_rf_replay.mat');
sourceText=[fileread(fullfile(r,'wz_iq.m')) fileread(fullfile(r,'wz_navigation_tick.m')) ...
 fileread(fullfile(r,'wz_navigation_sfun.m')) fileread(fullfile(r,'wz_build.m'))];
if reuseCarrier&&isfile(cache)
 loaded=load(cache,'record');record=loaded.record;
 assert(isequal(record.configuration,rmfield(c,'legacyP'))&&strcmp(record.sourceText,sourceText), ...
  'Carrier replay cache does not match the current configuration and algorithms');
else
 name=wz_build(c,false);wz_setup(c);out=sim(name);legacy=w7_metrics(out,c);
 q=out.tap_iq;n=out.tap_direct_navigation;o=out.tap_navigation;
 record=struct('configuration',rmfield(c,'legacyP'),'sourceText',sourceText,'legacy',legacy, ...
  'iq',struct('Time',q.Time,'Data',squeeze(q.Data)), ...
  'nav',struct('Time',n.Time,'Data',squeeze(n.Data)), ...
  'oldnav',struct('Time',o.Time,'Data',squeeze(o.Data)));
 save(cache,'record');close_system(name,0);
end
legacy=record.legacy;iq=record.iq;nav=record.nav;oldnav=record.oldnav;
base=readmatrix(fullfile(old,'evidence','hrg_wa_v8_carrier_2_iq.csv'));
assert(numel(iq.Time)==size(base,1));
check('carrier_timestamp_CSV_roundtrip',max(abs(iq.Time-base(:,1))),1e-12);
rfIQ=max(abs(round(iq.Data(:)*2^c.iqFractionBits)-round(reshape(base(:,2:5),[],1)*2^c.iqFractionBits)));
check('actual_carrier_IQ_codes_match_sealed_V8',rfIQ,0);
valid=nav.Data(:,3)>.5;epoch=find(valid,1);use=valid&nav.Time>=.5;
angleError=(nav.Data(:,1)-nav.Data(epoch,1))-c.inputRate*(nav.Time-nav.Time(epoch));
direct=struct('rmsDeg',sqrt(mean(angleError(use).^2))*180/pi,'peakDeg',max(abs(angleError(use)))*180/pi, ...
 'referenceEpochS',nav.Time(epoch),'validSamples',sum(valid),'windowStartS',.5);
check('direct_angle_reduces_noise_free_dynamic_error',direct.rmsDeg/legacy.angle.rmsDeg,.2);
writematrix([nav.Time nav.Data],fullfile(folder,'carrier_direct_navigation.csv'));
writematrix([oldnav.Time oldnav.Data],fullfile(folder,'carrier_legacy_navigation.csv'));
writematrix([iq.Time iq.Data],fullfile(folder,'carrier_iq.csv'));

c.name='hrg_wa_wz_calibrated';c.observers=true;c.spectra=true;
name=wz_build(c,true);close_system(name,0);evalin('base','clear wl_c');
load_system(fullfile(r,'models',[name '.slx']));
feval(name,[],[],[],'compile');
scopes=numel(find_system(name,'BlockType','Scope'));
blocks=find_system(name,'LookUnderMasks','all','RegExp','on','Name','^Spectrum_(?!Channel_|Sample_).*');
spectra=numel(blocks);rates=struct('name',{},'sampleTimeS',{},'sampleRateHz',{},'units',{});rateError=0;
for k=1:spectra
 label=erase(get_param(blocks{k},'Name'),'Spectrum_');parent=get_param(blocks{k},'Parent');
 ts=get_param([parent '/Spectrum_Channel_' label],'CompiledSampleTime');if iscell(ts),ts=ts{1};end
 fs=str2double(get_param(blocks{k},'SampleRate'));rateError=max(rateError,abs(ts(1)*fs-1));
 rates(end+1)=struct('name',label,'sampleTimeS',ts(1),'sampleRateHz',fs,'units',get_param(blocks{k},'SpectrumUnits'));
end
feval(name,[],[],[],'term');
check('instrumented_model_has_21_scopes',abs(scopes-21),0);
check('instrumented_model_retains_16_spectra',abs(spectra-16),0);
check('spectrum_input_sample_rates_match_settings',rateError,1e-10);close_system(name,0);
report=struct('date','2026-10-24','checks',checks,'pass',all([checks.pass])&&legacy.pass, ...
 'legacyAcceptance',legacy,'directAngle',direct,'scopes',scopes,'spectra',spectra,'spectrumRates',rates, ...
 'sourceConfiguration','Sealed V8 carrier case 2 synthetic fixture; noise disabled', ...
 'limits',{{'Direct branch rejects loss of phase continuity; no automatic absolute-angle recovery', ...
 'Online, FRP and temperature compensation are not applied to the direct branch', ...
 'Noise-free dynamic improvement is not an ARW or long-term bias result', ...
 'Three-step Newton is an implementation simplification, not a new compensation theory'}});
wl_write_json(fullfile(folder,'carrier_study.json'),report);
fprintf('Legacy angle RMS %.9g deg; direct %.9g deg\n',legacy.angle.rmsDeg,direct.rmsDeg);
assert(report.pass,'Zotero study failed; inspect retained evidence');
 function check(n,error,limit)
  checks(end+1)=struct('name',n,'error',error,'limit',limit,'pass',isfinite(error)&&error<=limit);
  fprintf('%s: %g <= %g: %d\n',n,error,limit,checks(end).pass);
 end
end
