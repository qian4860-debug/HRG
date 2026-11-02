function [out,report]=sn_demo()
root=sn_setup;mdl='hrg_wa_noise_research';load_system(fullfile(root,'models',[mdl '.slx']));p=evalin(get_param(mdl,'ModelWorkspace'),'p');open_system(mdl);open_system([mdl '/Quality_Monitor']);out=sim(mdl);report=sn_report(out,p,true,'interactive');
end
