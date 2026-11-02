function out=p102_demo(p)
root=p102_setup;if nargin<1,p=p101_config;end;c=p101_calibration;p101_validate(p,c);
addpath(fullfile(root,'models'));mdl='hrg_wa_v10_2_modular';
if ~exist(fullfile(root,'models',[mdl '.slx']),'file'),p102_build(p,c);else,load_system(fullfile(root,'models',[mdl '.slx']));end
mw=get_param(mdl,'ModelWorkspace');assignin(mw,'p',p);assignin(mw,'c',c);[Ad,Bd,x0]=p101_plant(p);
assignin(mw,'Ad',Ad);assignin(mw,'Bd',Bd);assignin(mw,'x0',x0);
open_system(mdl);open_system([mdl '/Piezo_Head_and_Circuits']);open_system([mdl '/Instrumentation/Scope_IQ']);
out=sim(mdl,'StopTime',num2str(p.duration));
end
