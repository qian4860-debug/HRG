function results=a4_run(report_only)
root=a4_setup;cfg=jsondecode(fileread(fullfile(root,'config.json')));
if nargin>0&&report_only
 results=jsondecode(fileread(fullfile(root,'evidence','results.json')));names=fieldnames(results);
 for k=1:numel(names)
  file=fullfile(root,'evidence',[names{k} '_frames.csv']);f=readmatrix(file);
  pending=f(:,1)<results.(names{k}).integer.source_origin_s;f(pending,[2 3 4 12])=NaN;writematrix(f,file);
 end
 a4_report(results,root);return
end
if ~exist(fullfile(root,'evidence'),'dir'),mkdir(fullfile(root,'evidence'));end
p=comp_config;p.enable_iq_estimator=false;p.predict_heading=false;p.enable_tensor_ff=false;p.virtual_rate=0;p.duration=cfg.duration_s;
profile=jsondecode(fileread(fullfile(fileparts(fileparts(root)),'HRG_WA_simulink','piezo_v10','revision_v10_2_cn','evidence','calibration_profile.json')));
c=pcn_calibration;c.frequency_Hz=profile.frequency_Hz;c.adapter=a4_adapter_config(p,c);
% 在闭环前核对缩放、相位及标定元数据拒绝路径。
unit=a4_unit_checks(p,c,cfg);pcn_json(fullfile(root,'evidence','adapter_checks.json'),unit);
names={'zero','positive','negative','fast','sign_step','noise5u'};omegas={0,.5,-.5,2,[.5 -.5 .25],.5};
results=struct;allok=true;
for k=1:numel(names)
 q=p;if k==6,q.noise_rms_V=5e-6;end
 z=a4_prepare_plant(q,omegas{k});rf=a4_reference(q,c,z,false);ri=a4_reference(q,c,z,true);
 [mf,ff]=a4_metrics(rf,q,cfg);[mi,fi]=a4_metrics(ri,q,cfg);
 trajectory=max(abs(ri.x(:,1:2)-rf.x(:,1:2)),[],'all')/q.charge_target;
 delta=sqrt(mean((fi(fi(:,1)>=cfg.score_not_before_s,2)-ff(ff(:,1)>=cfg.score_not_before_s,2)).^2));
 checks=struct('body',mi.relative_body_RMS_rad<=cfg.relative_body_angle_RMS_limit_rad,...
 'body_difference',delta<=cfg.integer_vs_float_body_angle_RMS_limit_rad,'trajectory',trajectory<=cfg.trajectory_difference_limit_charge_target,...
 'energy',abs(mi.energy_relative_mean)<=cfg.energy_relative_limit,'quadrature',mi.quadrature_RMS<=cfg.quadrature_RMS_limit,...
 'PLL',mi.PLL_RMS<=cfg.PLL_RMS_limit,'no_clip',mi.DAC_clipped==0,'valid',mi.valid_fraction==1);
 results.(names{k})=struct('float',mf,'integer',mi,'trajectory_difference_charge_target',trajectory,'body_difference_RMS_rad',delta,'checks',checks,'passed',all(structfun(@logical,checks)));
 allok=allok&&results.(names{k}).passed;
 writematrix([fi ff(:,2)],fullfile(root,'evidence',[names{k} '_frames.csv']));
 fprintf('A4 %s pass=%d body=%g delta=%g trajectory=%g\n',names{k},results.(names{k}).passed,mi.relative_body_RMS_rad,delta,trajectory);
 pcn_json(fullfile(root,'evidence','results.json'),results);
 if strcmp(names{k},'sign_step')
  if ~exist(fullfile(root,'data'),'dir'),mkdir(fullfile(root,'data'));end
  writematrix(ri.interface,fullfile(root,'data','rtl_replay.csv'));
  mdl=a4_build(q,c,z);out=sim(mdl);scale=max(max(abs(ri.x),[],1),1e-15);
  compare=struct('plant_relative_max',max(abs(out.a4_plant.Data-ri.x)./scale,[],'all'),...
   'DAC_bit_identical',isequal(out.a4_dac.Data,ri.u),'ADC_bit_identical',isequal(out.a4_adc.Data,ri.adc),...
   'diagnostics_NaN_masks',isequal(isnan(out.a4_diagnostics.Data),isnan(ri.d)));
  aa=out.a4_diagnostics.Data-ri.d;aa(isnan(aa))=0;compare.diagnostic_max=max(abs(aa),[],'all');
  pcn_json(fullfile(root,'evidence','simulink_scoreboard.json'),compare);
  assert(compare.DAC_bit_identical&&compare.ADC_bit_identical&&compare.plant_relative_max<1e-8&&compare.diagnostic_max<1e-8);
  ode=a4_ode_check(ri,q,z,cfg);pcn_json(fullfile(root,'evidence','ODE_checks.json'),ode);assert(ode.passed);
  close_system(mdl,0);
 end
