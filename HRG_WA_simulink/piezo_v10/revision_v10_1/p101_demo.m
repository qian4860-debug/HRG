function out=p101_demo(p)
% Open persistent observers; simulation completion does not close the windows.
root=fileparts(mfilename('fullpath'));addpath(root);
if nargin<1,p=p101_config;end;c=p101_calibration;mdl='hrg_wa_v10_1_piezo';
path=fullfile(root,'models',[mdl '.slx']);
if ~exist(path,'file'),p101_build(p,c);else,load_system(path);end
mw=get_param(mdl,'ModelWorkspace');assignin(mw,'p',p);assignin(mw,'c',c);
[Ad,Bd,x0]=p101_plant(p);assignin(mw,'Ad',Ad);assignin(mw,'Bd',Bd);assignin(mw,'x0',x0);
open_system(mdl);open_system([mdl '/Scope_diagnostics']);open_system([mdl '/Scope_Driver_V']);
out=sim(mdl,'StopTime',num2str(p.duration));
% Deliberately leave model/Scope tabs open. No save over accepted SLX.
end
