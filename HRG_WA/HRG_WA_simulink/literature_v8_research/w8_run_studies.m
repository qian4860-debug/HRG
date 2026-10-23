function report=w8_run_studies()
% Synthetic fixture -> freeze -> held-out closed loops. No V7 evidence writes.
r=fileparts(mfilename('fullpath'));addpath(r);c=w8_setup(w8_config());
folder=fullfile(r,'evidence');if ~isfolder(folder),mkdir(folder);end
cleanup=onCleanup(@close_v8_models); %#ok<NASGU>
checks=struct('name',{},'error',{},'limit',{},'pass',{});
 q=c;q.iqFractionBits=0;
ang=linspace(-pi,pi,701)';z=[cos(2*ang) sin(2*ang)].*exp(.37i);
M=[1.012 .006;-.004 .989];A=[1.018 -.003;.002 .982];
train=linspace(0,2*pi,43)';ref=[cos(train) sin(train)]';meas=M*ref;
Mfit=meas/ref;Afit=(A*ref)/ref;
check('matrix_fixture_fit',norm(Mfit-M,'fro'),1e-12);
q.v8.enabled=true;q.v8.senseInverse=inv(Mfit);
raw=zeros(size(z));corrected=raw;
for k=1:size(z,1)
 d=M*z(k,:).';raw(k,:)=d.';
 y=w8_iq([real(d/q.v7.senseCalibration);imag(d/q.v7.senseCalibration)],q);
 corrected(k,:)=y(1:2).'+1i*y(3:4).';
