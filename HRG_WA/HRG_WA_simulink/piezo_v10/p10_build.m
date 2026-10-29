function mdl=p10_build(p)
if nargin==0,p=p10_config;end
root=fileparts(mfilename('fullpath'));addpath(root);mdl='hrg_wa_v10_piezo';
if bdIsLoaded(mdl),close_system(mdl,0);end
new_system(mdl);mw=get_param(mdl,'ModelWorkspace');assignin(mw,'p',p);
[Ad,Bd,x0]=p10_plant(p);assignin(mw,'Ad',Ad);assignin(mw,'Bd',Bd);assignin(mw,'x0',x0);
set_param(mdl,'Solver','FixedStepDiscrete','FixedStep','p.Ts','StopTime','p.duration','ReturnWorkspaceOutputs','on');
add_block('simulink/Discrete/Discrete State-Space',[mdl '/Coupled_Piezo_Mechanics_Driver_Sensor_AFE'],...
'A','Ad','B','Bd','C','eye(12)','D','zeros(12,2)','InitialCondition','x0','SampleTime','p.Ts','Position',[90 80 310 160]);
add_block('simulink/Signal Routing/Selector',[mdl '/AFE_Tap'],'InputPortWidth','12','Indices','[11 12]','Position',[360 90 410 130]);
add_block('simulink/Math Operations/Gain',[mdl '/Channel_Gain'],'Gain','diag([1 p.gain_y])','Multiplication','Matrix(K*u)','Position',[450 90 540 130]);
add_block('simulink/User-Defined Functions/Level-2 MATLAB S-Function',[mdl '/ADC_Clip_Quantize'],'FunctionName','p10_adc_sfun','Parameters','p','Position',[580 90 700 135]);
add_block('simulink/User-Defined Functions/Level-2 MATLAB S-Function',[mdl '/IQ_AGC_Quadrature_PLL_DAC'],'FunctionName','p10_controller_sfun','Parameters','p','Position',[745 80 970 160]);
add_line(mdl,'Coupled_Piezo_Mechanics_Driver_Sensor_AFE/1','AFE_Tap/1');add_line(mdl,'AFE_Tap/1','Channel_Gain/1');
add_line(mdl,'Channel_Gain/1','ADC_Clip_Quantize/1');add_line(mdl,'ADC_Clip_Quantize/1','IQ_AGC_Quadrature_PLL_DAC/1');
add_line(mdl,'IQ_AGC_Quadrature_PLL_DAC/1','Coupled_Piezo_Mechanics_Driver_Sensor_AFE/1','autorouting','on');
names={'states','adc','control','iq'};ports={'Coupled_Piezo_Mechanics_Driver_Sensor_AFE/1','ADC_Clip_Quantize/1','IQ_AGC_Quadrature_PLL_DAC/1','IQ_AGC_Quadrature_PLL_DAC/2'};
for k=1:4
 add_block('simulink/Sinks/To Workspace',[mdl '/Log_' names{k}],'VariableName',['p10_' names{k}],'SaveFormat','Timeseries','Position',[1020 200+65*k 1150 230+65*k]);
 add_line(mdl,ports{k},['Log_' names{k} '/1'],'autorouting','on');
 add_block('simulink/Sinks/Scope',[mdl '/Scope_' names{k}],'Position',[1200 200+65*k 1240 235+65*k]);add_line(mdl,ports{k},['Scope_' names{k} '/1'],'autorouting','on');
end
labels={'Displacement_m','Velocity_m_s','Driver_V','Sensor_Port_V','Charge_Amp_V','AFE_V'};
for k=1:6
 tap=['Tap_' labels{k}];sc=['Scope_' labels{k}];
 add_block('simulink/Signal Routing/Selector',[mdl '/' tap],'InputPortWidth','12','Indices',mat2str([2*k-1 2*k]),'Position',[100 260+65*k 160 295+65*k]);
 add_line(mdl,'Coupled_Piezo_Mechanics_Driver_Sensor_AFE/1',[tap '/1'],'autorouting','on');
 add_block('simulink/Sinks/Scope',[mdl '/' sc],'Position',[210 260+65*k 260 295+65*k]);add_line(mdl,[tap '/1'],[sc '/1']);
end
load_system('dspsnks4');
for k=1:2
 source='ADC_Clip_Quantize/1';label='ADC';if k==2,source='Tap_Driver_V/1';label='Driver';end
 sel=['Spectrum_Input_' label];sp=['Spectrum_' label];
 add_block('simulink/Signal Routing/Selector',[mdl '/' sel],'InputPortWidth','2','Indices','1','Position',[450 500+80*k 500 535+80*k]);add_line(mdl,source,[sel '/1'],'autorouting','on');
 add_block(sprintf('dspsnks4/Spectrum\nAnalyzer'),[mdl '/' sp],'OpenAtSimulationStart','off',...
 'SampleRateSource','Property','SampleRate',num2str(1/p.Ts),'SpectrumUnits','dBV','Position',[560 500+80*k 720 545+80*k]);add_line(mdl,[sel '/1'],[sp '/1']);
end
set_param(mdl,'Description','V10 synthetic piezo carrier closed loop. State pairs: q,velocity,driver voltage,sensor voltage,charge amplifier,AFE. Equations and limitations in docs.');
if ~exist(fullfile(root,'models'),'dir'),mkdir(fullfile(root,'models'));end
save_system(mdl,fullfile(root,'models',[mdl '.slx']));
end
