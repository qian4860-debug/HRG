function results=comp_run()
root=comp_setup;dst=fullfile(root,'evidence');if ~exist(dst,'dir'),mkdir(dst);end
profiles=jsondecode(fileread(fullfile(root,'independent_profiles.json')));cases=stress_cases;
for j=1:3
 name=['holdout' num2str(j)];v=profiles.(name);p=v.plant;p.driver_tau=p.driver_tau(:);p.afe_bw=p.afe_bw(:);
 c=pcn_calibration;c.detect=diag([1.007,.993])*diag(exp(1i*[.35,-.35]*pi/180))*c.detect;
 cases(end+1)=struct('id',name,'label',['独立留出工况' num2str(j)],'p',p,'c',c);
end
old=fullfile(fileparts(root),'quality_dashboard','models','hrg_wa_quality_monitor.slx');folder=fullfile(root,'models');if ~exist(folder,'dir'),mkdir(folder);end
mdl='hrg_wa_compensation_research';copyfile(old,fullfile(folder,[mdl '.slx']));load_system(fullfile(folder,[mdl '.slx']));
set_param([mdl '/Digital_Control_and_DAC/Validated_Kernel'],'FunctionName','comp_sfun');mw=get_param(mdl,'ModelWorkspace');
comp_describe(mdl);
base=comp_config;assignin(mw,'p',base);save_system(mdl);results=struct;score=struct;ablation=struct;rows=cell(numel(cases),8);
for k=1:numel(cases)
 v=cases(k);name=matlab.lang.makeValidName(v.id);profile=profiles.(name);p=comp_config(v.p);c=v.c;
 c.detect=profile.detect_real+1i*profile.detect_imag;c.drive=profile.drive_real+1i*profile.drive_imag;
 p.enable_tensor_ff=true;p.identified_dK=profile.dK;p.identified_dD=profile.dD;
 r=comp_reference(p,c,v.p);m=pcn_metrics(r,v.p);before=pcn_metrics(pcn_reference(v.p,v.c),v.p);
 if k>18 || ismember(k,[10 12 14 15 16 17 18])
  q=p;q.enable_tensor_ff=false;ablation.(name)=pcn_metrics(comp_reference(q,c,v.p),v.p);
 end
 report=comp_report(r,v.p,false,v.id);passed=all(structfun(@logical,report.checks));
 results.(name)=struct('before',before,'after',report,'passed',passed,'case',stress_case_record(v),...
  'identified_dK',p.identified_dK,'identified_dD',p.identified_dD,'calibration_holdout',profile.holdout);
 failures=fieldnames(report.checks);failures=failures(~structfun(@logical,report.checks));
 rows(k,:)={v.id,v.label,before.angle_rms_deg,m.angle_rms_deg,m.quadrature_rms,m.pll_phase_rms,passed,strjoin(failures,',')};
 if ismember(k,[1 6 10 18 19 20 21])
  assignin(mw,'p',p);assignin(mw,'c',c);[Ad,Bd,x0]=pcn_plant(v.p);assignin(mw,'Ad',Ad);assignin(mw,'Bd',Bd);assignin(mw,'x0',x0);
  out=sim(mdl,'StopTime',num2str(p.duration));scale=max(max(abs(r.x),[],1),1e-15);
  score.(name)=max(abs(out.p103_states.Data-r.x)./scale,[],'all')<1e-7&&isequal(out.p103_dac.Data,r.u);
 end
 pcn_json(fullfile(dst,'results.json'),results);pcn_json(fullfile(dst,'scoreboard.json'),score);pcn_json(fullfile(dst,'ablation.json'),ablation);
 fprintf('COMP %d/%d %s before=%g after=%g pass=%d\n',k,numel(cases),v.id,before.angle_rms_deg,m.angle_rms_deg,passed);
end
T=cell2table(rows,'VariableNames',{'id','label','before_angle','after_angle','quadrature','PLL','passed','failed_checks'});writetable(T,fullfile(dst,'summary.csv'));
% 保存模型为基线补偿配置，避免最后留出点成为默认参数。
v=cases(1);profile=profiles.baseline;p=comp_config(v.p);p.enable_tensor_ff=true;p.identified_dK=profile.dK;p.identified_dD=profile.dD;
c=v.c;c.detect=profile.detect_real+1i*profile.detect_imag;c.drive=profile.drive_real+1i*profile.drive_imag;
assignin(mw,'p',p);assignin(mw,'c',c);[Ad,Bd,x0]=pcn_plant(v.p);assignin(mw,'Ad',Ad);assignin(mw,'Bd',Bd);assignin(mw,'x0',x0);save_system(mdl);close_system(mdl,0);
load_system(fullfile(folder,[mdl '.slx']));set_param(mdl,'SimulationCommand','update');assert(all(structfun(@logical,score)));
comp_summary(T,root);
end
