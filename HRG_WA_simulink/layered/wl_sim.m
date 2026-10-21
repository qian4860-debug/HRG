function [out,c]=wl_sim(c,rebuild)
if nargin<2,rebuild=false;end
root=fileparts(mfilename('fullpath'));addpath(root);
path=fullfile(root,'models',[c.name '.slx']);
if rebuild || ~isfile(path)
 wl_build(c);
elseif ~bdIsLoaded(c.name)
 load_system(path);
end
c=wl_setup(c); % Apply scenario AFTER loading the interactive default callback.
out=sim(c.name,'StopTime',num2str(c.duration,17));
end
