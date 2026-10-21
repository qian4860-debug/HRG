function report=wl_algorithm_study()
root=fileparts(mfilename('fullpath'));addpath(root);
wl_write_json(fullfile(root,'evidence','runtime.json'),struct('matlabVersion',version,'toolboxes',ver));
c=wl_config(5);c.duration=8;c.online=true;c.compensationApply=false;c.inputRate=80*pi/180;
% Build latest carrier containers so envelope copies current public-port schema.
raw=c;raw.duration=.02;wl_build(raw);name=wl_build_envelope(c);
c=wl_setup(c);out=sim(name,'StopTime',num2str(c.duration));
online=wl_metrics(out,c);assert(online.onlineUpdates>0 && online.kalmanUpdates>0);
wl_write_json(fullfile(root,'evidence','online_algorithm_activity.json'),online);
% Dedicated certified zero-rate FRP fixture. Only a Boolean permission enters
% the algorithm. Plant input is zero in the test scenario, not a readout port.
c=wl_config(5);c.duration=28;c.inputRate=0;c.frp=true;c.frpSequence=true;
c.calibrationPermit=true;c.zeroRateCertified=true;c.temperatureRampCPerS=.2;
c.compensationApply=false;c=wl_setup(c);
train=sim(name,'StopTime',num2str(c.duration));d=train.tap_algorithm_diagnostics.Data;
weights=d(end,13:21).';trained=wl_metrics(train,c);
assert(trained.frpUpdates>0,'FRP fixture did not produce any identification updates');
% Held-out use: freeze coefficients; no zero-rate permission, new rate and T.
validation=wl_config(5);validation.duration=4;validation.inputRate=45*pi/180;
validation.temperatureC=29;validation.frp=true;validation.frpFreeze=true;
validation.frpTheta=weights;validation.compensationApply=false;validation=wl_setup(validation);
off=sim(name,'StopTime','4');validation.compensationApply=true;validation=wl_setup(validation);on=sim(name,'StopTime','4');
moff=wl_metrics(off,validation);mon=wl_metrics(on,validation);
freezeChange=norm(on.tap_algorithm_diagnostics.Data(end,13:21).'-weights);
assert(freezeChange==0,'Held-out validation retrained parameters');
report=struct('training',trained,'trainedWeights',weights,'heldoutOff',moff,'heldoutOn',mon, ...
 'frozenWeightChange',freezeChange,'noiseImproved',mon.rateRmsErrorDegS<moff.rateRmsErrorDegS, ...
 'trainingConfiguration',rmfield(c,'legacyP'),'heldoutConfiguration',rmfield(validation,'legacyP'), ...
 'note','Envelope-equivalent system study. Activity and frozen isolation do not imply all physical parameters are identifiable or compensation always improves.');
wl_write_json(fullfile(root,'evidence','frp_closed_loop_study.json'),report);
writematrix([train.tap_navigation.Time train.tap_navigation.Data d],fullfile(root,'evidence','frp_training_trace.csv'));
% Baseband frequency sweep, explicitly separated from carrier circuit metrics.
frequencies=[1 10 50];frf=[];
for f=frequencies
 v=wl_config(5);v.duration=max(1,5/f);v.inputRate=0;v.inputRateAmplitude=60*pi/180;v.inputFrequencyHz=f;v=wl_setup(v);
 o=sim(name,'StopTime',num2str(v.duration));t=o.tap_navigation.Time;n=o.tap_navigation.Data(:,2);sel=t>v.duration/2;
 X=[sin(2*pi*f*t(sel)) cos(2*pi*f*t(sel)) ones(sum(sel),1)];coef=X\n(sel);
 frf(end+1,:)=[f hypot(coef(1),coef(2))/v.inputRateAmplitude atan2(coef(2),coef(1))*180/pi]; %#ok<AGROW>
end
writematrix(frf,fullfile(root,'evidence','envelope_frf.csv'));
fprintf('Online updates: %d; FRP train updates: %d; heldout weight change %.3g.\n',online.onlineUpdates,trained.frpUpdates,freezeChange);
end
