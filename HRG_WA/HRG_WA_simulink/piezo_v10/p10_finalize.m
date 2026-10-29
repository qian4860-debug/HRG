function p10_finalize
root=fileparts(mfilename('fullpath'));addpath(root);ev=fullfile(root,'evidence');p=p10_config;
[Ad,Bd,~,~,A,B]=p10_plant(p);
writematrix(A,fullfile(ev,'continuous_A.csv'));writematrix(B,fullfile(ev,'continuous_B.csv'));
writematrix(Ad,fullfile(ev,'discrete_A.csv'));writematrix(Bd,fullfile(ev,'discrete_B.csv'));
res=jsondecode(fileread(fullfile(ev,'results.json')));
res.checks.whole_angle_within_fixture_01deg=res.cases.baseline.angle_rms_deg<.1;
res.checks.quadrature_under_1e3=res.cases.baseline.quadrature_rms<1e-3;
res.checks.pll_phase_under_001=res.cases.baseline.pll_phase_rms<.01;
half=p;half.Ts=p.Ts/2;r=p10_reference(half);res.cases.half_step=p10_metrics(r.t,r.x,r.u,r.iq,half);
res.checks.sample_step_convergence=abs(res.cases.half_step.angle_rms_deg-res.cases.baseline.angle_rms_deg)<.02;
mdl='hrg_wa_v10_piezo';if bdIsLoaded(mdl),close_system(mdl,0);end
load_system(fullfile(root,'models',[mdl '.slx']));set_param(mdl,'SimulationCommand','update');
res.checks.reopened_compiled=true;res.scope_count=numel(find_system(mdl,'BlockType','Scope'));
res.spectrum_count=numel(find_system(mdl,'Regexp','on','Name','^Spectrum_(ADC|Driver)$'));
res.checks.native_observers=res.scope_count==10&&res.spectrum_count==2;
fid=fopen(fullfile(ev,'results.json'),'w');fprintf(fid,'%s\n',jsonencode(res,PrettyPrint=true));fclose(fid);
fid=fopen(fullfile(ev,'parameters.json'),'w');fprintf(fid,'%s\n',jsonencode(p,PrettyPrint=true));fclose(fid);
assert(all(structfun(@logical,res.checks)),'V10 final checks failed');disp(res.checks);
end
