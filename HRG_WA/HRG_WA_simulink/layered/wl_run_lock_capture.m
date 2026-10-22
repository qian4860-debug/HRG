function report=wl_run_lock_capture(duration)
% Longer baseline: distinguish acquisition transient from steady evaluation.
if nargin<1,duration=5;end
root=fileparts(mfilename('fullpath'));folder=fullfile(root,'evidence','principle_acceptance');
campaign=jsondecode(fileread(fullfile(folder,'campaign_quick.json')));
assert(campaign.executionComplete,'Complete quick injection campaign first');
c=campaign.cases(1).configuration;c.duration=duration;
% JSON arrays decode as columns; this block expects one row of FIR taps.
c.fir=c.fir(:).';
[out,c]=wl_acceptance_sim(c);b=wl_acceptance_budget(c);m=wl_acceptance_metrics(out,c,b);
t=out.tap_iq.Time;x=out.tap_iq.Data;d=x(:,1:2)+1i*x(:,3:4);
E=sum(abs(d).^2,2);Qq=2*imag(conj(d(:,1)).*d(:,2));phi=.5*angle(sum(d.^2,2));
nav=interp1(out.tap_navigation.Time,out.tap_navigation.Data,t);
good=t>=.05 & nav(:,3)>.5 & abs(E/c.head.energyTarget-1)<=b.energyRelativeRms & abs(phi)<=b.lockPhaseRmsRad;
holdS=.1;n=ceil(holdS/c.head.Ts)+1;cs=[0;cumsum(double(good))];first=find(cs(n+1:end)-cs(1:end-n)>=n-.5,1);
capture=NaN;if ~isempty(first),capture=t(first);end
report=struct('durationS',duration,'captureTimeS',capture,'captureHoldS',holdS, ...
 'captureDefinition','first joint valid/energy/observed-phase interval maintained for 100 ms; precharged, NOT mechanical startup', ...
 'physicalRimEquivalentPeriods',abs(c.head.bryan*c.inputRate*duration)/(pi/2), ...
 'metrics',m,'baselineCase','same configuration as quick baseline, duration only changed', ...
 'notAssessed','Allan/ARW, multiple initial azimuths, full temperature/rate corners');
wl_write_json(fullfile(folder,'lock_capture.json'),report);
writematrix([t E Qq./max(E,eps) phi nav],fullfile(folder,'lock_capture_trace.csv'));
fig=figure('Visible','off','Position',[30 30 1200 800]);
subplot(3,2,1);plot(t,E);yline(c.head.energyTarget,'--');ylabel('Normalized IQ energy');grid on;
subplot(3,2,2);plot(t,Qq./max(E,eps));ylabel('Q/E');grid on;
subplot(3,2,3);plot(t,phi);yline(b.lockPhaseRmsRad,'--');yline(-b.lockPhaseRmsRad,'--');ylabel('Observed phase residual (rad)');grid on;
anchor=find(nav(:,3)>.5,1);truth=c.inputRate*(t-t(anchor));err=(nav(:,1)-nav(anchor,1))-truth;
subplot(3,2,4);plot(t,err*180/pi);ylabel('Angle increment error (deg)');grid on;
subplot(3,2,5);plot(t,(nav(:,2)-c.inputRate)*180/pi);ylabel('Rate tracking error (deg/s)');grid on;
subplot(3,2,6);r=m.saturation.rails;bar([r.headroomFraction]);xticks(1:numel(r));xticklabels({r.name});xtickangle(25);ylabel('Full-record headroom fraction');grid on;
for k=1:5,subplot(3,2,k);xlabel('Time (s)');end
sgtitle(sprintf('Precharged acquisition baseline: %.3g s, %.3g equivalent rim periods',duration,report.physicalRimEquivalentPeriods));
exportgraphics(fig,fullfile(folder,'lock_capture.png'));close(fig);
fprintf('Long baseline: capture %.6g s, %.4g rim periods, illustrative budget pass %d\n',capture,report.physicalRimEquivalentPeriods,m.pass);
end
