function mdl=p10e_build(p)
root=fileparts(mfilename('fullpath'));addpath(root);addpath(fileparts(root));mdl='hrg_v10_electrical_only';
if bdIsLoaded(mdl),close_system(mdl,0);end
new_system(mdl);mw=get_param(mdl,'ModelWorkspace');assignin(mw,'p',p);[Ad,Bd,x0]=p10e_plant(p);assignin(mw,'Ad',Ad);assignin(mw,'Bd',Bd);assignin(mw,'x0',x0);
set_param(mdl,'Solver','FixedStepDiscrete','FixedStep','p.Ts','StopTime','p.duration','ReturnWorkspaceOutputs','on');
add_block('simulink/Discrete/Discrete State-Space',[mdl '/Charge_Domain_Piezo_Circuit'],'A','Ad','B','Bd','C','eye(12)','D','zeros(12,2)','InitialCondition','x0','SampleTime','p.Ts','Position',[100 100 320 180]);
add_block('simulink/Signal Routing/Selector',[mdl '/AFE_V'],'InputPortWidth','12','Indices','[11 12]','Position',[360 110 400 150]);
add_block('simulink/Math Operations/Gain',[mdl '/Gain_Mismatch'],'Gain','diag([1 p.gain_y])','Multiplication','Matrix(K*u)','Position',[440 110 550 150]);
add_block('simulink/User-Defined Functions/Level-2 MATLAB S-Function',[mdl '/ADC'],'FunctionName','p10_adc_sfun','Parameters','p','Position',[590 110 680 150]);
add_block('simulink/User-Defined Functions/Level-2 MATLAB S-Function',[mdl '/Charge_AGC_Quad_PLL'],'FunctionName','p10e_sfun','Parameters','p','Position',[730 100 940 180]);
add_line(mdl,'Charge_Domain_Piezo_Circuit/1','AFE_V/1');add_line(mdl,'AFE_V/1','Gain_Mismatch/1');add_line(mdl,'Gain_Mismatch/1','ADC/1');add_line(mdl,'ADC/1','Charge_AGC_Quad_PLL/1');add_line(mdl,'Charge_AGC_Quad_PLL/1','Charge_Domain_Piezo_Circuit/1','autorouting','on');
ports={'Charge_Domain_Piezo_Circuit/1','Charge_AGC_Quad_PLL/1','Charge_AGC_Quad_PLL/2'};names={'state','dac','iq'};
for k=1:3
 add_block('simulink/Sinks/To Workspace',[mdl '/Log_' names{k}],'VariableName',['e_' names{k}],'SaveFormat','Timeseries','Position',[300 240+70*k 440 275+70*k]);add_line(mdl,ports{k},['Log_' names{k} '/1'],'autorouting','on');
 add_block('simulink/Sinks/Scope',[mdl '/Scope_' names{k}],'Position',[490 240+70*k 540 275+70*k]);add_line(mdl,ports{k},['Scope_' names{k} '/1'],'autorouting','on');
end
set_param(mdl,'Description','Electrical-only synthetic research model. States 1:2 are motional charge [C], NOT displacement [m]. No mass, Theta or B supplied for stationary test.');
if ~exist(fullfile(root,'models'),'dir'),mkdir(fullfile(root,'models'));end
save_system(mdl,fullfile(root,'models',[mdl '.slx']));
end
