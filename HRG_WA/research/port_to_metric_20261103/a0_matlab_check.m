function report=a0_matlab_check(root)
% A0跨语言回放：只从t/u/y记录重算OLS与交叉拟合IV，再核对Python结果。
% 与Python采用相同数学方法，因此这是实现scoreboard，不是第二个独立辨识定理。
% 真实角度只在最后绘图阶段读取，不能进入fit_records的辨识。
if nargin<1,root=fileparts(mfilename('fullpath'));end
obs=fullfile(root,'data','observations');ev=fullfile(root,'evidence');
p=jsondecode(fileread(fullfile(obs,'protocol.json')));
py=jsondecode(fileread(fullfile(ev,'estimates.json')));
scores=jsondecode(fileread(fullfile(ev,'scores.json')));
maxModel=0;maxW=0;maxAngle=0;eligibility=true;
for ci=1:numel(p.cases)
 c=at(p.cases,ci);expected=at(py.cases,ci);reps=p.repeats;
 batches=cell(reps,1);ols=zeros(12,reps);iv=zeros(12,reps);Cs=zeros(2,3,reps);
 for j=1:reps
  pair=cell(2,1);
  for channel=1:2
   pair{channel}=readmatrix(fullfile(obs,c.id,sprintf('train_%02d_%d.csv',j-1,channel-1)));
  end
  batches{j}=pair;ols(:,j)=fit_pair(pair,p,[]);
 end
 for j=1:reps
  pilot=mean(ols(:,setdiff(1:reps,j)),2);
  iv(:,j)=fit_pair(batches{j},p,pilot);
  Cs(:,:,j)=constraint(iv(:,j),p.reference_omega);
 end
 v=mean(iv,2);D=reshape(v(1:4),2,2);K=reshape(v(5:8),2,2);B=reshape(v(9:12),2,2);
 error=max(abs([D-expected.D,K-expected.K,B-expected.B]),[],'all');maxModel=max(maxModel,error);
 assert(error<1e-8,['跨语言算子不符: ' c.id]);
 C=mean(Cs,3);[~,S,V]=svd(C);singular=diag(S);z=V(:,end);
 W=[z(1),z(2)/sqrt(2);z(2)/sqrt(2),z(3)];positive=false;
 if abs(trace(W))>1e-12,W=2*W/trace(W);positive=min(eig(W))>.05;end
 delta=Cs-C;se=sqrt(sum(delta.^2,'all')/(reps*(reps-1)));
 epsilon=p.numeric_constraint_floor+p.uncertainty_inflation*se;
 gap=singular(end);eligible=positive&&gap>epsilon&&epsilon/(gap-epsilon)<=sin(p.null_direction_budget_rad);
 eligibility=eligibility&&(eligible==expected.calibration_update_eligible);
 assert(eligible==expected.calibration_update_eligible,['跨语言门控不符: ' c.id]);
 if eligible
  maxW=max(maxW,max(abs(W-expected.W),[],'all'));assert(maxW<1e-7);
  rec=readmatrix(fullfile(obs,c.id,'holdout_motion.csv'));y=rec(:,4:5);
  corrected=y*chol(W).';angle=unwrap(atan2(corrected(:,2),corrected(:,1)));angle=angle-angle(1);
  logged=readmatrix(fullfile(ev,[c.id '_angles.csv']));
  difference=max(abs(angle-logged(:,4)));maxAngle=max(maxAngle,difference);assert(difference<1e-7);
 end
end
report=struct('cases',numel(p.cases),'all_model_scoreboards',true,'all_eligibility_scoreboards',eligibility,...
 'max_model_absolute_difference',maxModel,'max_W_absolute_difference_accepted',maxW,...
 'max_angle_absolute_difference_accepted',maxAngle,'scope','same-method cross-language replay; not hardware or full piezo model validation');
fid=fopen(fullfile(ev,'matlab_replay.json'),'w','n','UTF-8');assert(fid>0);fprintf(fid,'%s\n',jsonencode(report));fclose(fid);