end
check('heldout_matrix_waveforms',max(abs(corrected-z),[],'all'),1e-12);
% Diagonal nonlinear calibration needs amplitude diversity, not one operating point.
rho=.08;amplitudes=linspace(.08,1.25,79)';phases=.63*sin((1:79)');
x=[amplitudes.*exp(1i*phases) flipud(amplitudes).*exp(-1i*phases)];
G=[1.012; .989];beta=.75*rho^2*G.^2;
y=x.*G.'.*(1+abs(x).^2.*beta.');
fit=w8_fit_diagonal(x,y);
check('cubic_fixture_coefficients',max(abs(fit.cubicCoefficient-beta)),1e-12);
q.v8.senseInverse=fit.senseInverse;q.v8.cubicCoefficient=fit.cubicCoefficient;
ztest=[.73+.24i;-.39+.51i];d=G.*ztest.*(1+beta.*abs(ztest).^2);
y=w8_iq([real(d/q.v7.senseCalibration);imag(d/q.v7.senseCalibration)],q);
check('heldout_cubic_inverse',norm(y-[real(ztest);imag(ztest)]),1e-12);
% Failure case: calibration outside the supported amplitude domain must not extrapolate.
d=[3;0];y=w8_iq([real(d/q.v7.senseCalibration);imag(d/q.v7.senseCalibration)],q);
expected=q.v8.senseInverse*d;
check('out_of_range_does_not_extrapolate',abs(y(1)-real(expected(1))),1e-12);
% Thermal-force covariance: independent thermodynamic equilibrium oracle.
Ad=[cos(4*c.head.dampingAxis) sin(4*c.head.dampingAxis);sin(4*c.head.dampingAxis) -cos(4*c.head.dampingAxis)];
D=2*c.head.gamma*eye(2)+c.head.dgamma*Ad;L=chol(D/(2*c.head.gamma),'lower');
check('FDT_noise_matrix',norm(2*c.head.gamma*(L*L')-D,'fro'),1e-14);
K=(2*pi*c.head.f0)^2*eye(2);Ap=[zeros(2) eye(2);-K -D];
kT=1.380649e-23*c.temperatureK/c.massKg;
P=blkdiag(kT*inv(K),kT*eye(2));N=blkdiag(zeros(2),2*kT*D);
check('FDT_equipartition_Lyapunov',norm(Ap*P+P*Ap'+N,'fro')/norm(N,'fro'),1e-12);
test=w8_feedback_gate([1;2;3;4;c.v8.filterWarmupS-c.head.Ts],c);
check('warmup_IQ_is_invalid',norm(test),0);
test=w8_feedback_gate([1;2;3;4;c.v8.filterWarmupS],c);
check('warmup_releases_at_configured_epoch',norm(test-[1;2;3;4]),0);
test=w8_control_tick(zeros(28,1),c);
check('warmup_cannot_torque_precharged_head',norm(test(18:21)),0);

% Paired long envelope runs: exact same nominal scalar inverse and PI/PIR.
base=c;base.noiseEnable=false;base.observers=false;base.spectra=false;
base.v8.calibrationSource='synthetic independent-reference fixture; not measured hardware';
base.duration=8;base.head.dgamma=0;base.head.splitHz=0;base.head.detuningHz=0;
base.head.duffingHz=0;base.head.initialQuadRatio=0;
base.inputRate=80*pi/180;base.inputRateAmplitude=0;
cases=struct('name',{},'metrics',{});
for group=1:3
 t=base;
 if group==1
  label='linear_matrix';t.head.detect=M;t.head.drive=A;
  t.v8.senseInverse=inv(Mfit);t.v8.driveInverse=inv(Afit);
 elseif group==2
  label='diagonal_cubic';t.displacementM=rho*t.gapM;t.head.detect=diag(G);
  t.driverGain=[1.018; .982];t.v8.senseInverse=fit.senseInverse;
  t.v8.driveInverse=diag(1./t.driverGain);t.v8.cubicCoefficient=fit.cubicCoefficient;
 else
  label='calibration_drift';t.displacementM=rho*t.gapM;t.head.detect=diag(G.*[1.001;.999]);
  t.driverGain=[1.018; .982];t.v8.senseInverse=fit.senseInverse;
  t.v8.driveInverse=diag(1./t.driverGain);t.v8.cubicCoefficient=.8*fit.cubicCoefficient;
 end
 for on=0:1
  t.v8.enabled=logical(on);t.name=sprintf('hrg_wa_v8_%s_%d',label,on);
  name=w8_build(t,'envelope',false);w8_setup(t);out=sim(name);
  m=envelope_metrics(out,t,fullfile(folder,[label '_' num2str(on) '.csv']));
  cases(end+1)=struct('name',[label '_' num2str(on)],'metrics',m);
  fprintf('%s: angle=%g deg energy=%g Q=%g\n',cases(end).name,m.angleRmsDeg,m.mechanicalEnergyRms,m.quadratureRms);
  close_system(name,0);
 end
end
check('matrix_closed_loop_angle_improves',cases(2).metrics.angleRmsDeg/cases(1).metrics.angleRmsDeg,.2);
check('cubic_closed_loop_angle_improves',cases(4).metrics.angleRmsDeg/cases(3).metrics.angleRmsDeg,.2);

% RF carrier retains exact C(q), ADC, DAC, delays and all public metric groups.
carrier=base;carrier.duration=1;carrier.fsPlant=800000;
carrier.displacementM=rho*carrier.gapM;carrier.head.detect=diag(G);
carrier.driverGain=[1.018;.982];carrier.v8.senseInverse=fit.senseInverse;
carrier.v8.driveInverse=diag(1./carrier.driverGain);carrier.v8.cubicCoefficient=fit.cubicCoefficient;
carrier.maxLogPoints=ceil(carrier.duration*carrier.fsPlant)+1;
rf=struct('name',{},'metrics',{});saved='';
for on=0:2
 carrier.v8.enabled=on==2;carrier.v8.filterWarmupS=.012*double(on>0);
 carrier.name=sprintf('hrg_wa_v8_carrier_%d',on);
 name=w8_build(carrier,'carrier',on==2);w8_setup(carrier);out=sim(name);
 m=w7_metrics(out,carrier);rf(end+1)=struct('name',name,'metrics',m);
 wl_write_json(fullfile(folder,[name '_configuration.json']),jsonable(rmfield(carrier,'legacyP')));
 iq=out.tap_iq;writematrix([iq.Time squeeze(iq.Data)],fullfile(folder,[name '_iq.csv']));
 nav=out.tap_navigation;writematrix([nav.Time squeeze(nav.Data)],fullfile(folder,[name '_navigation.csv']));
 for node={'adc','driver','dac','dac_requested','force','head_displacement','head_velocity','cv_actual'}
  ts=out.(['tap_' node{1}]);sel=ts.Time>=carrier.duration-8/carrier.head.f0;
  writematrix([ts.Time(sel) ts.Data(sel,:)],fullfile(folder,[name '_' node{1} '_tail.csv']));
 end
 if on==2,saved=fullfile(r,'models',[name '.slx']);end
 close_system(name,0);
end
% Saved model must re-open without the caller having left wl_c in the base workspace.
evalin('base','clear wl_c');load_system(saved);[~,nm]=fileparts(saved);
set_param(nm,'SimulationCommand','update');
scopes=numel(find_system(nm,'BlockType','Scope'));spectra=numel(find_system(nm,'MaskType','Spectrum Analyzer'));
close_system(nm,0);
report=struct('date','2026-10-24','checks',checks,'unitAndStudyPass',all([checks.pass]), ...
 'fixture',struct('matrixFit',Mfit,'actuatorFit',Afit,'diagonalFit',fit, ...
 'source','Synthetic independent-reference fixture; not measurements or deployable in-device identification'), ...
 'envelopeCases',cases,'carrierCases',rf,'savedModelReopenedAndCompiled',true,'scopes',scopes,'spectra',spectra, ...
 'limitations',{{'Envelope excludes RF noise/harmonics and exact capacitor higher orders', ...
 'Matrix and cubic joint calibration validated only for diagonal cubic channels', ...
 'Third-harmonic online estimator not inserted in feedback', ...
 'Short RF records do not establish ARW, bias instability, low-speed or PVT qualification'}});
wl_write_json(fullfile(folder,'studies.json'),jsonable(report));
assert(report.unitAndStudyPass,'V8 exploratory scoreboard failed; inspect retained evidence');
 function check(n,e,l)
  checks(end+1)=struct('name',n,'error',e,'limit',l,'pass',isfinite(e)&&e<=l);
  fprintf('%s: %.9g <= %.9g : %d\n',n,e,l,checks(end).pass);
 end
end

function v=jsonable(v)
if isnumeric(v)&&~isreal(v),v=struct('real',real(v),'imaginary',imag(v));
elseif isstruct(v)
 for k=1:numel(v),for field=fieldnames(v).',v(k).(field{1})=jsonable(v(k).(field{1}));end,end
elseif iscell(v),for k=1:numel(v),v{k}=jsonable(v{k});end
end
end

function close_v8_models()
names=find_system('Type','block_diagram');
for k=1:numel(names)
 if startsWith(names{k},'hrg_wa_v8_'),close_system(names{k},0);end
end
end

function m=envelope_metrics(out,c,path)
z=squeeze(out.tap_envelope.Data);d=squeeze(out.tap_iq.Data);t=out.tap_iq.Time;
assert(size(z,2)==4&&size(d,2)==4);
z=z(:,1:2)+1i*z(:,3:4);d=d(:,1:2)+1i*d(:,3:4);
R=abs(d(:,1)).^2-abs(d(:,2)).^2;S=2*real(conj(d(:,1)).*d(:,2));
theta=unwrap(atan2(S,R))/4;psi=-theta/c.head.bryan;
epoch=find(t>=1,1);error=psi-psi(epoch)-c.inputRate*(t-t(epoch));use=t>=1;
E=sum(abs(d).^2,2);Q=2*imag(conj(d(:,1)).*d(:,2));Em=sum(abs(z).^2,2);
phase=.5*angle(sum(d.^2,2));rate=[0;diff(psi)./diff(t)];
m=struct('angleRmsDeg',sqrt(mean(error(use).^2))*180/pi,'anglePeakDeg',max(abs(error(use)))*180/pi, ...
 'energyRms',sqrt(mean((E(use)-c.head.energyTarget).^2)), ...
 'mechanicalEnergyRms',sqrt(mean((Em(use)-c.head.energyTarget).^2)), ...
 'quadratureRms',sqrt(mean((Q(use)./E(use)).^2)),'phaseRmsRad',sqrt(mean(phase(use).^2)), ...
 'rateResidualRmsDegS',sqrt(mean((rate(use)-c.inputRate).^2))*180/pi, ...
 'epochS',t(epoch),'zeroBiasStatus','not zero-rate; not evaluated', ...
 'buildAndSaturationStatus','not accepted from envelope; use carrier scoreboard', ...
 'finite',all(isfinite([z(:);d(:)])));
writematrix([t error*180/pi E Em Q./max(E,eps) phase rate*180/pi],path);
end
