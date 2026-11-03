function a2_generate()
% 只负责物理源与独立仪器记录，不调用A2因果处理器或角度评分器。
root=fileparts(mfilename('fullpath'));project=fileparts(fileparts(root));
addpath(fullfile(project,'HRG_WA_simulink','piezo_v10','revision_v10_2_cn'));
mkdir_if(fullfile(root,'data','observations'));mkdir_if(fullfile(root,'data','private_score'));
old=fullfile(project,'research','port_deembedding_20261103');
truthA1=jsondecode(fileread(fullfile(old,'data','private_score','truth.json')));
obsA1=jsondecode(fileread(fullfile(old,'data','observations','case_002.json')));
fits=jsondecode(fileread(fullfile(old,'evidence','joint_loading','estimates.json')));
assert(fits.cases(2).eligible);p=truthA1.cases(2).physical_parameters;
p.Rs=80000;p.driver_tau=p.driver_tau(:);p.afe_bw=p.afe_bw(:);
cal=obsA1.electronics;cal.Rs=80000;cal.driver_tau=cal.driver_tau(:)';cal.afe_bw=cal.afe_bw(:)';
% 从已有独立夹持测量恢复Cds*H，不给实时处理器真实H。
v=obsA1.train(1);s=2i*pi*v.frequency_Hz;rs=obsA1.electronics.Rs(v.load_index);
F=1./(1+s./(2*pi*cal.afe_bw(:)));
q=-s/((cal.Cs*s+1/rs+cal.G0)*rs*cal.Cf*(s+1/(cal.Rf*cal.Cf)));
C=-(v.fixture_re+1i*v.fixture_im)./F/q;
assert(norm(imag(C),'fro')<1e-20);cal.feed_charge_matrix_C_per_V=real(C);
cal.W=fits.cases(2).W;
% 方向速率rad/s / 时域每通道白噪RMS V / 校准类型 / 幅值比 / 种子。
plan={.7,0,'nominal',1,900;5,0,'nominal',1,901;0,0,'nominal',1,902;...
 .7,5e-6,'nominal',1,903;.7,500e-6,'nominal',1,904;.7,1e-3,'nominal',1,905;...
 .7,5e-6,'bounded',1,906;.7,5e-6,'bad_afe',1,907;.7,5e-6,'bad_Cs',1,908;...
 .7,5e-6,'extra_pole',1,909;.7,5e-6,'nominal',1e-4,910;...
 .7,500e-6,'nominal',1,920;.7,500e-6,'nominal',1,921;...
 .7,1e-3,'nominal',1,922;.7,1e-3,'nominal',1,923};
cfg=jsondecode(fileread(fullfile(root,'config.json')));protocol=struct('schema','A2-observed-stream-v1','cases',{{}});truth=struct('cases',{{}});
[~,~,~,A,B]=pcn_plant(p);D=-A(3:4,3:4);K=-A(3:4,1:2);
w=2*pi*p.f0;qscale=p.charge_target;vscale=max(1e-6,w*qscale*p.Rs);
S=diag([qscale qscale w*qscale w*qscale 1 1 vscale vscale qscale/p.Cf qscale/p.Cf qscale/p.Cf qscale/p.Cf]);An=S\A*S;Bn=S\B;
for c=1:size(plan,1)
 rng(plan{c,5},'twister');cc=cal;kind=plan{c,3};nu=plan{c,1};modrate=2*pi*3;amplitude=plan{c,4};rows=[];
 if strcmp(kind,'bounded'),cc.Cs=cc.Cs*1.004;cc.afe_bw=cc.afe_bw.*[1.004 .996];end
 if strcmp(kind,'bad_afe'),cc.afe_bw=cc.afe_bw.*[1.3 .75];end
 if strcmp(kind,'bad_Cs'),cc.Cs=cc.Cs*1.2;end
 extra_tau=0;if strcmp(kind,'extra_pole'),extra_tau=1/(2*pi*6000);end
 R=[cos(.3) -sin(.3);sin(.3) cos(.3)];
 for pair=[nu 1;modrate .15]'
  rate=pair(1);weight=pair(2);
  for signv=[-1 1]
   freq=cfg.carrier_Hz+signv*rate/(2*pi);s=2i*pi*freq;
   r=amplitude*weight*.5*qscale*R*[1;-signv*1i];
   L=-s/(p.Cs*s+1/p.Rs+p.G0);P=p.Cds*s/(p.Cs*s+1/p.Rs+p.G0);
   vd=(p.b*p.drive_matrix+p.kappa*P*eye(2))\((s*s*eye(2)+s*D+K-p.kappa*L*eye(2))*r);
   u=(1+s*p.driver_tau).*vd;X=S*((s*eye(12)-An)\(Bn*u));
   assert(norm(X(1:2)-r)/norm(r)<1e-8);
   y=X(11:12)/(1+s*extra_tau);
   rows=[rows;struct('frequency_Hz',freq,'u_re',real(u)','u_im',imag(u)','y_re',real(y)','y_im',imag(y)')]; %#ok<AGROW>
  end
 end
 % 独立校准检查仪器：AFE复频响和传感导纳；不读取处理器输出。
 checks=[];isigma=cfg.calibration_instrument_relative_sigma;
 for freq=[400 900 1500 3000 6500 12000]
  s=2i*pi*freq;F=1./(1+s./(2*pi*p.afe_bw))/(1+s*extra_tau);Y=p.Cs*s+1/p.Rs+p.G0;
  measured=[F;Y];sd=isigma*abs(measured);
  measured=measured+sd.*(randn(3,1)+1i*randn(3,1));
  checks=[checks;struct('frequency_Hz',freq,'value_re',real(measured)','value_im',imag(measured)','sigma',sd')]; %#ok<AGROW>
 end
 cid=sprintf('case_%03d',c);probe=plan{c,2}*randn(cfg.noise_probe_samples,2);
 payload=struct('tones',rows,'calibration',cc,'independent_calibration_check',checks,...
  'noise_probe_V',probe,'stream_noise_seed',plan{c,5}+10000,'stream_noise_RMS_V',plan{c,2});
 writej(fullfile(root,'data','observations',[cid '.json']),payload);
 protocol.cases{end+1}=struct('id',cid,'file',[cid '.json']);
 truth.cases{end+1}=struct('id',cid,'nominal_modal_rate_rad_s',nu,'modulation_rate_rad_s',modrate,...
  'modulation_fraction',.15,'calibration_kind',kind,'amplitude_fraction',amplitude,...
  'calibration_should_pass',~ismember(kind,{'bad_afe','bad_Cs','extra_pole'}),...
  'low_amplitude',amplitude<.01,'extra_seed',c>11);
end
writej(fullfile(root,'data','observations','protocol.json'),protocol);
writej(fullfile(root,'data','private_score','truth.json'),truth);
fprintf('A2 exported %d compact SI stream cases and independent instrument records.\n',numel(protocol.cases));
end
function mkdir_if(p),if ~isfolder(p),mkdir(p);end,end
function writej(path,v)
fid=fopen(path,'w','n','UTF-8');assert(fid>0);cleanup=onCleanup(@()fclose(fid));fprintf(fid,'%s\n',jsonencode(v));
end
