function mdl=p102_build(p,c,bench)
% Original implementation: grouped EXACT joint ZOH, not separate local ZOHs.
root=p102_setup;if nargin<1,p=p101_config;end;if nargin<2,c=p101_calibration;end;if nargin<3,bench=false;end
p101_validate(p,c);folder=fullfile(root,'models');if ~exist(folder,'dir'),mkdir(folder);end
lib='hrg_wa_v10_2_modules';
if bdIsLoaded(lib),close_system(lib,0);end;new_system(lib,'Library');set_param(lib,'Lock','off');
names={'Mechanical_Head','Drive_Electronics','Piezo_Sensor_Port','Charge_Amplifier','Analog_Front_End'};
rows={1:4,5:6,7:8,9:10,11:12};
for k=1:5,partition([lib '/' names{k}],rows{k},[50 40+110*k 280 120+110*k]);end
save_system(lib,fullfile(folder,[lib '.slx']));set_param(lib,'Lock','on');
if bench,mdl='hrg_wa_v10_2_port_bench';else,mdl='hrg_wa_v10_2_modular';end
if bdIsLoaded(mdl),close_system(mdl,0);end;new_system(mdl);
mw=get_param(mdl,'ModelWorkspace');assignin(mw,'p',p);assignin(mw,'c',c);[Ad,Bd,x0]=p101_plant(p);
assignin(mw,'Ad',Ad);assignin(mw,'Bd',Bd);assignin(mw,'x0',x0);
set_param(mdl,'Solver','FixedStepDiscrete','FixedStep','p.Ts','StopTime','p.duration','ReturnWorkspaceOutputs','on');
plant=[mdl '/Piezo_Head_and_Circuits'];empty(plant,[80 100 340 210]);
add_block('simulink/Sources/In1',[plant '/DAC_V'],'Position',[25 45 55 65]);
add_block('simulink/Signal Routing/Mux',[plant '/Joint_State'],'Inputs','5','Position',[620 75 625 460]);
for k=1:5
 n=names{k};add_block([lib '/' n],[plant '/' n],'Position',[240 35+100*(k-1) 490 110+100*(k-1)]);
 add_line(plant,'Joint_State/1',[n '/1'],'autorouting','on');add_line(plant,'DAC_V/1',[n '/2'],'autorouting','on');
 add_line(plant,[n '/1'],['Joint_State/' num2str(k)],'autorouting','on');
end
add_block('simulink/Sinks/Out1',[plant '/States'],'Position',[710 245 740 265]);add_line(plant,'Joint_State/1','States/1');
set_param(plant,'Description','Joint normalized ZOH rows retain reciprocal sensor loading and all within-sample circuit coupling. Every module updates the same sample, no extra delay.');
if bench
 t=(0:round(p.duration/p.Ts))'*p.Ts;input=[.03*sin(2*pi*900*t),.02*cos(2*pi*1100*t)];assignin(mw,'bench_input',[t input]);
 add_block('simulink/Sources/From Workspace',[mdl '/Independent_Port_Stimulus'],'VariableName','bench_input','Interpolate','off','OutputAfterFinalValue','Holding final value','SampleTime','p.Ts','Position',[70 320 320 365]);
 add_line(mdl,'Independent_Port_Stimulus/1','Piezo_Head_and_Circuits/1','autorouting','on');
 logblock(mdl,'states','Piezo_Head_and_Circuits/1',[440 130 590 170]);
else
 add_block('simulink/Signal Routing/Selector',[mdl '/AFE_V'],'InputPortWidth','12','Indices','[11 12]','Position',[390 120 450 160]);
 empty([mdl '/ADC_Interface'],[500 110 680 175]);wrapper([mdl '/ADC_Interface'],'p101_adc_sfun','p',1);
 empty([mdl '/Digital_Control_and_DAC'],[760 105 1030 195]);wrapper([mdl '/Digital_Control_and_DAC'],'p101_sfun','p,c',2);
 add_line(mdl,'Piezo_Head_and_Circuits/1','AFE_V/1');add_line(mdl,'AFE_V/1','ADC_Interface/1');
 add_line(mdl,'ADC_Interface/1','Digital_Control_and_DAC/1');add_line(mdl,'Digital_Control_and_DAC/1','Piezo_Head_and_Circuits/1','autorouting','on');
 observer([mdl '/Instrumentation'],[450 330 760 440]);
 ports={'Piezo_Head_and_Circuits/1','ADC_Interface/1','Digital_Control_and_DAC/1','Digital_Control_and_DAC/2'};
 for k=1:4,add_line(mdl,ports{k},['Instrumentation/' num2str(k)],'autorouting','on');end
 set_param([mdl '/Digital_Control_and_DAC'],'Description','Sealed V10.1 tick: window IQ, validity, calibration, AGC, quadrature, PLL, virtual precession and integer DAC. Algorithm state machine intentionally remains shared for equivalence.');
