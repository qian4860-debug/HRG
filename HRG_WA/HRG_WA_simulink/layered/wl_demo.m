function out=wl_demo(stage)
% Interactive MATLAB entry: show model and selected real library observers.
if nargin<1,stage=5;end
c=wl_config(stage);c.duration=2;[out,c]=wl_sim(c,true);
open_system(c.name);assignin('base','out_layered',out);
for label={'adc','iq','driver'}
 for prefix={'Scope_','Spectrum_'}
  blocks=find_system(c.name,'LookUnderMasks','all','Name',[prefix{1} label{1}]);
  for k=1:numel(blocks),open_system(blocks{k});end
 end
end
end
