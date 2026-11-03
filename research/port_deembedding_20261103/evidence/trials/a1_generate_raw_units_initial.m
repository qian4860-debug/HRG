function a1_generate()
% A1独立生成器：直接调用原12状态pcn_plant，不调用辨识器回归公式生成训练输出。
% 本阶段Omega=0，用于静止标定；所有物理量为合成SI参数。
root=fileparts(mfilename('fullpath'));project=fileparts(fileparts(root));
addpath(fullfile(project,'HRG_WA_simulink','piezo_v10','revision_v10_2_cn'));
mkdir_if(fullfile(root,'data','observations'));mkdir_if(fullfile(root,'data','private_score'));
trainf=[250 600 850 970 998.5 1001.5 1040 1400 2800 6500 12000];
testf=[400 750 990 1000.3 1100 2100 5000 15000];
loads=[1000 80000 300000];repeats=6;
% seed / Cds[F] / 失配种类 / 结构 / 电压复相量实虚部噪声sigma[V] / 独立组。
plan={101,0,'none','general',0,false;102,2e-13,'none','general',0,false;...
103,2e-13,'afe','general',0,false;104,0,'none','coaxial',0,false;...
105,0,'none','isotropic',0,false;106,2e-13,'none','general',5e-6,false;...
201,2e-13,'none','general',0,true;202,0,'none','general',0,true;...
203,2e-13,'Cs','general',0,true};
public=struct('schema','A1-port-phasors-v1','synthetic',true,'Omega',0,...
 'repeats',repeats,'known_handedness',1,'cases',{{}});
truth=struct('cases',{{}},'scope','合成真值仅离线评分；独立校准来自理想夹持电路夹具，非无参考');
for c=1:size(plan,1)
 rng(plan{c,1},'twister');p=pcn_config();p.Omega=0;p.split_hz=.3;
 p.damping_half_difference=.08;p.damping_axis=-.23;p.stiffness_axis=.37;
 p.detect_matrix=[1.2 .15;-.08 .85]+.02*randn(2);
 p.drive_matrix=[1 -.03;.02 1.08]+.01*randn(2);
 p.afe_bw=[4500;3500];p.Cds=plan{c,2};
 if strcmp(plan{c,4},'coaxial'),p.damping_axis=p.stiffness_axis;end
 if strcmp(plan{c,4},'isotropic'),p.split_hz=0;p.damping_half_difference=0;end
 cid=sprintf('case_%03d',c);records=[];
 for r=1:repeats
  records=[records;make_records(p,loads,trainf,r,plan{c,5})]; %#ok<AGROW>
 end
 held=make_records(p,loads,testf,0,plan{c,5});
 % 留出角度：载波两侧带构成缓慢转动的直线振型。用真实机械方程求输入，
 % 再通过完整12状态响应重新得到输出；该记录不参与算子估计和适用性判定。
 carrier=1000;nu=.7;tf=linspace(0,4,1201)';angle_ref=nu*tf;
 R=[cos(.3) -sin(.3);sin(.3) cos(.3)];side=[];
 for signv=[-1 1]
  freq=carrier+signv*nu/(2*pi);s=2i*pi*freq;pp=p;pp.Rs=loads(2);
  [~,~,~,A,B]=pcn_plant(pp);K=-A(3:4,1:2);D=-A(3:4,3:4);
  desired=R*(.5*p.charge_target*[1;-signv*1i]);
  gs=1/pp.Rs+pp.G0;loadcoef=-s/(pp.Cs*s+gs);feedcoef=pp.Cds*s/(pp.Cs*s+gs);
  vd=(pp.b*pp.drive_matrix+pp.kappa*feedcoef*eye(2))\((s*s*eye(2)+s*D+K-pp.kappa*loadcoef*eye(2))*desired);
  u=(1+s*pp.driver_tau).*vd;X=(s*eye(12)-A)\(B*u);
  assert(norm(X(1:2)-desired)/norm(desired)<1e-8);
  side=[side;row(pp,freq,2,0,0,u,X(11:12),0)]; %#ok<AGROW>
 end
 % 校准文件声明已知电路参数和独立夹持夹具的串扰响应，不提供H/D/K/b/kappa。
 cal=struct('Cs',p.Cs,'G0',p.G0,'Cf',p.Cf,'Rf',p.Rf,...
  'driver_tau',p.driver_tau','afe_bw',p.afe_bw','Rs',loads,...
  'fixture','理想r=0夹持夹具；同负载/频率，两输入独立激励的复响应');
 if strcmp(plan{c,3},'afe'),cal.afe_bw=cal.afe_bw.*[1.3 .75];end
 if strcmp(plan{c,3},'Cs'),cal.Cs=cal.Cs*1.2;end
 payload=struct('train',records,'validation',held,'motion',side,'motion_time',tf',...
  'carrier_Hz',carrier,'electronics',cal);
 writej(fullfile(root,'data','observations',[cid '.json']),payload);
 public.cases{end+1}=struct('id',cid,'file',[cid '.json']);
 [~,~,~,A]=pcn_plant(p);
 truth.cases{end+1}=struct('id',cid,'seed',plan{c,1},'independent',plan{c,6},...
  'kind',[plan{c,4} '_' plan{c,3}],'phasor_noise_sigma_V',plan{c,5},...
  'expected_eligible',strcmp(plan{c,4},'general')&&strcmp(plan{c,3},'none')&&plan{c,5}==0,...
  'D',-A(3:4,3:4),'K',-A(3:4,1:2),'H',p.detect_matrix,'kappa',p.kappa,...
  'motion_reference_rad',angle_ref');
 if c==1
  writej(fullfile(root,'data','private_score','simulink_parameters.json'),p);
 end
end
writej(fullfile(root,'data','observations','protocol.json'),public);
writej(fullfile(root,'data','private_score','truth.json'),truth);
fprintf('A1: exported %d cases from original continuous 12-state plant.\n',numel(public.cases));
end

function result=make_records(p,loads,freqs,repeat,sigma)
result=[];
for l=1:numel(loads)
 pp=p;pp.Rs=loads(l);[~,~,~,A,B]=pcn_plant(pp);
 for freq=freqs
  s=2i*pi*freq;T=(s*eye(12)-A)\B;
  for e=1:2
   u=zeros(2,1);u(e)=.02*exp(1i*(.17*repeat+.31*e+.07*l));
   y=T(11:12,:)*u+sigma*(randn(2,1)+1i*randn(2,1));
   result=[result;row(pp,freq,l,repeat,e,u,y,sigma)]; %#ok<AGROW>
  end
 end
end
end

function v=row(p,freq,loadindex,repeat,experiment,u,y,sigma)
% 二阶电路KCL的独立夹持测量：r=0时只有驱动-检测馈通。
s=2i*pi*freq;F=diag(1./(1+s./(2*pi*p.afe_bw)));
q=-s/((p.Cs*s+1/p.Rs+p.G0)*p.Rs*p.Cf*(s+1/(p.Rf*p.Cf)));
fixture=-p.Cds*q*F*p.detect_matrix;
v=struct('frequency_Hz',freq,'load_index',loadindex,'repeat',repeat,'experiment',experiment,...
 'u_re',real(u)','u_im',imag(u)','y_re',real(y)','y_im',imag(y)',...
 'fixture_re',real(fixture),'fixture_im',imag(fixture),'sigma_V',sigma);
end
function writej(path,value)
fid=fopen(path,'w','n','UTF-8');assert(fid>0);cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(value));
end
function mkdir_if(p)
if ~isfolder(p),mkdir(p);end
end
