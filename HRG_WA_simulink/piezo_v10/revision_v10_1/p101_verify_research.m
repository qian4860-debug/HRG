function result=p101_verify_research()
root=fileparts(mfilename('fullpath'));ev=fullfile(root,'evidence');addpath(root);
ident=p101_verify_identification();check=ident.checks;p=p101_envelope_config;
wa=p101_envelope_reference(p);[mwa,thetaWA]=p101_low_metrics(wa,p);
pp=p;pp.virtual_rate=2;vr=p101_envelope_reference(pp);[mvr,thetaVR]=p101_low_metrics(vr,pp);
disp(mwa);disp(mvr);
check.low_rate_pinning=abs(mwa.estimated_rate_rad_s)<.01*p.Omega;
check.virtual_precession_compensated_improvement=mvr.absolute_rate_error<.1*mwa.absolute_rate_error;
check.virtual_force_voltage_headroom=mvr.max_required_voltage_V<p.vmax;
rot=p;delta=pi/7;rot.stiffness_axis=rot.stiffness_axis+delta;rot.damping_axis=rot.damping_axis+delta;rot.theta0=rot.theta0+delta;
rr=p101_envelope_reference(rot);[~,tt]=p101_low_metrics(rr,rot);
check.arbitrary_axes_rotation_covariance=max(abs((tt-tt(1))-(thetaWA-thetaWA(1))))<1e-8;
half=pp;half.envTs=pp.envTs/2;hh=p101_envelope_reference(half);mh=p101_low_metrics(hh,half);
check.low_rate_step_convergence=abs(mh.estimated_rate_rad_s-mvr.estimated_rate_rad_s)<1e-5;
mdl=p101_build_low_rate(p);out=sim(mdl);y=out.p101_envelope.Data;
check.low_rate_simulink_scoreboard=max(abs(y-wa.y),[],'all')<1e-9;
mw=get_param(mdl,'ModelWorkspace');assignin(mw,'p',pp);out=sim(mdl);
check.virtual_simulink_scoreboard=max(abs(out.p101_envelope.Data-vr.y),[],'all')<1e-9;
assignin(mw,'p',p);save_system(mdl);close_system(mdl,0);load_system(fullfile(root,'models',[mdl '.slx']));set_param(mdl,'SimulationCommand','update');check.low_rate_model_reopens=true;
% Carry arbitrary axes and virtual command through the full fast carrier too.
c=p101_calibration;cp=p101_config;cp.split_hz=.01;cp.damping_half_difference=.002;cp.stiffness_axis=.61;cp.damping_axis=-.29;
carrier=p101_reference(cp,c);mc=p101_metrics(carrier,cp);
check.carrier_arbitrary_axes_finite=all(isfinite(carrier.x),'all')&&mc.valid_fraction>.95&&abs(mc.energy_relative_mean)<.05;
vp=p101_config;vp.Omega=.005;vp.virtual_rate=.2;carrierVirtual=p101_reference(vp,c);mv=p101_metrics(carrierVirtual,vp);
check.carrier_virtual_command_accounted=mv.valid_fraction>.95&&mv.dac_clip_samples==0&&mv.angle_rms_deg<.3;
ug=vp;ug.virtual_start_min_s=0;ug.virtual_settle_fraction=1;ug.predict_heading=false;ur=p101_reference(ug,c);mu=p101_metrics(ur,ug);
check.unsettled_virtual_startup_regression=mu.angle_rms_deg>2*mv.angle_rms_deg;
stress=vp;stress.virtual_rate=2;
try,p101_reference(stress,c);check.high_rate_virtual_request_rejected=false;
catch err,check.high_rate_virtual_request_rejected=strcmp(err.identifier,'p101:virtualrate');end
result=struct('checks',check,'WA',mwa,'virtual',mvr,'half_step_virtual',mh,'carrier_arbitrary_axes',mc,'carrier_virtual',mv,'carrier_virtual_ungated_regression',mu,...
 'boundary','Synthetic first-order long-horizon envelope plus short full-carrier counterchecks; no hardware deadzone rating');
p101_json(fullfile(ev,'research_results.json'),result);p101_json(fullfile(ev,'envelope_parameters.json'),p);
writematrix([wa.t wa.y thetaWA vr.y thetaVR],fullfile(ev,'low_rate_traces.csv'));
disp(check);assert(all(structfun(@logical,check)),'V10.1 research checks failed');
end
