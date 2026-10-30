function out=p101_demo(p,c,plant_p)
% Open persistent observers; simulation completion does not close the windows.
root=fileparts(mfilename('fullpath'));addpath(root);
if nargin<1,p=p101_config;end;if nargin<2,c=p101_calibration;end;if nargin<3,plant_p=p;end;mdl='hrg_wa_v10_1_piezo';
p101_validate(p,c);p101_validate(plant_p);
path=fullfile(root,'models',[mdl '.slx']);
if ~exist(path,'file'),p101_build(p,c,plant_p);else,load_system(path);end
mw=get_param(mdl,'ModelWorkspace');assignin(mw,'p',p);assignin(mw,'c',c);assignin(mw,'plant_p',plant_p);
[Ad,Bd,x0]=p101_plant(plant_p);assignin(mw,'Ad',Ad);assignin(mw,'Bd',Bd);assignin(mw,'x0',x0);
open_system(mdl);open_system([mdl '/Scope_diagnostics']);open_system([mdl '/Scope_Driver_V']);
out=sim(mdl,'StopTime',num2str(p.duration));
% Deliberately leave model/Scope tabs open. No save over accepted SLX.
end
