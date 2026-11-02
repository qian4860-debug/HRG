function [out,report]=quality_demo(p)
% 运行独立观察模型，保留中文图表及文字面板。
root=quality_setup;if nargin<1,p=pcn_config;end;c=pcn_calibration;pcn_validate(p,c);
mdl='hrg_wa_quality_monitor';path=fullfile(root,'models',[mdl '.slx']);
if ~exist(path,'file'),quality_build;else,load_system(path);end
mw=get_param(mdl,'ModelWorkspace');assignin(mw,'p',p);assignin(mw,'c',c);[Ad,Bd,x0]=pcn_plant(p);
assignin(mw,'Ad',Ad);assignin(mw,'Bd',Bd);assignin(mw,'x0',x0);
open_system(mdl);open_system([mdl '/Quality_Monitor']);out=sim(mdl,'StopTime',num2str(p.duration));
report=quality_report(out,p,true);
end
