function results=stress_run()
root=stress_setup;cases=stress_cases;folder=fullfile(root,'evidence');if ~exist(folder,'dir'),mkdir(folder);end
% 仅加载封存模型，不重建、不保存原SLX；质量观察SF与控制路径不变。
path=fullfile(fileparts(root),'quality_dashboard','models','hrg_wa_quality_monitor.slx');load_system(path);mdl='hrg_wa_quality_monitor';mw=get_param(mdl,'ModelWorkspace');
results=struct;rows=cell(numel(cases),12);verify=struct;
for k=1:numel(cases)
 v=cases(k);p=v.p;c=v.c;pcn_validate(p,c);[Ad,Bd,x0]=pcn_plant(p);
 assignin(mw,'p',p);assignin(mw,'c',c);assignin(mw,'Ad',Ad);assignin(mw,'Bd',Bd);assignin(mw,'x0',x0);
 out=sim(mdl,'StopTime',num2str(p.duration));r=stress_report(out,p,false,v.id);
 fail=fieldnames(r.checks);fail=fail(~structfun(@logical,r.checks));passed=isempty(fail);
 % 每个工况都保存配置和各项结果；允许质量门限失败，绝不把失败点丢弃。
 record=stress_case_record(v);dst=fullfile(folder,v.id);pcn_json(fullfile(dst,'parameters.json'),record);pcn_json(fullfile(dst,'failures.json'),fail);
 results.(matlab.lang.makeValidName(v.id))=struct('case',record,'report',r,'passed',passed,'failed_checks',{fail});
 rows(k,:)={v.id,v.label,passed,r.metrics.valid_fraction,r.normalized_energy_mean,r.normalized_Q_RMS,r.quadrature_RMS,r.PLL_detector_RMS,r.metrics.angle_rms_deg,r.metrics.dac_clip_samples,r.timestamp_max_error_us,strjoin(fail,',')};
 % 同工况逐拍调度replay；核对每个非理想点的模型执行一致性。
 ref=pcn_reference(p,c);actual=out.p103_states.Data;scale=max(max(abs(ref.x),[],1),1e-15);
 verify.(matlab.lang.makeValidName(v.id))=max(abs(actual-ref.x)./scale,[],'all')<1e-7&&isequal(out.p103_dac.Data,ref.u);
 fprintf('CASE %d/%d %s: passed=%d failures=%s\n',k,numel(cases),v.id,passed,strjoin(fail,','));
 % 逐工况写检查点，长批次中断后仍可保留已完成证据。
 pcn_json(fullfile(folder,'all_results.json'),results);pcn_json(fullfile(folder,'scoreboard.json'),verify);
end
T=cell2table(rows,'VariableNames',{'id','label','passed','valid_fraction','energy_mean','Q_RMS','quadrature_RMS','PLL_RMS','angle_RMS_deg','DAC_clips','timestamp_error_us','failed_checks'});
writetable(T,fullfile(folder,'summary.csv'));
records=arrayfun(@stress_case_record,cases);pcn_json(fullfile(folder,'cases.json'),records);
stress_summary(T,root);close_system(mdl,0);assert(all(structfun(@logical,verify)),'Nonideal scoreboard mismatch');
end
