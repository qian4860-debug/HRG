function result=quality_verify()
root=quality_setup;p=pcn_config;c=pcn_calibration;mdl=quality_build;out=sim(mdl);r=pcn_reference(p,c);
checks.observer_preserves_states=max(abs(out.p103_states.Data-r.x),[],'all')<1e-12;
checks.observer_preserves_DAC=isequal(out.p103_dac.Data,r.u);
report=quality_report(out,p,false);checks.baseline_quality_pass=all(structfun(@logical,report.checks));
checks.frame_count=report.metrics.total_frames==800;
z=out.p103_diagnostics.Data(end,:)';z(8)=0;y=quality_values(z,p);checks.invalid_residual_is_NaN=all(isnan(y(2:5)))&&y(9)==0;
z(8)=1;z(18)=1;y=quality_values(z,p);checks.clipped_frame_invalid=y(9)==0&&all(isnan(y(2:5)));
bad=r;bad.d(:,8)=0;bm=pcn_metrics(bad,p);checks.no_valid_frames_no_angle_score=isnan(bm.angle_rms_deg);
checks.Q_and_phase_match_original=abs(report.quadrature_RMS-report.metrics.quadrature_rms)<1e-14&&abs(report.PLL_detector_RMS-report.metrics.pll_phase_rms)<1e-14;
close_system(mdl,0);load_system(fullfile(root,'models',[mdl '.slx']));set_param(mdl,'SimulationCommand','update');checks.saved_model_reopens=true;
result=struct('checks',checks);pcn_json(fullfile(root,'evidence','verification.json'),result);disp(checks);assert(all(structfun(@logical,checks)));
end
