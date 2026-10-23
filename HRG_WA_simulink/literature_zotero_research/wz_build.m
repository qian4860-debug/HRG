function name=wz_build(c,saveArtifacts)
if nargin<2,saveArtifacts=false;end
c=wz_setup(c);assert(~c.online&&~c.frp&&~c.temperatureCompensate, ...
 'Direct-angle study does not replace online/FRP/temperature compensation logic');
name=w8_build(c,'carrier',false);
set_param([name '/NCO_IQ_CIC_FIR/IQ_Fixed_Format'],'MATLABFcn','wz_iq(u,wl_c)');
add_block('simulink/Signal Routing/Selector',[name '/Public_Navigation_Valid'], ...
 'InputPortWidth','4','Indices','3','Position',[1500 950 1540 990]);
add_line(name,'Algorithms_Kalman_RLS_FRP/2','Public_Navigation_Valid/1','autorouting','on');
add_block('simulink/User-Defined Functions/Level-2 MATLAB S-Function',[name '/Direct_Geometric_Navigation'], ...
 'FunctionName','wz_navigation_sfun','Parameters','wl_c','Position',[1630 890 1900 1000]);
add_line(name,'NCO_IQ_CIC_FIR/1','Direct_Geometric_Navigation/1','autorouting','on');
add_line(name,'Public_Navigation_Valid/1','Direct_Geometric_Navigation/2','autorouting','on');
add_line(name,'Virtual_Command_Sampling/1','Direct_Geometric_Navigation/3','autorouting','on');
add_block('simulink/Sinks/To Workspace',[name '/tap_direct_navigation'], ...
 'VariableName','tap_direct_navigation','SaveFormat','Timeseries','MaxDataPoints','wl_c.maxLogPoints', ...
 'Position',[2000 900 2200 940]);
add_line(name,'Direct_Geometric_Navigation/1','tap_direct_navigation/1','autorouting','on');
add_block('simulink/Sinks/Scope',[name '/Scope_direct_navigation'],'Position',[2260 900 2320 940]);
add_line(name,'Direct_Geometric_Navigation/1','Scope_direct_navigation/1','autorouting','on');
set_param(name,'PostLoadFcn',sprintf('addpath(fileparts(fileparts(get_param(''%s'',''FileName'')))); wz_setup(getVariable(get_param(''%s'',''ModelWorkspace''),''v8_saved_configuration''));',name,name));
if saveArtifacts
 r=fileparts(mfilename('fullpath'));folder=fullfile(r,'models');if ~isfolder(folder),mkdir(folder);end
 save_system(name,fullfile(folder,[name '.slx']));print(['-s' name],'-dpng','-r100',fullfile(folder,[name '.png']));
end
end
