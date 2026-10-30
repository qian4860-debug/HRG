function mdl=p101_build(p,c,plant_p)
if nargin<1,p=p101_config;end;if nargin<2,c=p101_calibration;end;if nargin<3,plant_p=p;end
root=fileparts(mfilename('fullpath'));addpath(root);mdl='hrg_wa_v10_1_piezo';
p101_validate(p,c);p101_validate(plant_p);
assert(abs(p.Tc/p.Ts-round(p.Tc/p.Ts))<1e-10,'Noninteger demodulation window');
if bdIsLoaded(mdl),close_system(mdl,0);end;new_system(mdl);
mw=get_param(mdl,'ModelWorkspace');assignin(mw,'p',p);assignin(mw,'c',c);assignin(mw,'plant_p',plant_p);
assert(plant_p.Ts==p.Ts);[Ad,Bd,x0]=p101_plant(plant_p);assignin(mw,'Ad',Ad);assignin(mw,'Bd',Bd);assignin(mw,'x0',x0);
set_param(mdl,'Solver','FixedStepDiscrete','FixedStep','p.Ts','StopTime','p.duration','ReturnWorkspaceOutputs','on');
add_block('simulink/Discrete/Discrete State-Space',[mdl '/Intrinsic_Mechanics_and_Explicit_Port_Load'],...
 'A','Ad','B','Bd','C','eye(12)','D','zeros(12,2)','InitialCondition','x0','SampleTime','p.Ts','Position',[70 90 290 170]);
add_block('simulink/Signal Routing/Selector',[mdl '/AFE'],'InputPortWidth','12','Indices','[11 12]','Position',[330 95 380 135]);
add_block('simulink/User-Defined Functions/Level-2 MATLAB S-Function',[mdl '/ADC_With_Clip_Flags'],'FunctionName','p101_adc_sfun','Parameters','p','Position',[430 90 570 145]);
add_block('simulink/User-Defined Functions/Level-2 MATLAB S-Function',[mdl '/Window_Validity_Calibration_Control_DAC'],'FunctionName','p101_sfun','Parameters','p,c','Position',[620 85 890 165]);
add_line(mdl,'Intrinsic_Mechanics_and_Explicit_Port_Load/1','AFE/1');add_line(mdl,'AFE/1','ADC_With_Clip_Flags/1');
add_line(mdl,'ADC_With_Clip_Flags/1','Window_Validity_Calibration_Control_DAC/1');
add_line(mdl,'Window_Validity_Calibration_Control_DAC/1','Intrinsic_Mechanics_and_Explicit_Port_Load/1','autorouting','on');
names={'states','adc','dac','diagnostics'};ports={'Intrinsic_Mechanics_and_Explicit_Port_Load/1','ADC_With_Clip_Flags/1','Window_Validity_Calibration_Control_DAC/1','Window_Validity_Calibration_Control_DAC/2'};
for k=1:4
 add_block('simulink/Sinks/To Workspace',[mdl '/Log_' names{k}],'VariableName',['p101_' names{k}],'SaveFormat','Timeseries','Position',[940 200+65*k 1090 230+65*k]);
 add_line(mdl,ports{k},['Log_' names{k} '/1'],'autorouting','on');
 add_block('simulink/Sinks/Scope',[mdl '/Scope_' names{k}],'OpenAtSimulationStart','off','Position',[1140 200+65*k 1180 235+65*k]);
 add_line(mdl,ports{k},['Scope_' names{k} '/1'],'autorouting','on');
end
labels={'Motional_Charge_C','Charge_Velocity_C_s','Driver_V','Sensor_V','Charge_Amp_V','AFE_V'};
for k=1:6
 n=['Tap_' labels{k}];add_block('simulink/Signal Routing/Selector',[mdl '/' n],'InputPortWidth','12','Indices',mat2str([2*k-1 2*k]),'Position',[90 260+65*k 160 295+65*k]);
 add_line(mdl,ports{1},[n '/1'],'autorouting','on');
 add_block('simulink/Sinks/Scope',[mdl '/Scope_' labels{k}],'OpenAtSimulationStart','off','Position',[230 260+65*k 280 295+65*k]);add_line(mdl,[n '/1'],['Scope_' labels{k} '/1']);
end
load_system('dspsnks4');
for k=1:2
 if k==1,source='ADC_With_Clip_Flags/1';width='4';label='ADC';else,source='Window_Validity_Calibration_Control_DAC/1';width='2';label='DAC';end
 n=['SpectrumInput_' label];add_block('simulink/Signal Routing/Selector',[mdl '/' n],'InputPortWidth',width,'Indices','1','Position',[450 520+80*k 500 555+80*k]);add_line(mdl,source,[n '/1'],'autorouting','on');
 add_block(sprintf('dspsnks4/Spectrum\nAnalyzer'),[mdl '/Spectrum_' label],'OpenAtSimulationStart','off','SampleRateSource','Property','SampleRate',num2str(1/p.Ts),'SpectrumUnits','dBV','Position',[560 520+80*k 730 565+80*k]);add_line(mdl,[n '/1'],['Spectrum_' label '/1']);
end
set_param(mdl,'Description','V10.1 synthetic motional-charge carrier loop. Intrinsic mechanical damping + explicit electrical load. Window-center timestamps, angle validity, independent calibration profile, integer-domain DAC clipping.');
folder=fullfile(root,'models');if ~exist(folder,'dir'),mkdir(folder);end;save_system(mdl,fullfile(folder,[mdl '.slx']));
end
