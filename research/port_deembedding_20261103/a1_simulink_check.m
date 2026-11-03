function report=a1_simulink_check()
% 真实动态Simulink台架：驱动/机械/传感节点/电荷放大/AFE五块互连，非数据回放。
% 与完整12状态频域解比较全部状态，标定辨识使用的频域记录由另一入口产生。
root=fileparts(mfilename('fullpath'));project=fileparts(fileparts(root));
addpath(fullfile(project,'HRG_WA_simulink','piezo_v10','revision_v10_2_cn'));
if ~isfolder(fullfile(root,'models')),mkdir(fullfile(root,'models'));end
if ~isfolder(fullfile(root,'evidence')),mkdir(fullfile(root,'evidence'));end
p=jsondecode(fileread(fullfile(root,'data','private_score','simulink_parameters.json')));
p.driver_tau=p.driver_tau(:);p.afe_bw=p.afe_bw(:);p.Rs=80000;
[~,~,~,A,B]=pcn_plant(p);w=2*pi*p.f0;q=p.charge_target;v=max(1e-6,w*q*p.Rs);
sc=[q q w*q w*q 1 1 v v q/p.Cf q/p.Cf q/p.Cf q/p.Cf];S=diag(sc);
An=S\A*S;Bn=S\B;
freqs=[600 998.5 1400 6500];U=zeros(2,numel(freqs));X=zeros(12,numel(freqs));
for k=1:numel(freqs)
 U(:,k)=.01*exp(1i*[.3*k;.17+.6*k]);s=2i*pi*freqs(k);
 X(:,k)=S*((s*eye(12)-An)\(Bn*U(:,k)));
end
x0=sum(real(X),2);name='hrg_wa_a1_port_deembedding';
if bdIsLoaded(name),close_system(name,0);end
load_system('simulink');new_system(name);
set_param(name,'Solver','ode113','SolverType','Variable-step','RelTol','1e-10','AbsTol','1e-12',...
 'MaxStep','1/200000','StopTime','.04','ReturnWorkspaceOutputs','on');
% 连续多正弦源避免ZOH/线性插值引入未声明的相位与混叠误差。
add_block('simulink/Signal Routing/Mux',[name '/Input_Mux'],'Inputs','2','Position',[220 95 225 170]);
for j=1:2
 sumname=sprintf('Sum_%d',j);add_block('simulink/Math Operations/Sum',[name '/' sumname],...
  'Inputs','++++','Position',[175 170+270*(j-1) 195 200+270*(j-1)]);
 for k=1:numel(freqs)
  n=sprintf('Sine_%d_%d',j,k);
  add_block('simulink/Sources/Sine Wave',[name '/' n],'Amplitude',num2str(abs(U(j,k)),17),...
   'Frequency',num2str(2*pi*freqs(k),17),'Phase',num2str(angle(U(j,k))+pi/2,17),...
   'SampleTime','0','Position',[25 100+270*(j-1)+50*(k-1) 100 125+270*(j-1)+50*(k-1)]);
  add_line(name,[n '/1'],[sumname '/' num2str(k)],'autorouting','on');
 end
 add_line(name,[sumname '/1'],['Input_Mux/' num2str(j)],'autorouting','on');
end
% 每块状态单独按SI特征尺度归一化，输出恢复物理量，精确复用原A/B各子矩阵。
ssblock(name,'Driver_驱动器',5:6,[],[A(5:6,5:6)],B(5:6,:),eye(2),x0,sc,[320 110 470 180]);
ssblock(name,'Head_机械表头',1:4,[],A(1:4,1:4),A(1:4,5:8),eye(4),x0,sc,[710 130 875 220]);
ssblock(name,'Sensor_传感端口',7:8,[],A(7:8,7:8),[A(7:8,3:4) A(7:8,5:6) B(7:8,:)],eye(2),x0,sc,[710 350 875 420]);
ssblock(name,'ChargeAmp_电荷放大器',9:10,[],A(9:10,9:10),A(9:10,7:8),eye(2),x0,sc,[1010 350 1190 420]);
ssblock(name,'AFE_模拟前端',11:12,[],A(11:12,11:12),A(11:12,9:10),eye(2),x0,sc,[1320 350 1480 420]);
add_block('simulink/Signal Routing/Mux',[name '/Head_Inputs'],'Inputs','2','Position',[625 125 630 220]);
add_block('simulink/Signal Routing/Mux',[name '/Sensor_Inputs'],'Inputs','3','Position',[625 345 630 425]);
add_block('simulink/Signal Routing/Demux',[name '/Charge_Velocity'],'Outputs','[2 2]','Position',[915 130 920 220]);
line(name,'Input_Mux/1','Driver_驱动器/1');line(name,'Driver_驱动器/1','Head_Inputs/1');
line(name,'Sensor_传感端口/1','Head_Inputs/2');line(name,'Head_Inputs/1','Head_机械表头/1');
line(name,'Head_机械表头/1','Charge_Velocity/1');line(name,'Charge_Velocity/2','Sensor_Inputs/1');
line(name,'Driver_驱动器/1','Sensor_Inputs/2');line(name,'Input_Mux/1','Sensor_Inputs/3');
line(name,'Sensor_Inputs/1','Sensor_传感端口/1');line(name,'Sensor_传感端口/1','ChargeAmp_电荷放大器/1');
line(name,'ChargeAmp_电荷放大器/1','AFE_模拟前端/1');
add_block('simulink/Signal Routing/Mux',[name '/All_States_SI'],'Inputs','6','Position',[1630 160 1635 490]);
signals={'Charge_Velocity/1','Charge_Velocity/2','Driver_驱动器/1','Sensor_传感端口/1','ChargeAmp_电荷放大器/1','AFE_模拟前端/1'};
labels={'Charge_C','ChargeVelocity_C_s','Driver_V','Sensor_V','ChargeAmp_V','AFE_V'};
for k=1:6
 line(name,signals{k},['All_States_SI/' num2str(k)]);
 add_block('simulink/Sinks/Scope',[name '/Scope_' labels{k}],'OpenAtSimulationStart','off',...
  'Position',[1750 90+80*k 1830 130+80*k]);line(name,signals{k},['Scope_' labels{k} '/1']);
