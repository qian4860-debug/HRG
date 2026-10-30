function out=p101_demo_low_rate(p)
% Ideal-envelope research demo; changing this workspace does not save the SLX.
root=fileparts(mfilename('fullpath'));addpath(root);
if nargin<1,p=p101_envelope_config;end
mdl='hrg_wa_v10_1_low_rate';path=fullfile(root,'models',[mdl '.slx']);
if ~exist(path,'file'),p101_build_low_rate(p);else,load_system(path);end
mw=get_param(mdl,'ModelWorkspace');assignin(mw,'p',p);
open_system(mdl);open_system([mdl '/Scope_IQ_Cp_Voltage']);
out=sim(mdl,'StopTime',num2str(p.envDuration));
end
