function [out,report]=comp_demo()
% 打开已保存的基线补偿模型；演示不修改原模型或辨识参数。
root=comp_setup;path=fullfile(root,'models','hrg_wa_compensation_research.slx');load_system(path);mdl='hrg_wa_compensation_research';
p=evalin(get_param(mdl,'ModelWorkspace'),'p');open_system(mdl);open_system([mdl '/Quality_Monitor']);out=sim(mdl);
report=comp_report(out,p,true,'interactive');
end
