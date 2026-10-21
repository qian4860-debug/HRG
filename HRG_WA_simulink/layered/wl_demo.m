function out=wl_demo(stage,duration)
% Open live library observers before simulation; retain a logged-data viewer.
if nargin<1,stage=5;end
if nargin<2,duration=2;end
c=wl_config(stage);c.duration=duration;c.name=[c.name '_demo'];
wl_build(c,false);c=wl_setup(c);
live=~batchStartupOptionUsed;
if live,open_system(c.name);end
for label={'adc','iq','driver'}
 for prefix={'Scope_','Spectrum_'}
  blocks=find_system(c.name,'LookUnderMasks','all','Name',[prefix{1} label{1}]);
  for k=1:numel(blocks)
   % Let Simulink open a compiled instrument at start. Opening the DSP web
   % window before compilation can stall a non-desktop MATLAB session.
   if live,set_param(blocks{k},'OpenAtSimulationStart','on');end
  end
 end
end
drawnow;
fprintf('Running %s (%.6g s). Live library windows: %d.\n',c.name,c.duration,live);
out=sim(c.name,'StopTime',num2str(c.duration,17));
assignin('base','out_layered',out);assignin('base','wl_demo_configuration',c);
fprintf('Simulation data saved; opening persistent logged-data replay.\n');
fig=wl_view_results(out,c);assignin('base','hrg_wa_viewer',fig);
fprintf('Simulation complete. Persistent replay: hrg_wa_viewer (19 signal tabs).\n');
fprintf('Replay again: wl_view_results(out_layered,wl_demo_configuration);\n');
end
