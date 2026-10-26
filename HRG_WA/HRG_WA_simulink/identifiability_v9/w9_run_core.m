function report=w9_run_core()
r=fileparts(mfilename('fullpath'));addpath(r);p=w9_setup();
e=fullfile(r,'evidence');if ~isfolder(e),mkdir(e);end
checks=struct('name',{},'error',{},'limit',{},'pass',{});rng(20261026);
angle=(.03+(0:126)*sqrt(2))*2*pi;amplitude=.15+1.05*rand(1,numel(angle));
reference=[cos(angle);sin(angle)].*amplitude;
measured=round((p.sense_matrix*reference)/p.fixture_adc_step)*p.fixture_adc_step;
fit=w9_fit_detection(reference,measured);
check('independent_fixture_matrix_fit',norm(fit.matrix-p.sense_matrix,'fro'),p.acceptance.fixture_gain_relative_error);
writematrix([reference' measured'],fullfile(e,'detection_fixture.csv'));
rejected=false;try,w9_fit_detection([ones(1,20);zeros(1,20)],ones(2,20));catch,rejected=true;end
check('directionally_unexcited_fixture_rejected',double(~rejected),0);
t=(0:.01:2)';iq=exp(-.01*t)*[cos(.2) sin(.2)];rejected=false;
try,w9_fit_damping(t,iq);catch,rejected=true;end
check('fixed_angle_damping_fit_rejected',double(~rejected),0);
axis=[cos(4*p.damping_axis_rad) sin(4*p.damping_axis_rad);sin(4*p.damping_axis_rad) -cos(4*p.damping_axis_rad)];
truth=[pi*p.f0_hz/p.quality_factor;p.damping_anisotropy_per_s/2*cos(4*p.damping_axis_rad);p.damping_anisotropy_per_s/2*sin(4*p.damping_axis_rad)];
cases=struct('name',{},'rateDegS',{},'stepS',{},'raw',{},'corrected',{},'angleRmsRawRad',{},'angleRmsCorrectedRad',{});
for rate=p.holdout_rates_deg_s(:)'
 for refinement=0:1
  step=p.envelope_step_s/2^refinement;name=w9_build_envelope(p,fit.inverse,rate*pi/180,step,rate==80&&refinement==1);
  out=sim(name);t=out.tap_truth.Time;z=squeeze(out.tap_truth.Data);raw=squeeze(out.tap_raw.Data);cal=squeeze(out.tap_calibrated.Data);
  a=w9_fit_damping(t,raw);b=w9_fit_damping(t,cal);
  angle=@(x)unwrap(atan2(2*x(:,1).*x(:,2),x(:,1).^2-x(:,2).^2))/4;
  target=angle(z);eraw=(angle(raw)-angle(raw(1,:)))-(target-target(1));
  ecal=(angle(cal)-angle(cal(1,:)))-(target-target(1));
  rmsRaw=sqrt(mean(eraw.^2));rmsCal=sqrt(mean(ecal.^2));
  label=sprintf('envelope_%+g_%d',rate,refinement);
  writematrix([t z raw cal],fullfile(e,[label '.csv']));
  rel=norm([b.gamma;b.dc;b.ds]-truth)/norm(truth(2:3));
  check([label '_damping'],rel,p.acceptance.envelope_damping_relative_error);
  check([label '_angle'],rmsCal/rmsRaw,p.acceptance.envelope_angle_improvement_ratio);
  cases(end+1)=struct('name',label,'rateDegS',rate,'stepS',step,'raw',a,'corrected',b, ...
   'angleRmsRawRad',rmsRaw,'angleRmsCorrectedRad',rmsCal);
  close_system(name,0);
 end
end
drift=p.sense_matrix*diag([1.001,.999])*reference;
residual=norm(fit.inverse*drift-reference,'fro')/norm(reference,'fro');
check('frozen_calibration_drift_is_detectable',double(residual<5e-4),0);
biasCases=struct('name',{},'voltageV',{},'mode',{},'stepS',{},'frequencyHz',{});
for V=[p.reference_bias_v,p.bias_holdout_v]
 for mode={'bare','reference','double_count'}
  for refinement=0:1
   step=p.carrier_reference_step_s/2^refinement;
   name=w9_build_bias(p,mode{1},V,step,strcmp(mode{1},'reference')&&V==p.reference_bias_v&&refinement==1);
   out=sim(name);t=out.tap_q.Time;q=squeeze(out.tap_q.Data);velocity=squeeze(out.tap_p.Data);
   freq=zeros(1,2);
   for j=1:2
    ind=find(q(1:end-1,j)>0&q(2:end,j)<=0);
    cross=t(ind)-q(ind,j).*(t(ind+1)-t(ind))./(q(ind+1,j)-q(ind,j));
    line=polyfit((0:numel(cross)-1)',cross,1);freq(j)=1/line(1);
   end
   label=sprintf('bias_%s_V%g_%d',mode{1},V,refinement);
   w9_write_bias_evidence(t,q,velocity,label,e);
   biasCases(end+1)=struct('name',label,'voltageV',V,'mode',mode{1},'stepS',step,'frequencyHz',freq);
   fprintf('%s: f=[%.10f %.10f] Hz\n',label,freq);close_system(name,0);
  end
 end
end
report=struct('date','2026-10-26','profile',p,'checks',checks,'pass',all([checks.pass]), ...
 'detectionFit',fit,'trueDampingCoefficients',truth,'envelopeCases',cases,'biasCases',biasCases, ...
 'frozenDriftResidual',residual,'scope','Envelope identification and native carrier mechanics; RF control assessed separately');
wl_write_json(fullfile(e,'core_study.json'),report);
assert(report.pass,'Core study failure: retain evidence before changing anything');
 function check(n,error,limit)
  checks(end+1)=struct('name',n,'error',error,'limit',limit,'pass',isfinite(error)&&error<=limit);
  fprintf('%s: %.12g <= %.12g : %d\n',n,error,limit,checks(end).pass);
 end
end
