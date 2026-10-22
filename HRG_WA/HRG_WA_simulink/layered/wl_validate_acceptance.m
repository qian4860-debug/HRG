function report=wl_validate_acceptance()
% Analytic independent metric oracles + actual Simulink regressions.
root=fileparts(mfilename('fullpath'));addpath(root);checks=struct('name',{},'value',{},'limit',{},'pass',{});
c=wl_config(4);c.duration=.2;c.noiseEnable=false;c.head.splitHz=0;c.head.dgamma=0;c.head.duffingHz=0;
b=wl_acceptance_budget(c);[out,psi]=fixture(c);m=wl_acceptance_metrics(out,c,b);
check('ideal_angle_reference',m.angle.peakDeg,1e-10);
check('ideal_energy',m.energy.relativeRms,1e-12);
check('ideal_quadrature',m.quadrature.invariantRatioRms,1e-12);
check('ideal_phase',m.lock.phaseRmsRad,1e-12);
check('precharged_is_not_startup',double(~strcmp(m.build.status,'not_assessed_precharged')),0);
check('ideal_budget_pass',double(~m.pass),0);
% Independent known navigation drift must NOT be fitted/removed by scoreboard.
a=out.tap_navigation;a.Data(:,1)=psi+.2*pi/180*a.Time;out.tap_navigation=a;
m=wl_acceptance_metrics(out,c,b);check('known_accumulated_angle_error',abs(m.angle.peakDeg-.04),1e-10);
% Inject a known ellipse with signed minor/major r=0.1 and common phase 0.07.
[out,~]=fixture(c);a=out.tap_iq;t=a.Time;alpha=2*(c.head.initialTheta-c.head.bryan*c.inputRate*t);
r=.1;major=1/sqrt(1+r*r);minor=r*major;
d=[major*cos(alpha)-1i*minor*sin(alpha),major*sin(alpha)+1i*minor*cos(alpha)]*exp(1i*.07);
a.Data=[real(d) imag(d)];out.tap_iq=a;m=wl_acceptance_metrics(out,c,b);
check('ellipse_invariant',abs(m.quadrature.invariantRatioRms-2*r/(1+r*r)),1e-12);
check('ellipse_minor_major',abs(m.quadrature.minorMajorRatioRms-r),1e-12);
check('known_phase_error',abs(m.lock.phaseRmsRad-.07),1e-12);
% Independent mechanical ramp reaches 98% at t=0.049, then holds.
[out,~]=fixture(c);c.head.initialEnergy=.04;b.holdS=.02;
a=out.tap_head_displacement;v=out.tap_head_velocity;E=min(1,.04+.96*a.Time/.05);
a.Data=a.Data.*sqrt(E);v.Data=v.Data.*sqrt(E);out.tap_head_displacement=a;out.tap_head_velocity=v;
m=wl_acceptance_metrics(out,c,b);expected=.05*(.98-.04)/.96;
check('known_seeded_build_time',abs(m.build.timeS-expected),1/c.fsPlant+eps);
c.head.initialEnergy=1;
[out,~]=fixture(c);a=out.tap_accept_afe_request;a.Data(:)=2*c.afeLimitV;out.tap_accept_afe_request=a;
m=wl_acceptance_metrics(out,c,b);check('hidden_AFE_overload',abs(m.saturation.minimumHeadroomFraction+1),1e-12);
check('overload_fails_budget',double(m.pass),0);
[out,~]=fixture(c);a=out.tap_head_displacement;a.Data(1,1)=NaN;out.tap_head_displacement=a;
m=wl_acceptance_metrics(out,c,b);check('corrupt_mechanical_trace_fails_even_with_valid_nav',double(m.pass),0);
[out,~]=fixture(c);a=out.tap_navigation;a.Data(:,3)=0;out.tap_navigation=a;
m=wl_acceptance_metrics(out,c,b);check('all_invalid_fails_closed',double(m.pass),0);
c.inputRate=0;[out,~]=fixture(c);a=out.tap_navigation;a.Data(:,2)=.1*pi/180;out.tap_navigation=a;
m=wl_acceptance_metrics(out,c,b);check('known_zero_input_mean',abs(m.zeroBias.shortRunMeanDegS-.1),1e-12);
check('short_record_does_not_claim_bias_instability',double(~startsWith(m.zeroBias.biasInstabilityStatus,'not_assessed')),0);
% Full-rim algebra oracle across many atan2 branches and nonzero common phase.
theta=linspace(-pi,pi,1025)';d=[cos(2*theta) sin(2*theta)]*exp(.37i);
rr=abs(d(:,1)).^2-abs(d(:,2)).^2;ss=2*real(conj(d(:,1)).*d(:,2));
check('four_theta_identity',max(abs(rr+1i*ss-exp(4i*theta))),1e-12);
decoded=unwrap(atan2(ss,rr))/4;check('physical_rim_unwrap',max(abs((decoded-decoded(1))-(theta-theta(1)))),1e-12);
% Independent RK4 loss budget for the actual default step, and half-step bound.
g=pi*c.head.f0/c.head.Q;
for fs=[400000 800000]
 z=1i*2*pi*c.head.f0/fs;P=1+z+z^2/2+z^3/6+z^4/24;loss=-fs*log(abs(P));
 if fs==400000,limit=.1;else,limit=.005;end
 check(sprintf('RK4_numerical_loss_fraction_%d_Hz',fs),loss/g,limit);