end
set_param(mdl,'Description','V10.2 structural revision inspired by static Gyro.rar module organization. Piezo whole-angle physics and sealed V10.1 controller retained; no SDtoolbox dependency.');
save_system(mdl,fullfile(folder,[mdl '.slx']));
end
function empty(path,pos)
add_block('simulink/Ports & Subsystems/Subsystem',path,'Position',pos);Simulink.SubSystem.deleteContents(path);
end
function partition(path,rows,pos)
empty(path,pos);r=mat2str(rows);
add_block('simulink/Sources/In1',[path '/Joint_State'],'Port','1','Position',[30 35 60 55]);
add_block('simulink/Sources/In1',[path '/DAC_V'],'Port','2','Position',[30 105 60 125]);
add_block('simulink/Math Operations/Gain',[path '/Joint_ZOH_A_rows'],'Gain',['Ad(' r ',:)'],'Multiplication','Matrix(K*u)','Position',[110 20 250 65]);
add_block('simulink/Math Operations/Gain',[path '/Joint_ZOH_B_rows'],'Gain',['Bd(' r ',:)'],'Multiplication','Matrix(K*u)','Position',[110 95 250 140]);
add_block('simulink/Math Operations/Sum',[path '/Next_State'],'Inputs','++','Position',[290 55 320 95]);
add_block('simulink/Discrete/Unit Delay',[path '/Physical_State'],'InitialCondition',['x0(' r ')'],'SampleTime','p.Ts','Position',[365 55 425 95]);
add_block('simulink/Sinks/Out1',[path '/State'],'Position',[480 60 510 80]);
add_line(path,'Joint_State/1','Joint_ZOH_A_rows/1');add_line(path,'DAC_V/1','Joint_ZOH_B_rows/1');
add_line(path,'Joint_ZOH_A_rows/1','Next_State/1');add_line(path,'Joint_ZOH_B_rows/1','Next_State/2');add_line(path,'Next_State/1','Physical_State/1');add_line(path,'Physical_State/1','State/1');
end
function wrapper(path,fun,params,n)
add_block('simulink/Sources/In1',[path '/Input'],'Position',[30 60 60 80]);
add_block('simulink/User-Defined Functions/Level-2 MATLAB S-Function',[path '/Validated_Kernel'],'FunctionName',fun,'Parameters',params,'Position',[115 40 300 110]);
add_line(path,'Input/1','Validated_Kernel/1');
for k=1:n
 add_block('simulink/Sinks/Out1',[path '/Output' num2str(k)],'Port',num2str(k),'Position',[360 20+60*k 390 40+60*k]);
 add_line(path,['Validated_Kernel/' num2str(k)],['Output' num2str(k) '/1']);
end
end
function observer(path,pos)
empty(path,pos);names={'states','adc','dac','diagnostics'};
for k=1:4
 add_block('simulink/Sources/In1',[path '/' names{k}],'Port',num2str(k),'Position',[30 40+80*k 60 60+80*k]);
 logblock(path,names{k},[names{k} '/1'],[150 30+80*k 310 70+80*k]);
 add_block('simulink/Sinks/Scope',[path '/Scope_' names{k}],'OpenAtSimulationStart','off','Position',[360 35+80*k 410 70+80*k]);add_line(path,[names{k} '/1'],['Scope_' names{k} '/1']);
end
labels={'Charge_C','ChargeVelocity_C_s','Driver_V','Sensor_V','CV_V','AFE_V','IQ','PLL_Hz','Energy_Linearity_Validity','Source_Timestamps'};
indices={'[1 2]','[3 4]','[5 6]','[7 8]','[9 10]','[11 12]','[1 2 3 4]','5','[6 7 8]','[10 11 12 13]'};
for k=1:numel(labels)
 if k<=6,source='states';width='12';else,source='diagnostics';width='18';end
 n=['Tap_' labels{k}];add_block('simulink/Signal Routing/Selector',[path '/' n],'InputPortWidth',width,'Indices',indices{k},'Position',[500 40*k 560 25+40*k]);
 add_line(path,[source '/1'],[n '/1'],'autorouting','on');
 add_block('simulink/Sinks/Scope',[path '/Scope_' labels{k}],'OpenAtSimulationStart','off','Position',[620 40*k 680 25+40*k]);add_line(path,[n '/1'],['Scope_' labels{k} '/1']);
end
load_system('dspsnks4');
for k=1:2
 if k==1,n='adc';width='4';else,n='dac';width='2';end
 add_block('simulink/Signal Routing/Selector',[path '/FFT_Input_' n],'InputPortWidth',width,'Indices','1','Position',[500 470+70*k 560 500+70*k]);add_line(path,[n '/1'],['FFT_Input_' n '/1']);
 add_block(sprintf('dspsnks4/Spectrum\nAnalyzer'),[path '/Spectrum_' n],'OpenAtSimulationStart','off','SampleRateSource','Property','SampleRate','1/p.Ts','SpectrumUnits','dBV','Position',[620 460+70*k 790 510+70*k]);add_line(path,['FFT_Input_' n '/1'],['Spectrum_' n '/1']);
end
end
function logblock(path,n,source,pos)
add_block('simulink/Sinks/To Workspace',[path '/Log_' n],'VariableName',['p102_' n],'SaveFormat','Timeseries','Position',pos);add_line(path,source,['Log_' n '/1'],'autorouting','on');
end
