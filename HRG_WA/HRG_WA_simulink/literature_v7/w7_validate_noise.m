function report=w7_validate_noise()
% Paired source-on/source-off records; not a long-term noise qualification.
for enabled=[false true]
 c=w7_config([],struct('startupEnable',false));c.duration=.2;c.noiseEnable=enabled;
 c.noiseSourceEnable=struct('cv',true,'pga',false,'driver',false,'jitter',false,'brownian',false);
 c.observers=false;c.spectra=false;c.name='hrg_wa_v7_noise_pair';
 [out,c]=w7_sim(c,false);nav=out.tap_navigation;
 if enabled,on=nav;else,off=nav;end
 close_system(c.name,0);
end
assert(isequal(on.Time,off.Time));delta=on.Data(:,2)-off.Data(:,2);
sel=on.Time>=.1;[f,P,info]=wl_native_psd(on.Time(sel),delta(sel));info.noiseIsolated=true;
folder=fullfile(fileparts(mfilename('fullpath')),'evidence');
writematrix([on.Time delta],fullfile(folder,'cv_noise_increment.csv'));
writematrix([f P],fullfile(folder,'cv_noise_increment_psd.csv'));
report=struct('source','CV only; identical scenario and seed, source-on minus source-off', ...
 'recordS',.2,'windowStartS',.1,'rateIncrementStdRadS',std(delta(sel),1),'psd',info, ...
 'pass',all(isfinite(delta))&&std(delta(sel),1)>0, ...
 'limitation','short paired response includes nonlinear interaction/quantizer changes; not intrinsic noise, ARW or bias instability');
wl_write_json(fullfile(folder,'noise_scoreboard.json'),report);assert(report.pass);
end
