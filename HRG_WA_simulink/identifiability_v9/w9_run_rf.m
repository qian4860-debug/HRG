function report=w9_run_rf()
r=fileparts(mfilename('fullpath'));addpath(r);p=w9_setup();e=fullfile(r,'evidence');
if ~isfolder(e),mkdir(e);end
c=w8_config();c.noiseEnable=false;c.observers=false;c.spectra=false;
c.online=false;c.frp=false;c.temperatureCompensate=false;c.duration=p.rf_closed_loop_duration_s;
c.fsPlant=800000;c.maxLogPoints=ceil(c.duration*c.fsPlant)+1;
c.head.dgamma=0;c.head.splitHz=0;c.head.detuningHz=0;c.head.duffingHz=0;
c.head.initialQuadRatio=0;c.head.initialEnergy=1;c.head.initialTheta=.231;
c.head.detect=eye(2);c.head.drive=eye(2);c.driverGain=[1;1];c.adcGain=diag(p.sense_matrix);
c.inputRate=80*pi/180;c.inputRateAmplitude=0;c.v8.filterWarmupS=.012;
c.v8.driveInverse=eye(2);c.v8.maximumCalibratedAmplitude=1.5;
c.v8.calibrationSource='Frozen independent-reference synthetic amplitude/phase fixture, not held-out RF truth';
% Separate fixture implementation: numerical Fourier integration of exact
% differential charge; actual RF uses the time-domain C(q), AFE and converters.
N=8192;phase=2*pi*(0:N-1)/N;rho=c.displacementM/c.gapM;
amp=linspace(.12,1.25,73)';phi=.41*sin((1:73)');
reference=[amp.*exp(1i*phi),flipud(amp).*exp(-1i*phi)];measured=zeros(size(reference));
for k=1:size(reference,1)
 for j=1:2
  motion=real(reference(k,j)*exp(1i*phase));charge=motion./(1-rho^2*motion.^2);
  measured(k,j)=c.adcGain(j)*2*mean(charge.*exp(-1i*phase));
 end
end
fit=w8_fit_diagonal(reference,measured);
c.v8.senseInverse=fit.senseInverse;c.v8.cubicCoefficient=fit.cubicCoefficient;
writematrix([real(reference) imag(reference) real(measured) imag(measured)],fullfile(e,'rf_independent_fixture.csv'));
wl_write_json(fullfile(e,'rf_frozen_fit.json'),struct('inverseReal',real(fit.senseInverse),'inverseImag',imag(fit.senseInverse), ...
 'cubicCoefficient',fit.cubicCoefficient,'condition',fit.condition,'relativeFitResidual',fit.relativeFitResidual));
rejected=false;
try,w8_fit_diagonal(ones(20,2),ones(20,2));catch,rejected=true;end
assert(rejected,'A single amplitude cannot separate linear gain and cubic coefficient');
cases=struct('name',{},'calibrationEnabled',{},'directAngle',{},'metrics',{});
for on=0:1
 c.name=sprintf('hrg_wa_v9_rf_%d',on);c.v8.enabled=logical(on);
 c=w9_setup(c);name=wz_build(c,false);w9_setup(c);out=sim(name);
 m=w7_metrics(out,c);nav=out.tap_direct_navigation;iq=out.tap_iq;
 t=nav.Time;d=squeeze(nav.Data);valid=d(:,3)>.5;first=find(valid,1);use=valid&t>=.5;
 error=(d(:,1)-d(first,1))-c.inputRate*(t-t(first));
 metric=struct('rmsDeg',sqrt(mean(error(use).^2))*180/pi,'peakDeg',max(abs(error(use)))*180/pi, ...
  'epochS',t(first),'steadyStartS',.5,'validFraction',mean(valid(t>=.5)));
 writematrix([t d],fullfile(e,sprintf('rf_%d_navigation.csv',on)));
 writematrix([iq.Time squeeze(iq.Data)],fullfile(e,sprintf('rf_%d_iq.csv',on)));
 for node={'adc','driver','head_displacement','head_velocity'}
  ts=out.(['tap_' node{1}]);sel=ts.Time>=c.duration-8/c.head.f0;
  writematrix([ts.Time(sel) ts.Data(sel,:)],fullfile(e,sprintf('rf_%d_%s_tail.csv',on,node{1})));
 end
 cases(end+1)=struct('name',name,'calibrationEnabled',logical(on),'directAngle',metric,'metrics',m);
 fprintf('V9 actual RF calibration=%d: direct RMS %.10g deg; functional acceptance=%d\n',on,metric.rmsDeg,m.pass);
 close_system(name,0);clear out;
end
ratio=cases(2).directAngle.rmsDeg/cases(1).directAngle.rmsDeg;
% Build a visible delivery model, then reopen with an empty caller workspace.
c.name='hrg_wa_v9_frozen_calibration';c.observers=true;c.spectra=true;c=w9_setup(c);
name=wz_build(c,false);folder=fullfile(r,'models');if ~isfolder(folder),mkdir(folder);end
set_param(name,'PostLoadFcn',sprintf(['addpath(fileparts(fileparts(get_param(''%s'',''FileName'')))); ' ...
 'w9_setup(getVariable(get_param(''%s'',''ModelWorkspace''),''v8_saved_configuration''));'],name,name));
note=Simulink.Annotation(name,['V9 HELD-OUT RF: frozen independent fixture; no online refit or plant truth in the calibration estimator. ' ...
 '1% ADC gain asymmetry; exact capacitor, ADC/DAC and original control. Synthetic, noise disabled.']);
note.Position=[20 1390 1600 1460];save_system(name,fullfile(folder,[name '.slx']));
print(['-s' name],'-dpng','-r100',fullfile(folder,[name '.png']));close_system(name,0);
evalin('base','clear wl_c');load_system(fullfile(folder,[name '.slx']));
feval(name,[],[],[],'compile');scopes=numel(find_system(name,'BlockType','Scope'));
blocks=find_system(name,'LookUnderMasks','all','RegExp','on','Name','^Spectrum_(?!Channel_|Sample_).*');rateError=0;
for k=1:numel(blocks)
 label=erase(get_param(blocks{k},'Name'),'Spectrum_');parent=get_param(blocks{k},'Parent');
 ts=get_param([parent '/Spectrum_Channel_' label],'CompiledSampleTime');if iscell(ts),ts=ts{1};end
 rateError=max(rateError,abs(ts(1)*str2double(get_param(blocks{k},'SampleRate'))-1));
end
feval(name,[],[],[],'term');close_system(name,0);
report=struct('date','2026-10-26','cases',cases,'angleImprovementRatio',ratio, ...
 'singleAmplitudeFixtureRejected',rejected,'reopenedCompiled',true,'scopes',scopes,'spectra',numel(blocks), ...
 'spectrumRateError',rateError,'pass',ratio<=p.acceptance.rf_angle_improvement_ratio&&cases(2).metrics.pass&&rateError<1e-10, ...
 'scope','Actual original-rate RF run; precharged, constant rate, synthetic fixture, noise disabled', ...
 'notAssessed',{{'ARW','long-term Allan bias','new zero-state startup','unknown-motion online calibration','physical-head parameter accuracy'}});
wl_write_json(fullfile(e,'rf_study.json'),report);
assert(report.pass,'RF hypothesis failed; retain evidence and diagnose before changing acceptance');
end