end
a4_report(results,root);pcn_json(fullfile(root,'evidence','summary.json'),struct('cases',numel(names),'all_passed',allok,'scope',cfg.scope));
assert(allok,'A4:Acceptance','存在未通过工况，保留证据，不调整门限');
end

function result=a4_unit_checks(p,c,cfg)
s=sn_state('unpack',sn_state('init',p));maxerr=0;phasefault=0;scaleerr=0;
for theta=[0 .37 pi/2 pi -1]
 e=[cos(theta);sin(theta)];n=[-e(2);e(1)];s.I=p.charge_target*e;s.Fc=c.adapter.F0*.2*n;s.Fs=-c.adapter.F0*(.4*e+.1*n);
 for phi=0:pi/20:2*pi
  s.phase=phi;u=a4_drive(s,p,c);v=c.drive\complex(s.Fc,-s.Fs);ideal=real(v*exp(1i*phi));
  maxerr=max(maxerr,max(abs(u-ideal))/(c.adapter.VFS/131072));
  bad=s;bad.phase=phi+2*pi*p.f0*p.Ts;phasefault=max(phasefault,max(abs(a4_drive(bad,p,c)-ideal)));
  cc=c;cc.adapter.F0=2*c.adapter.F0;cc.adapter.M=2*c.adapter.M;
  cc.adapter.matrix_codes=2*c.adapter.matrix_codes;scaleerr=max(scaleerr,max(abs(a4_drive(s,p,cc)-u)));
 end
end
assert(maxerr<=cfg.adapter_error_limit_DAC_LSB&&phasefault>1e-3&&scaleerr<16*c.adapter.VFS/131072);
count=0;
for kind=1:3
 try
  q=p;cc=c;
  if kind==1,q.Ts=2*p.Ts;elseif kind==2,q.f0=p.f0+1;else,cc.drive(:)=0;end
  a4_adapter_config(q,cc);
 catch ex
  assert(startsWith(ex.identifier,'A4:'));count=count+1;
 end
end
assert(count==3);
result=struct('maximum_unrounded_error_DAC_LSB',maxerr,'one_sample_phase_fault_voltage',phasefault,...
 'scale_invariance_voltage_error',scaleerr,'metadata_and_singular_matrix_rejections',count,'passed',true);
end

function result=a4_ode_check(r,p,z,cfg)
x=z.x0;maximum=0;dt=p.Ts/cfg.ODE_RK4_substeps;
for k=1:numel(z.segment)
 maximum=max(maximum,max(abs(x(1:2)-r.x(k,1:2)'))/p.charge_target);
 j=z.segment(k);A=z.A(:,:,j);bu=z.B(:,:,j)*r.u(k,:)';
 for n=1:cfg.ODE_RK4_substeps
  k1=A*x+bu;k2=A*(x+dt*k1/2)+bu;k3=A*(x+dt*k2/2)+bu;k4=A*(x+dt*k3)+bu;
  x=x+dt*(k1+2*k2+2*k3+k4)/6;
 end
end
result=struct('RK4_substeps',cfg.ODE_RK4_substeps,'max_charge_error_over_target',maximum,'passed',maximum<cfg.ODE_relative_charge_limit);
end

function a4_report(results,root)
names=fieldnames(results);fig=figure('Visible','off','Position',[100 100 1200 750]);tiledlayout(2,2);
nexttile;hold on;for k=1:numel(names),f=readmatrix(fullfile(root,'evidence',[names{k} '_frames.csv']));plot(f(:,1),f(:,4)*180/pi,'DisplayName',names{k});end
title('机体增量角误差（源中心，无真值拟合）');xlabel('s');ylabel('°');legend('Location','best');grid on;
nexttile;hold on;for k=1:numel(names),f=readmatrix(fullfile(root,'evidence',[names{k} '_frames.csv']));plot(f(:,1),f(:,5));end;title('归一化能量');xlabel('s');grid on;
f=readmatrix(fullfile(root,'evidence','sign_step_frames.csv'));nexttile;plot(f(:,1),f(:,2:3)*180/pi);legend('D0闭环输出','输入转角积分');title('分段反转：实际机械科氏输入');xlabel('源中心 s');ylabel('°');grid on;
nexttile;plot(f(:,1),f(:,6:7));legend('正交残差','PLL检测量');title('sign-step闭环残差');xlabel('s');grid on;
sgtitle('A4：合成固定校准的最小旋转闭环；无预测/张量/虚拟进动；非实物性能');
exportgraphics(fig,fullfile(root,'evidence','a4_dashboard.png'));close(fig);
end
