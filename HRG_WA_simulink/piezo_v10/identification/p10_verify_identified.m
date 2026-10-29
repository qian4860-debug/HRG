function p10_verify_identified
root=fileparts(mfilename('fullpath'));addpath(fileparts(root));addpath(root);
path=fullfile(root,'identified_profile.json');r=jsondecode(fileread(path));p=p10_config;
blocked=false;try,p10_apply_identified(path,p,true);catch ME,blocked=contains(ME.message,'must be supplied independently');end
assert(blocked,'Missing independent limits should block import');
% Explicit synthetic bench settings only. Not manufacturer ratings or measurements.
r.bryan_factor=p.B;r.drive_voltage_limit_V=p.vmax;r.displacement_limit_m=2*p.amp;
tmp=fullfile(root,'synthetic_complete_profile.json');fid=fopen(tmp,'w');fprintf(fid,'%s',jsonencode(r));fclose(fid);
identified=p10_apply_identified(tmp,p,true);baseline=p10_reference(p);test=p10_reference(identified);
m0=p10_metrics(baseline.t,baseline.x,baseline.u,baseline.iq,p);
m1=p10_metrics(test.t,test.x,test.u,test.iq,identified);
checks=struct('blocks_missing_independent_limits',blocked,...
 'energy_within_5percent',abs(m1.energy_relative_mean)<.05,...
 'angle_within_01degree',m1.angle_rms_deg<.1,...
 'angle_vs_original_under_002degree',abs(m1.angle_rms_deg-m0.angle_rms_deg)<.02);
out=struct('scope','Synthetic offline identification followed by V10 MATLAB closed-loop replay; not new full Simulink acceptance',...
 'checks',checks,'baseline',m0,'identified',m1);
fid=fopen(fullfile(root,'matlab_identification_checks.json'),'w');fprintf(fid,'%s\n',jsonencode(out,PrettyPrint=true));fclose(fid);
assert(all(structfun(@logical,checks)));disp(checks);
end