% 下面只做离线评分可视化。真值不参与上面的辨识或认证逻辑。
fig=figure('Visible','off','Position',[30 30 1400 900],'Color','w');
tl=tiledlayout(fig,2,2,'Padding','compact','TileSpacing','compact');
a=readmatrix(fullfile(ev,'case_001_angles.csv'));
t=readmatrix(fullfile(root,'data','private_score','case_001_motion_truth.csv'));
reference=t(:,2)-t(1,2);
nexttile;plot(a(:,1),a(:,2)-reference,'LineWidth',1.2);hold on;plot(a(:,1),a(:,4)-reference,'LineWidth',1.2);
grid on;xlabel('Time [normalized s]');ylabel('Modal increment error [rad]');title('Noiseless held-out motion');legend('Raw','Estimated metric');
nexttile;ids=14:18;raw=zeros(5,1);fixed=zeros(5,1);
for j=1:5,r=at(scores.cases,ids(j));raw(j)=r.raw_modal_increment_RMS_rad;fixed(j)=r.candidate_modal_increment_RMS_rad;end
bar([raw fixed]);set(gca,'YScale','log');grid on;xlabel('Independent positive case');ylabel('RMS [rad]');title('Fresh holdout seeds');legend('Raw','Calibrated');
nexttile;gaps=zeros(numel(py.cases),1);limits=gaps;
for j=1:numel(py.cases),r=at(py.cases,j);gaps(j)=max(r.constraint_singular_values(end),1e-18);limits(j)=r.epsilon_C*(1+1/sin(p.null_direction_budget_rad));end
semilogy(gaps,'o-');hold on;semilogy(limits,'s-');grid on;xlabel('Case');ylabel('Constraint singular value');title('Information gap and empirical gate');legend('Observed gap','Required gap');
nexttile;positive=find(arrayfun(@(j)at(scores.cases,j).eligible,1:numel(scores.cases)));de=zeros(numel(positive),1);ke=de;
for j=1:numel(positive),r=at(scores.cases,positive(j));de(j)=r.IV_relative_errors.D;ke(j)=r.IV_relative_errors.K;end
semilogy(max(de,1e-17),'o-');hold on;semilogy(max(ke,1e-17),'s-');grid on;xlabel('Eligible case');ylabel('Relative operator error');title('Offline oracle scoring only');legend('D_y','K_y');
title(tl,sprintf('A0: %d matched; %d eligible, %d rejected; conditional synthetic model',scores.summary.checks_matched,scores.summary.accepted,scores.summary.rejected));
exportgraphics(fig,fullfile(ev,'a0_dashboard.png'),'Resolution',140);close(fig);
disp(report);
end

function value=at(values,index)
if iscell(values),value=values{index};else,value=values(index);end
end

function vector=fit_pair(records,p,pilot)
X=[];Z=[];R=[];
for channel=1:numel(records)
 data=records{channel};assert(size(data,1)==p.samples&&size(data,2)==5);
 values=2*fft(data(:,2:5))/size(data,1);bins=p.train_bins(:);values=values(bins+1,:);
 U=values(:,1:2);Y=values(:,3:4);w=2*pi*bins*p.sample_rate/size(data,1);
 x=[1i*w.*Y,Y,-U];rhs=w.^2.*Y;
 if isempty(pilot),z=x;else
  D=reshape(pilot(1:4),2,2);K=reshape(pilot(5:8),2,2);B=reshape(pilot(9:12),2,2);predicted=zeros(size(Y));
  for f=1:numel(w),predicted(f,:)=((-w(f)^2*eye(2)+1i*w(f)*D+K)\(B*U(f,:).')).';end
  z=[1i*w.*predicted,predicted,-U];
 end
 X=[X;real(x);imag(x)];Z=[Z;real(z);imag(z)];R=[R;real(rhs);imag(rhs)]; %#ok<AGROW>
end
xs=max(vecnorm(X),1e-30);zs=max(vecnorm(Z),1e-30);xn=X./xs;zn=Z./zs;
if isempty(pilot),coef=xn\R;else,coef=(zn.'*xn)\(zn.'*R);end
coef=coef./xs.';D=coef(1:2,:).';K=coef(3:4,:).';B=coef(5:6,:).';vector=[D(:);K(:);B(:)];
end

function C=constraint(v,w)
D=reshape(v(1:4),2,2)/w;K=reshape(v(5:8),2,2)/w^2;C=zeros(2,3);
ops={D,K};for j=1:2,A=ops{j};C(j,:)=[A(1,2),(A(2,2)-A(1,1))/sqrt(2),-A(2,1)];end
end
