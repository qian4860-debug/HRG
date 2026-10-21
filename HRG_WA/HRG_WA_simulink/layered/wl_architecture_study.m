function report=wl_architecture_study()
% Paired architecture experiment: change only drive scheduling and Cpar.
root=fileparts(mfilename('fullpath'));addpath(root);
base=wl_config(6);base.name='hrg_wa_v6_architecture';base.duration=.3;
base.observers=false;base.spectra=false;base.noiseEnable=false;
wl_build(base);rows=struct('tdm',{},'feedthroughF',{},'metrics',{},'frequencyHz',{},'feedthroughPeakV',{});
for tdm=[false true]
 for cp=[0 20e-15]
  c=base;c.tdmEnable=tdm;c.feedthroughF=cp;[out,c]=wl_sim(c,false);
  m=wl_metrics(out,c);t=out.tap_driver.Time;v=out.tap_driver.Data;
  sel=t>.15;t=t(sel);v=v(sel,:)*cp/c.cfF;
  % Input-referred electrical feedthrough before Rf/Cf and AFE filtering.
  amp=zeros(3,2);freq=c.head.f0*[.5 1 1.5];
  for k=1:3
   X=[sin(2*pi*freq(k)*t) cos(2*pi*freq(k)*t) ones(size(t))];coef=X\v;
   amp(k,:)=hypot(coef(1,:),coef(2,:));
  end
  rows(end+1)=struct('tdm',tdm,'feedthroughF',cp,'metrics',m, ...
   'frequencyHz',freq,'feedthroughPeakV',amp); %#ok<AGROW>
 end
end
report=struct('rows',rows,'pairedSeeds',base.seed,'noiseEnabled',false, ...
 'note','Mechanism-isolation experiment with fixed nominal phase calibration. Sideband redistribution alone does not prove lower closed-loop navigation error.');
wl_write_json(fullfile(root,'evidence','architecture_comparison.json'),report);
fig=figure('Visible','off','Position',[20 20 1000 440]);
subplot(1,2,1);bar([rows(2).feedthroughPeakV(:,1) rows(4).feedthroughPeakV(:,1)]);
xticklabels({'0.5 f0','f0','1.5 f0'});ylabel('Feedthrough peak (V), X');legend('Continuous','TDM');grid on;
subplot(1,2,2);bar(arrayfun(@(r)r.metrics.rateRmsErrorDegS,rows));
xticklabels({'CW Cpar=0','CW 20fF','TDM Cpar=0','TDM 20fF'});ylabel('Rate error RMS (deg/s)');grid on;
exportgraphics(fig,fullfile(root,'evidence','architecture_comparison.png'));close(fig);
close_system(base.name,0);
fprintf('Completed four paired architecture cases.\n');
end