end
add_block('simulink/Sinks/To Workspace',[name '/Log_States'],'VariableName','a1_states','SaveFormat','Timeseries',...
 'Position',[1750 850 1850 890]);line(name,'All_States_SI/1','Log_States/1');
% 频谱输入必须离散：明确40kHz观察采样率；不将观察采样置于反馈路径。
add_block('simulink/Discrete/Zero-Order Hold',[name '/Spectrum_Sample_40kHz'],'SampleTime','1/40000','Position',[1510 720 1600 760]);
add_block('simulink/Signal Routing/Selector',[name '/Spectrum_X'],'InputPortWidth','2','Indices','1','Position',[1640 720 1690 760]);
line(name,'AFE_模拟前端/1','Spectrum_Sample_40kHz/1');line(name,'Spectrum_Sample_40kHz/1','Spectrum_X/1');
load_system('dspsnks4');add_block(sprintf('dspsnks4/Spectrum\nAnalyzer'),[name '/Spectrum_AFE'],...
 'OpenAtSimulationStart','off','SampleRateSource','Property','SampleRate','40000','SpectrumUnits','dBV','Position',[1750 720 1900 770]);
line(name,'Spectrum_X/1','Spectrum_AFE/1');
Simulink.Annotation(name,sprintf(['A1 压电端口辨识台架｜静止Omega=0｜合成SI参数\n'...
 '机械阻尼仅含本征项；传感端口加载由显式电压状态反馈，禁止重复加等效阻尼。\n'...
 '五个动态模块互连，全部12状态与独立频域解核对；不是波形回放。\n'...
 'Scope与40kHz频谱仅观察；辨识/去嵌在a1_fit.py离线执行；尚未接入AGC/PLL闭环。']));
modelpath=fullfile(root,'models',[name '.slx']);save_system(name,modelpath);
out=sim(name);ts=out.a1_states;t=ts.Time;actual=ts.Data;
if size(actual,2)~=12,actual=reshape(actual,numel(t),12);end
expected=zeros(numel(t),12);
for k=1:numel(freqs),expected=expected+real(exp(2i*pi*freqs(k)*t)*X(:,k).');end
err=(actual-expected)./sc;
report=struct('states',12,'samples',numel(t),'maximum_normalized_error',max(abs(err),[],'all'),...
 'normalized_RMS_error',sqrt(mean(err.^2,'all')),'scope','连续Simulink模块互连对频域稳态解；非硬件或控制闭环');
limits=jsondecode(fileread(fullfile(root,'acceptance.json')));
assert(report.maximum_normalized_error<limits.simulink_normalized_max_error);
fid=fopen(fullfile(root,'evidence','simulink_scoreboard.json'),'w','n','UTF-8');fprintf(fid,'%s\n',jsonencode(report));fclose(fid);
% 保存实际时域记录，便于逐点检查；不依赖.mat被忽略文件。
writematrix([t actual expected],fullfile(root,'evidence','simulink_states.csv'));
f=figure('Visible','off','Position',[100 100 1350 750]);tiledlayout(2,3);
for k=1:6
 nexttile;plot(t,actual(:,2*k-1:2*k));title(labels{k},'Interpreter','none');xlabel('时间 [s]');grid on;
end
sgtitle('A1 原生动态模块台架｜各电路参考面实际波形｜合成参数');
exportgraphics(f,fullfile(root,'evidence','simulink_waveforms.png'),'Resolution',130);close(f);
print(['-s' name],'-dpng','-r100',fullfile(root,'models','a1_structure.png'));
fprintf('A1 Simulink 12-state scoreboard: max normalized error %.6g\n',report.maximum_normalized_error);
close_system(name,0);
end

function ssblock(parent,name,indices,unused,A,B,C,x0,sc,pos) %#ok<INUSD>
S=diag(sc(indices));add_block('simulink/Continuous/State-Space',[parent '/' name],...
 'A',mat2str(S\A*S,17),'B',mat2str(S\B,17),'C',mat2str(C*S,17),...
 'D',mat2str(zeros(size(C,1),size(B,2))),...
 'InitialCondition',mat2str(S\x0(indices),17),'Position',pos);
end
function line(model,source,target)
add_line(model,source,target,'autorouting','on');
end
