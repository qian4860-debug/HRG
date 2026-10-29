function result=p10_run
root=fileparts(mfilename('fullpath'));addpath(root);ev=fullfile(root,'evidence');if ~exist(ev,'dir'),mkdir(ev);end
p=p10_config;mdl=p10_build(p);out=sim(mdl);
t=out.p10_states.Time;x=out.p10_states.Data;u=out.p10_control.Data;iq=out.p10_iq.Data;
r=p10_reference(p);check=struct;
check.time_grid=isequal(size(t),size(r.t))&&max(abs(t-r.t))<1e-10;
check.state_scoreboard=max(abs(x-r.x),[],'all')<1e-10;
check.control_scoreboard=max(abs(u-r.u),[],'all')<1e-8;
base=p10_metrics(t,x,u,iq,p);
cases=struct;cases.baseline=base;
names={'gain_uncalibrated','gain_calibrated','load_changed','drive_uncompensated','drive_compensated'};
for j=1:numel(names)
 pp=p;
 switch j
 case 1,pp.gain_y=1.05;pp.calibrate=false;
 case 2,pp.gain_y=1.05;
 case 3,pp.Rs=2e4;
 case 4,pp.drive_y=1.1;pp.compensate_drive=false;
 case 5,pp.drive_y=1.1;
 end
 rr=p10_reference(pp);cases.(names{j})=p10_metrics(rr.t,rr.x,rr.u,rr.iq,pp);
end
check.finite_states=all(isfinite(x),'all');check.no_saturation=base.drive_margin_V>0;
check.energy_within_5_percent=abs(base.energy_relative_mean)<.05;
check.build_within_800ms=isfinite(base.build_time_s)&&base.build_time_s<.8;
check.gain_compensation=cases.gain_calibrated.angle_rms_deg<cases.gain_uncalibrated.angle_rms_deg;
check.drive_compensation=cases.drive_compensated.angle_rms_deg<cases.drive_uncompensated.angle_rms_deg;
result=struct('matlab',version,'synthetic_only',true,'checks',check,'cases',cases);
writejson(fullfile(ev,'results.json'),result);writejson(fullfile(ev,'parameters.json'),p);
ix=1:40:numel(t);writetable(array2table([t(ix) x(ix,1:2) iq(ix,1:4) u(ix,:)],'VariableNames',{'t','x','y','Ix','Iy','Qx','Qy','DACx','DACy'}),fullfile(ev,'traces.csv'));
f=figure('Visible','off');subplot(3,1,1);plot(t,x(:,1:2));ylabel('q [m]');subplot(3,1,2);plot(t,iq(:,1:4));ylabel('IQ [m]');subplot(3,1,3);plot(t,u);ylabel('DAC [V]');xlabel('t [s]');exportgraphics(f,fullfile(ev,'waveforms.png'));close(f);
save_system(mdl);assert(all(structfun(@(v)logical(v),check)),'p10:acceptance','One or more checks failed; inspect results.json');
disp(result);
end
function writejson(path,v)
fid=fopen(path,'w');cleanup=onCleanup(@()fclose(fid));fprintf(fid,'%s\n',jsonencode(v,PrettyPrint=true));
end