end
% Native closed-loop run: absence of switches vs explicit all-on must agree.
c=wl_config(4);c.duration=.08;[a,c]=wl_acceptance_sim(c);
c.noiseSourceEnable=struct('cv',true,'pga',true,'driver',true,'jitter',true,'brownian',true);
[d,~]=wl_acceptance_sim(c);names=who(a);names=names(startsWith(names,'tap_'));
for k=1:numel(names),check([names{k} '_default_noise_compatibility'],max(abs(a.(names{k}).Data(:)-d.(names{k}).Data(:))),1e-10);end
for source={'cv','pga','driver','jitter','brownian'},c.noiseSourceEnable.(source{1})=false;end
wl_setup(c);vars={'wl_cvNoiseVariance','wl_pgaNoiseVariance','wl_driverNoiseVariance','wl_jitterVariance','wl_brownVariance'};
for k=1:numel(vars),check([vars{k} '_off'],evalin('base',vars{k}),0);end
c.noiseSourceEnable.cv=true;wl_setup(c);check('CV_independent_enable',double(evalin('base','wl_cvNoiseVariance')<=0),0);
check('CV_does_not_enable_jitter',evalin('base','wl_jitterVariance'),0);
c.noiseEnable=false;c.head.initialEnergy=0;[cold,c]=wl_acceptance_sim(c);
check('zero_state_is_legal_and_stationary',max(abs(cold.tap_head_displacement.Data(:))),0);
check('zero_state_has_no_feedback_drive',max(abs(cold.tap_driver.Data(:))),0);
cm=wl_acceptance_metrics(cold,c);check('zero_state_does_not_claim_startup',double(cm.pass),0);
p=c.head;p.initialEnergy=-1;rejected=false;
try,wa_validate_parameters(p);catch,rejected=true;end
check('negative_initial_energy_rejected',double(~rejected),0);
report=struct('checks',checks,'pass',all([checks.pass]),'oracle','analytic synthetic traces and actual Simulink same-clock comparisons');
folder=fullfile(root,'evidence','principle_acceptance');if ~isfolder(folder),mkdir(folder);end
wl_write_json(fullfile(folder,'scoreboards.json'),report);assert(report.pass,'Unified acceptance regression failed');
fprintf('PASS %d unified acceptance checks.\n',numel(checks));
 function check(name,value,limit)
  ok=isfinite(value)&&value<=limit;checks(end+1)=struct('name',name,'value',value,'limit',limit,'pass',ok);
  fprintf('%s %.9g <= %.9g : %d\n',name,value,limit,ok);
 end
end
function [out,psi]=fixture(c)
t=(0:c.head.Ts:c.duration)';psi=c.inputRate*t;theta=c.head.initialTheta-c.head.bryan*psi;
iq=[cos(2*theta) sin(2*theta) zeros(numel(t),2)];
out=Simulink.SimulationOutput;out.tap_navigation=timeseries([psi c.inputRate+zeros(size(t)) ones(size(t)) theta],t);
out.tap_iq=timeseries(iq,t);out.tap_control_commands=timeseries(zeros(numel(t),3),t);
th=(0:1/c.fsPlant:c.duration)';alpha=2*(c.head.initialTheta-c.head.bryan*c.inputRate*th);w=2*pi*c.head.f0;
u=[cos(alpha) sin(alpha)];q=u.*cos(w*th);v=-w*u.*sin(w*th);
out.tap_head_displacement=timeseries(q,th);out.tap_head_velocity=timeseries(v,th);
for name={'sample_hold','dac_requested','pga','driver','accept_afe_request','accept_driver_request'}
 out.(['tap_' name{1}])=timeseries(zeros(numel(t),2),t);
end
end
