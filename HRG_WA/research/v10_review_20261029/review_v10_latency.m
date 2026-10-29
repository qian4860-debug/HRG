function review_v10_latency
% Audit only: no change to the sealed V10 controller, parameters or metrics.
here=fileparts(mfilename('fullpath'));root=fileparts(fileparts(here));
addpath(fullfile(root,'HRG_WA_simulink','piezo_v10'));
p=p10_config;r=p10_reference(p);t=r.t;
I=r.iq(:,1:2);Q=r.iq(:,3:4);
theta_iq=ellipse_angle(I,Q);
theta_state=ellipse_angle(r.x(:,1:2),r.x(:,3:4)/(2*pi*p.f0));
truth=(p.alpha0-2*p.B*p.Omega*t)/2;hold=t>.6*p.duration;
N=round(p.Tc/p.Ts);k=(0:numel(t)-1)';window=floor(k/N);
% diag is emitted before the new window is committed in p10_tick.
mid=((window-1)*N+(N-1)/2)*p.Ts;
valid=hold & window>=1;
state_at_window_mid=interp1(t,theta_state,mid(valid),'linear');
scale=180/pi/abs(p.B);
m=struct('synthetic_only',true,'matlab',version,...
 'original_metrics',p10_metrics(t,r.x,r.u,r.iq,p),...
 'state_ellipse_vs_truth_carrier_rms_deg',rms(theta_state(valid)-truth(valid))*scale,...
 'iq_vs_current_state_carrier_rms_deg',rms(theta_iq(valid)-theta_state(valid))*scale,...
 'iq_vs_window_mid_state_carrier_rms_deg',rms(theta_iq(valid)-state_at_window_mid)*scale,...
 'window_age_min_s',min(t(valid)-mid(valid)),...
 'window_age_max_s',max(t(valid)-mid(valid)),...
 'checks',struct('finite',all(isfinite(theta_iq(valid)))&&all(isfinite(theta_state(valid))),...
 'baseline_reproduced',abs(p10_metrics(t,r.x,r.u,r.iq,p).angle_rms_deg-.074850716261878836)<1e-6,...
 'window_mid_reduces_iq_state_disagreement',rms(theta_iq(valid)-state_at_window_mid)<rms(theta_iq(valid)-theta_state(valid))));
% The q,v/w construction is a narrowband diagnostic, not an exact observer
% under all nonidealities. Timestamp alignment is fixed from scheduling,
% never fitted to the truth/error to manufacture accuracy.
fid=fopen(fullfile(here,'latency_audit.json'),'w');fwrite(fid,jsonencode(m,PrettyPrint=true));fclose(fid);
disp(m);assert(all(structfun(@(x)x,m.checks)));
end
function theta=ellipse_angle(I,Q)
U=I(:,1).^2+Q(:,1).^2-I(:,2).^2-Q(:,2).^2;
V=2*(I(:,1).*I(:,2)+Q(:,1).*Q(:,2));
theta=unwrap(atan2(V,U))/4;
end
