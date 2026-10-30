function result=p101_verify_temperature()
root=fileparts(mfilename('fullpath'));ev=fullfile(root,'evidence');
fixture=jsondecode(fileread(fullfile(ev,'temperature_holdout_fixture.json')));
base=p101_config;base.duration=.5;c0=p101_calibration;check=struct;cases=struct;
errors=[];goodError=[];badError=[];
for k=[1 3 4]
 truth=fixture.physical_truth(k);[p,c]=p101_temperature_apply(base,c0,truth.T);
 actual=base;fields={'f0','gamma_intrinsic','Cs','detect_matrix','drive_matrix','driver_tau','afe_bw'};
 for j=1:numel(fields),actual.(fields{j})=truth.(fields{j});end
 actual.driver_tau=actual.driver_tau(:);actual.afe_bw=actual.afe_bw(:);
 % Only independent fixture truth enters the plant. Fitted profile enters the
 % controller and deembedding, so mismatches cannot cancel by construction.
 r=p101_reference(p,c,actual);m=p101_metrics(r,actual);
 u=p101_reference(base,c0,actual);mu=p101_metrics(u,actual);
 goodError(end+1)=m.angle_rms_deg;badError(end+1)=mu.angle_rms_deg;
 expected=fixture.observations(k,:);pred=[p.f0 p.gamma_intrinsic p.Cs reshape(real(c.detect).',1,4) reshape(imag(c.detect).',1,4) reshape(real(c.drive).',1,4) reshape(imag(c.drive).',1,4)];
 errors(end+1)=max(abs(pred-expected)./max(abs(expected),realmin));
 cases.(['T' num2str(k)])=struct('temperature_C',truth.T,'calibrated',m,'uncalibrated',mu);
 if k==3
  % Update a loaded model in memory, simulate, then restore it without saving
  % fitted controller parameters into the accepted baseline SLX.
  mdl='hrg_wa_v10_1_piezo';load_system(fullfile(root,'models',[mdl '.slx']));mw=get_param(mdl,'ModelWorkspace');
  assignin(mw,'p',p);assignin(mw,'c',c);assignin(mw,'plant_p',actual);[Ad,Bd,x0]=p101_plant(actual);
  assignin(mw,'Ad',Ad);assignin(mw,'Bd',Bd);assignin(mw,'x0',x0);out=sim(mdl,'StopTime',num2str(p.duration));
  check.temperature_simulink_vs_mismatched_replay=max(abs(out.p101_states.Data-r.x),[],'all')<1e-10;
  close_system(mdl,0);
 end
end
check.minimum_profile_independent_holdout=max(errors)<2e-5;
check.calibration_improves_temperature_errors=mean(goodError)<mean(badError);
check.valid_temperature_carrier=all(isfinite(goodError))&&max(goodError)<.1;
try,p101_temperature_apply(base,c0,100);check.extrapolation_rejected=false;
catch err,check.extrapolation_rejected=strcmp(err.identifier,'p101:temperature');end
result=struct('checks',check,'cases',cases,'holdout_max_relative_error',max(errors),...
 'algorithm_decision','Minimal offline model passes fixture. PIR/online identification/TDM remain disabled; gradients/hysteresis not validated.');
p101_json(fullfile(ev,'matlab_temperature_results.json'),result);disp(check);assert(all(structfun(@logical,check)),'Temperature checks failed');
end
