function [out,c]=wl_sim(c,rebuild)
if nargin<2,rebuild=false;end
root=fileparts(mfilename('fullpath'));addpath(root);
path=fullfile(root,'models',[c.name '.slx']);
if rebuild || ~isfile(path)
 wl_build(c);
elseif ~bdIsLoaded(c.name)
 load_system(path);
end
% A zero skew is an actual wire. Changing its sign changes which delay block
% exists, so rebuild that structure before applying a sweep's new parameters.
saved=getVariable(get_param(c.name,'ModelWorkspace'),'wl_saved_configuration');
if sign(saved.channelSkewS)~=sign(c.channelSkewS),wl_build(c);end
c=wl_setup(c); % Apply scenario AFTER loading the interactive default callback.
out=sim(c.name,'StopTime',num2str(c.duration,17));
end
