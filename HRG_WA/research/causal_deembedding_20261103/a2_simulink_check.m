function report=a2_simulink_check()
% 原生离散SOS、驱动滤波、串扰补偿、NCO及滑动平均，逐样本核对Python。
% 输入为保存的物理端口测试流；模型实际计算滤波，不回放期望输出。
root=fileparts(mfilename('fullpath'));cfg=jsondecode(fileread(fullfile(root,'config.json')));
if ~isfolder(fullfile(root,'models')),mkdir(fullfile(root,'models'));end
short=jsondecode(fileread(fullfile(root,'evidence','window_40','estimates.json')));
long=jsondecode(fileread(fullfile(root,'evidence','window_240','estimates.json')));
a=readmatrix(fullfile(root,'evidence','window_40','stream_scoreboard.csv'));
b=readmatrix(fullfile(root,'evidence','window_240','stream_scoreboard.csv'));
assert(isequal(a(:,1:5),b(:,1:5)));name='hrg_wa_a2_causal_frontend';
if bdIsLoaded(name),close_system(name,0);end
load_system('simulink');new_system(name);mws=get_param(name,'ModelWorkspace');assignin(mws,'a2_input',a(:,1:5));
ts=1/cfg.sample_rate_Hz;
set_param(name,'SolverType','Fixed-step','Solver','FixedStepDiscrete','FixedStep',num2str(ts,17),...
 'StopTime',num2str(a(end,1),17),'ReturnWorkspaceOutputs','on');
add_block('simulink/Sources/From Workspace',[name '/Port_Stream_u_y'],'VariableName','a2_input',...
 'Interpolate','off','OutputAfterFinalValue','Holding final value','SampleTime',num2str(ts,17),'Position',[30 200 160 250]);
build_profile([name '/Short_Window_40'],short.cases(1).coefficients,40,cfg,[280 80 510 180]);
build_profile([name '/Long_Window_240'],long.cases(1).coefficients,240,cfg,[280 320 510 420]);
add_line(name,'Port_Stream_u_y/1','Short_Window_40/1','autorouting','on');add_line(name,'Port_Stream_u_y/1','Long_Window_240/1','autorouting','on');
add_block('simulink/Signal Routing/Mux',[name '/Both_Profiles'],'Inputs','2','ShowName','off','Position',[630 140 635 380]);
for k=1:2
 n={'Short_Window_40','Long_Window_240'};delay=['Publish_Delay_' num2str(k)];
 add_block('simulink/Discrete/Unit Delay',[name '/' delay],'SampleTime',num2str(ts,17),'InitialCondition','0',...
  'Position',[550 100+240*(k-1) 590 140+240*(k-1)]);
 add_line(name,[n{k} '/1'],[delay '/1'],'autorouting','on');
 add_line(name,[delay '/1'],['Both_Profiles/' num2str(k)],'autorouting','on');
end
add_block('simulink/Sinks/To Workspace',[name '/Log_Streaming_Output'],'VariableName','a2_output','SaveFormat','Timeseries','Position',[750 220 900 260]);
add_line(name,'Both_Profiles/1','Log_Streaming_Output/1','autorouting','on');
for k=1:2
 n={'Short_Window_40','Long_Window_240'};add_block('simulink/Sinks/Scope',[name '/Scope_' n{k}],...
  'OpenAtSimulationStart','off','Position',[750 70+300*(k-1) 900 110+300*(k-1)]);
 add_line(name,['Publish_Delay_' num2str(k) '/1'],['Scope_' n{k} '/1'],'autorouting','on');
end
add_block('simulink/Signal Routing/Selector',[name '/Observe_AFE_X'],'InputPortWidth','4','Indices','3','Position',[250 520 340 560]);
add_line(name,'Port_Stream_u_y/1','Observe_AFE_X/1','autorouting','on');
load_system('dspsnks4');add_block(sprintf('dspsnks4/Spectrum\nAnalyzer'),[name '/Spectrum_AFE_V'],...
 'OpenAtSimulationStart','off','SampleRateSource','Property','SampleRate','40000','SpectrumUnits','dBV','Position',[440 500 620 580]);
add_line(name,'Observe_AFE_X/1','Spectrum_AFE_V/1','autorouting','on');
Simulink.Annotation(name,sprintf(['A2 因果限带前端台架｜40 kHz｜已校准W，未接AGC/PLL反馈控制\n'...
 '双击两分支查看SOS、驱动重建、串扰补偿、I/Q解调和两级滑窗。\n'...
 '分支输出[z_x,z_y,I_x,I_y,Q_x,Q_y]，均为运动电荷标称值归一化。\n'...
 '输入为原12状态端口源测试流；分支是真实动态计算，期望输出只用于离线scoreboard。\n'...
 '角度、有效性、校准/噪声预算和源时间戳由a2_process.py计算；不是完整控制闭环。']));
model=fullfile(root,'models',[name '.slx']);save_system(name,model);out=sim(name);
actual=out.a2_output.Data;expected=[zeros(1,12);a(1:end-1,6:11) b(1:end-1,6:11)];
assert(isequal(size(actual),size(expected)));
error=max(abs(actual-expected),[],'all');assert(error<1e-8);
report=struct('samples',size(actual,1),'channels',12,'maximum_absolute_difference',error,...
 'profiles',[40 240],'scope','独立原生Simulink离散实现对Python状态算法；不是实时硬件或全闭环');
