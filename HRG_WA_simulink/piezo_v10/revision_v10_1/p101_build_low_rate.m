function mdl=p101_build_low_rate(p)
if nargin<1,p=p101_envelope_config;end
root=fileparts(mfilename('fullpath'));addpath(root);mdl='hrg_wa_v10_1_low_rate';
if bdIsLoaded(mdl),close_system(mdl,0);end;new_system(mdl);mw=get_param(mdl,'ModelWorkspace');assignin(mw,'p',p);
set_param(mdl,'Solver','FixedStepDiscrete','FixedStep','p.envTs','StopTime','p.envDuration','ReturnWorkspaceOutputs','on');
add_block('simulink/User-Defined Functions/Level-2 MATLAB S-Function',[mdl '/Arbitrary_Axes_Envelope_AGC_Quadrature_Phase_VirtualPrecession'],'FunctionName','p101_envelope_sfun','Parameters','p','Position',[100 100 440 180]);
add_block('simulink/Sinks/To Workspace',[mdl '/Log_Envelope'],'VariableName','p101_envelope','SaveFormat','Timeseries','Position',[530 100 690 140]);
add_line(mdl,'Arbitrary_Axes_Envelope_AGC_Quadrature_Phase_VirtualPrecession/1','Log_Envelope/1');
add_block('simulink/Sinks/Scope',[mdl '/Scope_IQ_Cp_Voltage'],'Position',[530 200 690 250]);
add_line(mdl,'Arbitrary_Axes_Envelope_AGC_Quadrature_Phase_VirtualPrecession/1','Scope_IQ_Cp_Voltage/1');
set_param(mdl,'Description','Long-horizon first-order normalized motional-charge envelope. Independent axes, free WA vs virtual Cp. Does not replace fast carrier/ADC validation.');
folder=fullfile(root,'models');if ~exist(folder,'dir'),mkdir(folder);end;save_system(mdl,fullfile(folder,[mdl '.slx']));
end
