function result=comp_ablation()
root=comp_setup;p=comp_config;c=pcn_calibration;p.Omega=2;result=struct;
for early=[false true]
 for zero=[false true]
  q=p;q.heading_start_s=.25*(~early);q.zero_start_force=zero;
  result.(sprintf('early%d_zero%d',early,zero))=pcn_metrics(comp_reference(q,c),q);
 end
end
% 独立留出头参数下，将辨识张量故意偏离10%，不使用真值修正导航。
profiles=jsondecode(fileread(fullfile(root,'independent_profiles.json')));v=profiles.holdout1;q=comp_config(v.plant);q.driver_tau=q.driver_tau(:);q.afe_bw=q.afe_bw(:);
c.detect=v.detect_real+1i*v.detect_imag;c.drive=v.drive_real+1i*v.drive_imag;
q.enable_tensor_ff=true;q.identified_dK=1.1*v.dK;q.identified_dD=.9*v.dD;
result.ten_percent_tensor_error=pcn_metrics(comp_reference(q,c),q);
pcn_json(fullfile(root,'evidence','startup_and_uncertainty.json'),result);disp(result);
end
