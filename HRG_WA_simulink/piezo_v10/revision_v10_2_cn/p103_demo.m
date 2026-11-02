function out=p103_demo(p)
root=p103_setup;if nargin<1,p=pcn_config;end;c=pcn_calibration;pcn_validate(p,c);
addpath(fullfile(root,'models'));mdl='hrg_wa_v10_2_cn_modular';
if ~exist(fullfile(root,'models',[mdl '.slx']),'file'),p103_build(p,c);else,load_system(fullfile(root,'models',[mdl '.slx']));end
mw=get_param(mdl,'ModelWorkspace');assignin(mw,'p',p);assignin(mw,'c',c);[Ad,Bd,x0]=pcn_plant(p);
assignin(mw,'Ad',Ad);assignin(mw,'Bd',Bd);assignin(mw,'x0',x0);
open_system(mdl);open_system([mdl '/Piezo_Head_and_Circuits']);open_system([mdl '/Instrumentation/Scope_IQ']);
out=sim(mdl,'StopTime',num2str(p.duration));
end
