function results=sn_run()
root=sn_setup;folder=fullfile(root,'evidence');if ~exist(folder,'dir'),mkdir(folder);end
profiles=jsondecode(fileread(fullfile(fileparts(root),'compensation_research','independent_profiles.json')));
p=comp_config;cases=struct('id',{},'p',{},'profile',{});p.enable_iq_estimator=true;
add('clean',p,profiles.baseline);
for seed=[20261030 20261110:20261114],q=p;q.noise_rms_V=500e-6;q.noise_seed=seed;add(['noise500_' num2str(seed)],q,profiles.noise_500u);end
for rate=[0 -.5 2],q=p;q.noise_rms_V=500e-6;q.Omega=rate;q.noise_seed=20261200;add(['rate_' strrep(num2str(rate),'-','m')],q,profiles.noise_500u);end
q=p;q.noise_rms_V=500e-6;q.split_hz=.01;q.damping_half_difference=.002;q.stiffness_axis=.61;q.damping_axis=-.29;q.noise_seed=20261201;add('combined500',q,profiles.combined_2);
q=p;q.noise_rms_V=1000e-6;add('noise1000_boundary',q,profiles.noise_500u);
old=fullfile(fileparts(root),'compensation_research','models','hrg_wa_compensation_research.slx');dst=fullfile(root,'models');if ~exist(dst,'dir'),mkdir(dst);end
mdl='hrg_wa_noise_research';copyfile(old,fullfile(dst,[mdl '.slx']));load_system(fullfile(dst,[mdl '.slx']));
set_param([mdl '/Digital_Control_and_DAC/Validated_Kernel'],'FunctionName','sn_sfun');
set_param([mdl '/Quality_Monitor/Read_Only_Quality'],'FunctionName','sn_quality_sfun');
selectors={'Tap_IQ','Tap_PLL_Hz','Tap_Energy_Linearity_Validity','Tap_Source_Timestamps'};
for k=1:numel(selectors),set_param([mdl '/Instrumentation/' selectors{k}],'InputPortWidth','23');end
set_param([mdl '/Digital_Control_and_DAC'],'Description','32帧因果端点IQ估计；23维诊断，19:22为未平滑IQ，23为原始有效性。目标时刻仍为当前源窗口中心，不能将估计值误称为直接单窗测量。');
a=Simulink.Annotation([mdl '/Quality_Monitor'],sprintf('降噪研究：面板显示当前源中心对应的因果估计。\n支持历史最多32帧；重叠与相关性不用于增加统计样本数。\n原始IQ与有效性保存在诊断19:23列，不隐藏原始噪声。\n独立机械真值仅离线核对，不进入控制或估计。'));a.Position=[20 500];
mw=get_param(mdl,'ModelWorkspace');results=struct;score=struct;rows=cell(numel(cases),9);
for k=1:numel(cases)
 v=cases(k);q=v.p;q.enable_tensor_ff=true;q.identified_dK=v.profile.dK;q.identified_dD=v.profile.dD;
 c=pcn_calibration;c.detect=v.profile.detect_real+1i*v.profile.detect_imag;c.drive=v.profile.drive_real+1i*v.profile.drive_imag;
 r=sn_reference(q,c);report=sn_report(r,q,false,v.id);
 raw=r;raw.d(:,1:4)=r.d(:,19:22);raw=geometry(raw,r.d(:,23));rawm=pcn_metrics(raw,q);
 truth=r;truth.d(:,1:4)=r.clean;truth=geometry(truth,r.d(:,8));truthm=pcn_metrics(truth,q);
 before=pcn_metrics(comp_reference(q,c),q);
 physicalPass=truthm.angle_rms_deg<.1&&truthm.quadrature_rms<1e-3&&truthm.pll_phase_rms<1e-3;
 passed=all(structfun(@logical,report.checks))&&physicalPass;
 name=matlab.lang.makeValidName(v.id);results.(name)=struct('p',q,'before',before,'after',report,'raw_observation',rawm,'mechanical_truth',truthm,'physical_pass',physicalPass,'passed',passed);
 rows(k,:)={v.id,q.noise_rms_V,q.Omega,before.angle_rms_deg,report.metrics.angle_rms_deg,report.quadrature_RMS,report.PLL_detector_RMS,truthm.angle_rms_deg,passed};
 if ismember(k,[2 7 10 11 12])
  assignin(mw,'p',q);assignin(mw,'c',c);[Ad,Bd,x0]=pcn_plant(q);assignin(mw,'Ad',Ad);assignin(mw,'Bd',Bd);assignin(mw,'x0',x0);
  out=sim(mdl,'StopTime',num2str(q.duration));scale=max(max(abs(r.x),[],1),1e-15);
  score.(name)=max(abs(out.p103_states.Data-r.x)./scale,[],'all')<1e-7&&isequal(out.p103_dac.Data,r.u);
 end
 idx=find(r.d(:,9)>0&[true;diff(r.d(:,9))~=0]);f=r.d(idx,:);clean=r.clean(idx,:);
 writematrix([f(:,12) f(:,1:4) f(:,19:23) clean],fullfile(folder,v.id,'raw_estimated_truth.csv'));
 pcn_json(fullfile(folder,'results.json'),results);pcn_json(fullfile(folder,'scoreboard.json'),score);
 fprintf('NOISE %d/%d %s pass=%d estimated=%g raw=%g physical=%g\n',k,numel(cases),v.id,passed,report.metrics.angle_rms_deg,rawm.angle_rms_deg,truthm.angle_rms_deg);
end
T=cell2table(rows,'VariableNames',{'id','noise_V','Omega','before_angle','after_angle','quadrature','PLL','physical_angle','passed'});writetable(T,fullfile(folder,'summary.csv'));sn_summary(T,root);
% 默认演示保存原500μV强噪声点。
v=cases(2);q=v.p;q.enable_tensor_ff=true;q.identified_dK=v.profile.dK;q.identified_dD=v.profile.dD;c=pcn_calibration;c.detect=v.profile.detect_real+1i*v.profile.detect_imag;c.drive=v.profile.drive_real+1i*v.profile.drive_imag;
assignin(mw,'p',q);assignin(mw,'c',c);[Ad,Bd,x0]=pcn_plant(q);assignin(mw,'Ad',Ad);assignin(mw,'Bd',Bd);assignin(mw,'x0',x0);save_system(mdl);close_system(mdl,0);load_system(fullfile(dst,[mdl '.slx']));set_param(mdl,'SimulationCommand','update');assert(all(structfun(@logical,score)));
sn_finalize;
 function add(id,q,profile),cases(end+1)=struct('id',id,'p',q,'profile',profile);end
end
function r=geometry(r,valid)
d=r.d;I=d(:,1:2);Q=d(:,3:4);E=sum(I.^2+Q.^2,2);N=I(:,1).^2+Q(:,1).^2-I(:,2).^2-Q(:,2).^2;M=2*(I(:,1).*I(:,2)+Q(:,1).*Q(:,2));r.d(:,6)=E;r.d(:,7)=hypot(N,M)./max(E,realmin);r.d(:,8)=valid;
end
