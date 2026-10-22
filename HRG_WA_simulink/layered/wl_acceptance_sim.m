function [out,c]=wl_acceptance_sim(c)
% Unsaved isolated model; old accepted .slx and user edits are never overwritten.
c.name='hrg_wa_acceptance_runtime';c.observers=false;c.spectra=false;
c.maxLogPoints=max(c.maxLogPoints,ceil(c.duration*c.fsPlant)+1);
wl_build(c,false);cleanup=onCleanup(@()close_system(c.name,0)); %#ok<NASGU>
tap('Capacitive_CV_PGA_AA','PGA_Finite_Bandwidth/1','afe_request');
tap('DAC_Driver_Force','Driver_Slew/1','driver_request');
tap('NCO','Phase/1','nco_phase');
c=wl_setup(c);out=sim(c.name,'StopTime',num2str(c.duration,17));
 function tap(subsystem,source,label)
  parent=[c.name '/' subsystem];name=['tap_accept_' label];
  add_block('simulink/Sinks/To Workspace',[parent '/' name], ...
   'VariableName',name,'SaveFormat','Timeseries','MaxDataPoints',num2str(c.maxLogPoints));
  add_line(parent,source,[name '/1'],'autorouting','on');
 end
end
