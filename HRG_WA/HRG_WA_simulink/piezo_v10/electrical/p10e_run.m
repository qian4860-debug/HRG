function result=p10e_run
root=fileparts(mfilename('fullpath'));addpath(root);addpath(fileparts(root));ev=fullfile(root,'evidence');if ~exist(ev,'dir'),mkdir(ev);end
p=p10e_config(fullfile(fileparts(root),'identification/identified_profile.json'));p.Rs=1000;
mdl=p10e_build(p);o=sim(mdl);t=o.e_state.Time;x=o.e_state.Data;u=o.e_dac.Data;iq=o.e_iq.Data;
[Ad,Bd,xx,H,A,B]=p10e_plant(p);s=[];xr=zeros(size(x));ur=zeros(size(u));
for k=1:numel(t)
 y=xx(11:12).*[1;p.gain_y];lsb=p.adc_span/2^p.adc_bits;y=round(max(-p.adc_span/2,min(p.adc_span/2-lsb,y))/lsb)*lsb;
 [s,uk,~]=p10e_tick(s,y,p,H);xr(k,:)=xx';ur(k,:)=uk';xx=Ad*xx+Bd*uk;
end
hold=t>.4;amp=sqrt(sum(iq(:,1:4).^2,2));
checks=struct('state_scoreboard',max(abs(x-xr),[],'all')<1e-10,'dac_scoreboard',max(abs(u-ur),[],'all')<1e-8,...
 'charge_amplitude_within_5percent',abs(mean(amp(hold))/p.charge_target_C-1)<.05,...
 'no_clipping',max(abs(u),[],'all')<p.vmax,'no_physical_head_fields',~any(isfield(p,{'mass','theta_s','theta_d','amp'})));
blocked=false;pp=p;pp.Omega=.5;try,p10e_plant(pp);catch ME,blocked=contains(ME.message,'Unknown B');end
checks.blocks_rotation_without_B=blocked;
% Two different physical mass/coupling triples give the same charge-state model.
for scale=[1 9]
 m=1e-4*scale;ts=sqrt(m*p.kappa);td=p.b*m/ts;
 legacy=p10_config;legacy.mass=m;legacy.theta_s=ts;legacy.theta_d=td;legacy.f0=p.f0;legacy.Q=pi*p.f0/p.gamma;
 legacy.Cs=p.Cs;legacy.Cds=p.Cds;legacy.Omega=0;[~,~,~,~,Ap,Bp]=p10_plant(legacy);
 Ap(7:8,7:8)=Ap(7:8,7:8)-p.G0/p.Cs*eye(2);
 T=diag([repmat(ts,1,4) ones(1,8)]);err=norm(T*Ap/T-A,'fro')/norm(A,'fro');
 assert(err<1e-12&&norm(T*Bp-B,'fro')<1e-12);
end
checks.two_physical_gauges_same_electrical_model=true;
save_system(mdl);close_system(mdl,0);load_system(fullfile(root,'models',[mdl '.slx']));set_param(mdl,'SimulationCommand','update');checks.reopened_compiled=true;
result=struct('scope','Synthetic stationary charge-domain closed loop; no physical amplitude or navigation scale acceptance','checks',checks,...
 'charge_target_C',p.charge_target_C,'charge_relative_mean_error',mean(amp(hold))/p.charge_target_C-1,'peak_DAC_V',max(abs(u),[],'all'),'matlab',version);
for name={'A','B','Ad','Bd'},writematrix(eval(name{1}),fullfile(ev,[name{1} '.csv']));end
writetable(array2table([t(1:40:end) x(1:40:end,1:2) iq(1:40:end,1:4) u(1:40:end,:)],'VariableNames',{'time_s','eta_x_C','eta_y_C','Ix_C','Iy_C','Qx_C','Qy_C','DACx_V','DACy_V'}),fullfile(ev,'traces.csv'));
for pair={{'parameters.json',p},{'results.json',result}},v=pair{1};fid=fopen(fullfile(ev,v{1}),'w');fprintf(fid,'%s\n',jsonencode(v{2},PrettyPrint=true));fclose(fid);end
assert(all(structfun(@logical,checks)));disp(result);
end
