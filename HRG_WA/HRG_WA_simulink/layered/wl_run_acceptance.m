function report=wl_run_acceptance(mode,caseNames)
% Sequential physical-chain injections; same eight-family scoreboard every run.
% quick: short functional screen. full: longer carrier runs, still NOT Allan signoff.
if nargin<1,mode='quick';end
if nargin<2,caseNames={};end
if ischar(caseNames)||isstring(caseNames),caseNames=cellstr(caseNames);end
assert(ismember(mode,{'quick','full'}));root=fileparts(mfilename('fullpath'));addpath(root);
c=wl_config(4);c.observers=false;c.spectra=false;c.duration=.2;
if strcmp(mode,'full'),c.duration=5;end
c.head.splitHz=0;c.head.dgamma=0;c.head.duffingHz=0;c.head.detect=eye(2);c.head.drive=eye(2);
c.noiseEnable=true;c.noiseSourceEnable=struct('cv',false,'pga',false,'driver',false,'jitter',false,'brownian',false);
base=c;cases={};labels={};groups={};
push('baseline','reference',base);
x=base;x.head.splitHz=.008;push('frequency_split','mechanical',x);
x=base;x.head.dgamma=.00025;push('damping_anisotropy','mechanical',x);
x=base;x.head.duffingHz=.015;push('amplitude_frequency','mechanical',x);
x=base;x.temperatureRampCPerS=5;push('temperature_ramp','mechanical',x);
x=base;x.head.detect=[1 .003;-.002 1];push('electrode_cross_coupling','detection',x);
x=base;x.adcGain=[1;1.001];push('detection_gain_mismatch','detection',x);
x=base;x.channelSkewS=5e-6;push('channel_skew','detection',x);
x=base;x.cvBandwidthHz=10000;push('unrecalibrated_AFE_pole','detection',x);
for source={'brownian','cv','pga','jitter','driver'}
 x=base;x.noiseSourceEnable.(source{1})=true;push([source{1} '_noise'],'stochastic_single_source',x);
end
x=base;x.adcBits=12;push('ADC_quantization','conversion',x);
x=base;x.pipelineCtrl=12;push('digital_latency','digital',x);
x=base;x.dacBits=10;push('DAC_quantization','actuation',x);
x=base;x.driverGain=[1;1.01];push('drive_gain_mismatch','actuation',x);
x=base;x.feedthroughF=2e-15;push('parasitic_feedthrough','actuation',x);
x=base;x.adcFsV=.03;push('ADC_overrange_negative_control','negative_control',x);
x=base;x.inputRate=0;push('zero_input','zero_input',x);
x=base;x.head.initialEnergy=.04;x.duration=4.1;push('seeded_build_up','startup',x);
% True zero-state start is an explicit known limitation of the feedback-only model.
x=base;x.head.initialEnergy=0;x.duration=.1;push('zero_energy_start_negative_control','negative_control',x);
% Cumulative corners exercise coupling that one-factor tests cannot establish.
x=base;x.head.splitHz=.008;x.head.dgamma=.00025;x.head.duffingHz=.015;
x.head.detect=[1 .003;-.002 1];x.noiseSourceEnable=struct('cv',true,'pga',true,'driver',true,'jitter',true,'brownian',true);
push('joint_head_frontend_conversion_drive','joint',x);
rows=struct('name',{},'group',{},'configuration',{},'metrics',{},'status',{});
folder=fullfile(root,'evidence','principle_acceptance');if ~isfolder(folder),mkdir(folder);end
resultPath=fullfile(folder,['campaign_' mode '.json']);
indices=1:numel(cases);
if ~isempty(caseNames)
 assert(all(ismember(caseNames,labels)),'Unknown acceptance case');
 assert(isfile(resultPath),'Run the complete campaign before selected reruns');
 previous=jsondecode(fileread(resultPath));rows=previous.cases;
 assert(numel(rows)==numel(cases)&&isequal({rows.name},labels),'Campaign schema changed; rerun all cases');
 % Always re-run the baseline for an exact, same-clock stochastic pairing.
 indices=find(ismember(labels,[{'baseline'} caseNames(:)']));
end
reference=[];referenceTime=[];
for k=indices
 x=cases{k};fprintf('ACCEPTANCE %d/%d %s duration %.3g s\n',k,numel(cases),labels{k},x.duration);
 [out,x]=wl_acceptance_sim(x);b=wl_acceptance_budget(x);m=wl_acceptance_metrics(out,x,b);
 if k==1,reference=out.tap_navigation.Data(:,2);referenceTime=out.tap_navigation.Time;end
 if strcmp(groups{k},'stochastic_single_source') && isfield(m,'rate')
  assert(isequal(referenceTime,out.tap_navigation.Time),'Paired noise runs require identical clocks');
  delta=out.tap_navigation.Data(:,2)-reference;sel=referenceTime>=b.steadyStartS & out.tap_navigation.Data(:,3)>.5;
  m.pairedNoise=struct('rateStdDegS',std(delta(sel),1)*180/pi,'referenceCase','baseline', ...
   'definition','demeaned same-configuration output increment; only named stochastic source enabled');
 end
 m.fullRimPeriodObserved=abs(x.head.bryan*x.inputRate*x.duration)>=pi/2;
 m.shortRecordWarning='No ARW or bias instability qualification from this campaign';
 cfg=x;if isfield(cfg,'legacyP'),cfg=rmfield(cfg,'legacyP');end
 status='screened';if ~m.pass,status='outside_illustrative_budget';end
 row=struct('name',labels{k},'group',groups{k},'configuration',cfg,'metrics',m,'status',status);
 if isempty(caseNames),rows(end+1)=row;else,rows(k)=row;end %#ok<AGROW>
 wl_write_json(fullfile(folder,['campaign_' mode '_partial.json']),struct('executionComplete',false,'completedIndices',1:numel(rows),'cases',rows));
end
report=struct('mode',mode,'cases',rows,'allFunctionalBudgetsMet',all(arrayfun(@(r)r.metrics.pass,rows)), ...
 'executionComplete',true,'note','Budget failures and negative controls are retained, never converted to a universal PASS. Full mode is a longer carrier experiment, not long-term noise signoff.');
report.rerunCaseNames=caseNames;wl_write_json(resultPath,report);
f=fopen(fullfile(folder,['campaign_' mode '.csv']),'wb');clean=onCleanup(@()fclose(f)); %#ok<NASGU>
fprintf(f,'case,group,assessment,budget_pass,energy_rms,Q_E_rms,phase_rms_rad,angle_peak_deg,rate_std_deg_s,min_headroom,build_time_s,zero_mean_deg_s\n');
for k=1:numel(rows)
 r=rows(k);m=r.metrics;
 if ~isfield(m,'energy'),fprintf(f,'%s,%s,%s,0,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN\n',r.name,r.group,m.assessment);continue;end
 fprintf(f,'%s,%s,%s,%d,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g\n',r.name,r.group,m.assessment,m.pass,m.energy.relativeRms,m.quadrature.invariantRatioRms,m.lock.phaseRmsRad,m.angle.peakDeg,m.rate.residualStdDegS,m.saturation.minimumHeadroomFraction,m.build.timeS,m.zeroBias.shortRunMeanDegS);
end
fprintf('Completed %d cases; functional budget pass %d. See retained per-case results.\n',numel(rows),report.allFunctionalBudgetsMet);
 function push(label,group,x)
  cases{end+1}=x;labels{end+1}=label;groups{end+1}=group;
 end
end
