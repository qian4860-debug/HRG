function report=w9_check_delivery()
r=fileparts(mfilename('fullpath'));w9_setup();
names={'hrg_wa_v9_identification','hrg_wa_v9_bias_reference','hrg_wa_v9_frozen_calibration'};
models=struct('name',{},'reopenedCompiled',{},'scopes',{});
for k=1:numel(names)
 name=names{k};evalin('base','clear wl_c');load_system(fullfile(r,'models',[name '.slx']));
 feval(name,[],[],[],'compile');count=numel(find_system(name,'BlockType','Scope'));
 feval(name,[],[],[],'term');close_system(name,0);
 models(end+1)=struct('name',name,'reopenedCompiled',true,'scopes',count);
end
entry=checkcode(fullfile(r,'w9_demo.m'),'-id');assert(~any(strcmp({entry.id},'SYNER')));
report=struct('date','2026-10-26','models',models,'MATLAB',ver('MATLAB'), ...
 'Simulink',ver('Simulink'),'DSP',ver('dsp'),'platform',computer,'pass',true);
wl_write_json(fullfile(r,'evidence','delivery.json'),report);
end
