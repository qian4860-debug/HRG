function sn_finalize()
root=sn_setup;d=jsondecode(fileread(fullfile(root,'evidence','results.json')));names=fieldnames(d);
for k=1:numel(names)
 v=d.(names{k});id=names{k};if strcmp(id,'rate_m0_5'),id='rate_m0.5';end
 path=fullfile(root,'evidence',id,'quality_report.html');text=fileread(path);
 if ~contains(text,'原始观测与机械核验')
  fid=fopen(path,'a','n','UTF-8');fprintf(fid,'<h2>原始观测与机械核验</h2><p>上方面板显示因果估计，不表示原始噪声消失。机械真值仅用于离线核验。</p><table border="1"><tr><th>指标</th><th>原始观测</th><th>因果估计</th><th>机械真值</th></tr><tr><td>角度RMS[°]</td><td>%.7g</td><td>%.7g</td><td>%.7g</td></tr><tr><td>正交残差RMS</td><td>%.7g</td><td>%.7g</td><td>%.7g</td></tr></table><p>机械核验通过=%d；联合判定通过=%d。校准与张量仍依赖独立参考。</p>',v.raw_observation.angle_rms_deg,v.after.metrics.angle_rms_deg,v.mechanical_truth.angle_rms_deg,v.raw_observation.quadrature_rms,v.after.quadrature_RMS,v.mechanical_truth.quadrature_rms,v.physical_pass,v.passed);fclose(fid);
 end
end
mdl='hrg_wa_noise_research';load_system(fullfile(root,'models',[mdl '.slx']));
set_param([mdl '/Digital_Control_and_DAC/Validated_Kernel'],'Description','sn_sfun调用sn_tick，165维状态。当前源中心端点估计，诊断19:22保留原始IQ、23保留原始有效性；控制不读取机械真值或真实Omega。');
set_param(mdl,'Description','500μV白噪声研究：建幅后32帧因果端点IQ估计；原门限与原始观测保留，另检查机械真值。独立校准参考仍是前提，动态带宽未全面认证。');
set_param(mdl,'SimulationCommand','update');save_system(mdl);close_system(mdl,0);
end