fid=fopen(fullfile(root,'evidence','simulink_scoreboard.json'),'w','n','UTF-8');fprintf(fid,'%s\n',jsonencode(report));fclose(fid);
print(['-s' name],'-dpng','-r120',fullfile(root,'models','a2_structure.png'));
print(['-s' name '/Short_Window_40'],'-dpng','-r100',fullfile(root,'models','a2_frontend_detail.png'));
fprintf('A2 Simulink streaming scoreboard: %d samples, max difference %.6g\n',size(actual,1),error);
close_system(name,0);
end

function build_profile(path,c,M,cfg,position)
add_block('built-in/Subsystem',path,'Position',position);ts=num2str(1/cfg.sample_rate_Hz,17);
add_block('simulink/Sources/In1',[path '/Port_u_y'],'Position',[20 140 50 160]);
add_block('simulink/Signal Routing/Demux',[path '/Split_u_y'],'Outputs','[1 1 1 1]','Position',[90 60 95 240]);
ln(path,'Port_u_y/1','Split_u_y/1');
add_block('simulink/Signal Routing/Mux',[path '/Driver_Vector'],'Inputs','2','Position',[390 180 395 260]);
for j=1:2
 endpoint=sos(path,['Driver_' num2str(j)],c.driver_sos(j),['Split_u_y/' num2str(j)],[160 150+80*j]);
 ln(path,endpoint,['Driver_Vector/' num2str(j)]);
end
add_block('simulink/Math Operations/Gain',[path '/FeedCharge_Matrix'],'Gain',mat2str(c.feed_charge_matrix_normalized,17),...
 'Multiplication','Matrix(K*u)','Position',[440 190 550 250]);ln(path,'Driver_Vector/1','FeedCharge_Matrix/1');
add_block('simulink/Signal Routing/Demux',[path '/Feed_Split'],'Outputs','2','Position',[590 190 595 250]);ln(path,'FeedCharge_Matrix/1','Feed_Split/1');
add_block('simulink/Sources/Sine Wave',[path '/NCO_I'],'Amplitude','2','Frequency',num2str(2*pi*cfg.carrier_Hz,17),...
 'Phase',num2str(pi/2,17),'SampleTime',ts,'Position',[850 650 940 680]);
add_block('simulink/Sources/Sine Wave',[path '/NCO_Q'],'Amplitude','2','Frequency',num2str(2*pi*cfg.carrier_Hz,17),...
 'Phase',num2str(pi,17),'SampleTime',ts,'Position',[850 720 940 750]);
add_block('simulink/Signal Routing/Mux',[path '/z_I_Q'],'Inputs','6','Position',[1500 50 1505 620]);
for j=1:2
 if iscell(c.inverse_sos),es=c.inverse_sos{j};else,es=c.inverse_sos(j,:);end
 % JSON嵌套数组在MATLAB中通常为二维struct；统一为线性section列表。
 endpoint=sos(path,['Inverse_' num2str(j)],es,['Split_u_y/' num2str(j+2)],[160 20+420*(j-1)]);
 common=sos(path,['Common_' num2str(j)],c.common_sos,['Feed_Split/' num2str(j)],[650 110+420*(j-1)]);
 sn=['Charge_' num2str(j)];add_block('simulink/Math Operations/Sum',[path '/' sn],'Inputs','++','Position',[1000 40+420*(j-1) 1020 80+420*(j-1)]);
 ln(path,endpoint,[sn '/1']);ln(path,common,[sn '/2']);ln(path,[sn '/1'],['z_I_Q/' num2str(j)]);
 for phase=1:2
  label={'I','Q'};pn=sprintf('Mix_%s_%d',label{phase},j);ypos=120+130*(phase-1)+420*(j-1);
  add_block('simulink/Math Operations/Product',[path '/' pn],'Position',[1070 ypos 1100 ypos+30]);
  ln(path,[sn '/1'],[pn '/1']);ln(path,['NCO_' label{phase} '/1'],[pn '/2']);endpoint=[pn '/1'];
  for stage=1:2
   bn=sprintf('MA_%s_%d_%d',label{phase},j,stage);
   add_block('simulink/Discrete/Discrete Filter',[path '/' bn],'Numerator',mat2str(ones(1,M)/M,17),'Denominator','1',...
    'SampleTime',ts,'Position',[1140+140*(stage-1) ypos 1260+140*(stage-1) ypos+40]);
   ln(path,endpoint,[bn '/1']);endpoint=[bn '/1'];
  end
  ln(path,endpoint,['z_I_Q/' num2str(2+2*(phase-1)+j)]);
 end
end
add_block('simulink/Sinks/Out1',[path '/Streaming_Output'],'Position',[1580 330 1610 350]);ln(path,'z_I_Q/1','Streaming_Output/1');
note=Simulink.Annotation(path,sprintf('限带逆滤波E_j与共同L的系数按z^{-1}递增；全零初始状态\nM=%d，两级滑窗的FIR中心延迟=(M-1)/40kHz\n串扰补偿使用独立夹具CdsH与因果重建驱动；严禁读取未来样本',M));
note.Position=[20 -120];
end

function endpoint=sos(path,prefix,sections,source,xy)
if iscell(sections),sections=[sections{:}];end
endpoint=source;
for k=1:numel(sections)
 sec=sections(k);n=[prefix '_SOS' num2str(k)];
 add_block('simulink/Discrete/Discrete Filter',[path '/' n],'Numerator',mat2str(sec.b(:)',17),...
  'Denominator',mat2str(sec.a(:)',17),'SampleTime','1/40000',...
  'Position',[xy(1)+160*(k-1) xy(2) xy(1)+140+160*(k-1) xy(2)+45]);
 ln(path,endpoint,[n '/1']);endpoint=[n '/1'];
end
end
function ln(path,a,b),add_line(path,a,b,'autorouting','on');end
