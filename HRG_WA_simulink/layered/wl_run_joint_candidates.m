function report=wl_run_joint_candidates()
% Joint Rf/current-noise study after the initial one-factor screening.
root=fileparts(mfilename('fullpath'));addpath(root);
screen=jsondecode(fileread(fullfile(root,'evidence','sweep_results.json')));budget=screen.budget;
c=wl_config(5);c.name='hrg_wa_v5_joint';c.duration=.25;c.observers=false;c.spectra=false;
wl_build(c);rows=struct('rfOhm',{},'cvInArtHz',{},'metrics',{},'meetsBudget',{});
for rf=[1e9 1e10 1e11]
 for inoise=[.2 1]*1e-15
  v=c;v.rfOhm=rf;v.cvInArtHz=inoise;[out,v]=wl_sim(v,false);m=wl_metrics(out,v);
  meets=m.finite && m.rateStdErrorDegS<=budget.rateStdDegS && abs(m.rateMeanErrorDegS)<=budget.rateMeanDegS ...
   && max(m.adcErrorRmsV)<=budget.ADCerrorV && m.energyMean>=budget.energyMin && m.energyMean<=budget.energyMax ...
   && m.adcClipFraction==0 && m.afeClipFraction==0 && m.driverClipFraction==0;
  rows(end+1)=struct('rfOhm',rf,'cvInArtHz',inoise,'metrics',m,'meetsBudget',meets); %#ok<AGROW>
  fprintf('JOINT Rf=%.3g, i_n=%.3g, rate std=%.4g, budget=%d\n',rf,inoise,m.rateStdErrorDegS,meets);
 end
end
report=struct('rows',rows,'budget',budget,'configuration',rmfield(wl_setup(c),'legacyP'), ...
 'note','Conditional research candidates with frozen nominal calibration. No assertion that 100GOhm Rf or sub-fA noise is feasible in the intended IC process.');
wl_write_json(fullfile(root,'evidence','joint_candidates.json'),report);
close_system(c.name,0);
end
