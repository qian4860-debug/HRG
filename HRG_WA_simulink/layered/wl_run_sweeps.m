function result=wl_run_sweeps()
% Reproducible one-factor carrier sweeps; explicitly conditional research budget.
root=fileparts(mfilename('fullpath'));addpath(root);
base=wl_config(5);base.name='hrg_wa_v5_sweep';base.observers=false;base.spectra=false;base.duration=.25;
base.cvInArtHz=1e-15; % Candidate lower-noise C/V, not measured or guaranteed feasible.
budget=struct('rateStdDegS',.1,'rateMeanDegS',.25,'ADCerrorV',20e-6, ...
 'energyMin',.8,'energyMax',1.2,'clipFraction',0, ...
 'status','Illustrative research allocation. Replace with actual instrument requirements.');
axes={ ...
 'adcBits',[10 14 18],'bit'; ...
 'dacBits',[10 14 16],'bit'; ...
 'cvInArtHz',[1 5 10]*1e-15,'A/sqrt(Hz)'; ...
 'pipelineCtrl',[0 3 12],'control samples, in addition to base register'; ...
 'channelSkewS',[0 .5 2]*1e-6,'s'; ...
 'jitterRmsS',[0 2 20]*1e-9,'s'; ...
 'cvBandwidthHz',[10000 30000 100000],'Hz'; ...
 'driverBandwidthHz',[10000 50000 100000],'Hz'; ...
 'pgaGain',[1 4 12],'V/V'};
wl_build(base);rows=struct('parameter',{},'value',{},'unit',{},'status',{},'metrics',{},'meetsBudget',{});
for axis=1:size(axes,1)
 for val=axes{axis,2}
  c=base;c.(axes{axis,1})=val;
  fprintf('SWEEP %s = %.9g\n',axes{axis,1},val);
  try
   [out,c]=wl_sim(c,false);m=wl_metrics(out,c);
   meets=m.finite && m.rateStdErrorDegS<=budget.rateStdDegS && abs(m.rateMeanErrorDegS)<=budget.rateMeanDegS ...
    && max(m.adcErrorRmsV)<=budget.ADCerrorV && m.energyMean>=budget.energyMin && m.energyMean<=budget.energyMax ...
    && m.adcClipFraction==0 && m.afeClipFraction==0 && m.driverClipFraction==0;
   status='simulated';
  catch e
   m=struct('errorIdentifier',e.identifier,'error',e.message);meets=false;status='simulation_error';
  end
  rows(end+1)=struct('parameter',axes{axis,1},'value',val,'unit',axes{axis,3},'status',status,'metrics',m,'meetsBudget',meets);
 end
end
% Paired independent seed repetitions quantify variability, not just one trace.
for seed=base.seed+(1:3)
 c=base;c.seed=seed;[out,c]=wl_sim(c,false);m=wl_metrics(out,c);
 rows(end+1)=struct('parameter','seed','value',seed,'unit','PRNG seed','status','simulated','metrics',m,'meetsBudget',m.rateStdErrorDegS<=budget.rateStdDegS);
end
summary=struct('budget',budget,'conditionalBase',rmfield(wl_setup(base),'legacyP'), ...
 'rows',rows,'warning','One-factor feasibility is not joint-corner signoff; short PSD cannot establish bias instability or ARW.');
wl_write_json(fullfile(root,'evidence','sweep_results.json'),summary);
f=fopen(fullfile(root,'evidence','sweep_summary.csv'),'wb');fprintf(f,'parameter,value,rate_std_deg_s,rate_mean_deg_s,adc_error_rms_V,energy,meets_budget\n');
for k=1:numel(rows)
 r=rows(k);if ~strcmp(r.status,'simulated'),continue;end;m=r.metrics;
 fprintf(f,'%s,%.12g,%.12g,%.12g,%.12g,%.12g,%d\n',r.parameter,r.value,m.rateStdErrorDegS,m.rateMeanErrorDegS,max(m.adcErrorRmsV),m.energyMean,r.meetsBudget);
end
fclose(f);result=summary;
fig=figure('Visible','off','Position',[20 20 1250 900]);
for a=1:9
 subplot(3,3,a);sel=strcmp({rows.parameter},axes{a,1});r=rows(sel);
 good=arrayfun(@(x)strcmp(x.status,'simulated'),r);r=r(good);
 if isempty(r),continue;end
 plot([r.value],arrayfun(@(x)x.metrics.rateStdErrorDegS,r),'-o');yline(budget.rateStdDegS,'--');
 xlabel(axes{a,3},'Interpreter','none');ylabel('Rate error std (deg/s)');title(axes{a,1},'Interpreter','none');grid on;
end
exportgraphics(fig,fullfile(root,'evidence','sweep_tradeoffs.png'));close(fig);
fprintf('Completed %d carrier sweep/seed cases.\n',numel(rows));
end
