function result=p101_verify_measurement()
root=fileparts(mfilename('fullpath'));addpath(root);ev=fullfile(root,'evidence');
if ~exist(ev,'dir'),mkdir(ev);end;p=p101_config;c=p101_calibration;
lsb=p.dac_span/2^p.dac_bits;[v,code,clip]=p101_quantize([-2 -1 0 1-lsb 1 2],2,18,1);
check.dac_signed_boundaries=isequal(code,[-131072 -131072 0 131071 131071 131071])&&max(v)<=1-lsb&&all(clip([1 5 6]));
[v,~,~]=p101_quantize([-1 1],2,18,.93);check.dac_physical_limit_after_round=all(abs(v)<=.93);
a=p.charge_target;
q=p101_validity([0;0],[0;0],p,false,1);check.zero_angle_rejected=~q.valid&&isnan(q.pattern_angle);
q=p101_validity([a;0],[0;a],p,false,1);check.circle_angle_rejected=~q.valid;
q=p101_validity([a;0],[0;0],p,true,1);check.clipped_angle_rejected=~q.valid;
q=p101_validity([NaN;0],[0;0],p,false,1);check.nonfinite_angle_rejected=~q.valid;
q=p101_validity([a;0],[0;0],p,false,1);check.line_angle_accepted=q.valid&&q.pattern_angle==0;
s=[];nw=round(p.Tc/p.Ts);
for k=1:2*nw+1,[s,~,dd]=p101_tick(s,zeros(4,1),p,c);if k==nw,completed=s;end;end
check.invalid_windows_not_scored=dd(8)==0&&s.id==2;
check.window_source_center=abs(completed.center-(nw-1)*p.Ts/2)<1e-14;
check.window_publication_latency=abs(completed.available-completed.frame_end-p.Ts)<1e-14;
check.initial_diagnostics_invalid=p101_state('init',p);check.initial_diagnostics_invalid=check.initial_diagnostics_invalid(27)==0;
r=p101_reference(p,c);[base,frames]=p101_metrics(r,p);
disp(base);
check.baseline_valid=base.valid_fraction>.95;
check.center_scored_whole_angle=isfinite(base.angle_rms_deg)&&base.angle_rms_deg<.1;
check.energy_5_percent=abs(base.energy_relative_mean)<.05;
check.no_dac_clip=base.dac_clip_samples==0;
check.build_time=isfinite(base.build_time_s)&&base.build_time_s<.7;
check.unique_frame_scoring=height(frames)==floor((numel(r.t)-1)/nw);
mdl=p101_build(p,c);out=sim(mdl);actual=out.p101_states.Data;u=out.p101_dac.Data;d=out.p101_diagnostics.Data;
check.simulink_state_scoreboard=isequal(size(actual),size(r.x))&&max(abs(actual-r.x),[],'all')<1e-10;
check.simulink_DAC_scoreboard=max(abs(u-r.u),[],'all')<1e-12;
finite=isfinite(d)&isfinite(r.d);check.simulink_diagnostics_scoreboard=isequal(isnan(d),isnan(r.d))&&max(abs(d(finite)-r.d(finite)))<1e-10;
set_param(mdl,'SimulationCommand','update');check.model_reopens=true;save_system(mdl);close_system(mdl,0);
load_system(fullfile(root,'models',[mdl '.slx']));set_param(mdl,'SimulationCommand','update');
check.model_reopens=bdIsLoaded(mdl);
% Stochastic ADC-input noise must enter the Simulink feedback loop as well as
% the scheduling replay; precomputed fixture prevents extra Outputs calls
% from advancing the random stream.
noisy=p;noisy.noise_rms_V=5e-6;rn=p101_reference(noisy,c);
mw=get_param(mdl,'ModelWorkspace');assignin(mw,'p',noisy);on=sim(mdl);
check.noisy_closed_loop_state_scoreboard=max(abs(on.p101_states.Data-rn.x),[],'all')<1e-10;
check.noisy_closed_loop_ADC_scoreboard=max(abs(on.p101_adc.Data-rn.adc),[],'all')<1e-12;
assignin(mw,'p',p);close_system(mdl,0);
pp=p;pp.calibrate_detection=false;uncal=p101_reference(pp,c);uncal=p101_metrics(uncal,pp);
check.independent_detection_profile_improves=base.angle_rms_deg<uncal.angle_rms_deg;
pp=p;pp.calibrate_drive=false;uncalDrive=p101_reference(pp,c);uncalDrive=p101_metrics(uncalDrive,pp);
check.independent_drive_profile_improves=base.pll_phase_rms<uncalDrive.pll_phase_rms;
result=struct('matlab',version,'synthetic_only',true,'checks',check,'baseline',base,'detection_uncalibrated',uncal,'drive_uncalibrated',uncalDrive);
p101_json(fullfile(ev,'measurement_results.json'),result);p101_json(fullfile(ev,'parameters.json'),p);
writetable(frames,fullfile(ev,'baseline_frames.csv'));writematrix([r.t r.u r.d],fullfile(ev,'baseline_samples.csv'));
[Ad,Bd,~,A,B]=p101_plant(p);writematrix(A,fullfile(ev,'A.csv'));writematrix(B,fullfile(ev,'B.csv'));writematrix(Ad,fullfile(ev,'Ad.csv'));writematrix(Bd,fullfile(ev,'Bd.csv'));
disp(check);assert(all(structfun(@(x)logical(x),check)),'V10.1 measurement acceptance failed');
end
