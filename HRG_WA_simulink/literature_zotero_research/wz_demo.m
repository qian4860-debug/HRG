function [out,c]=wz_demo()
% Desktop replay. The synthetic calibration is not a measured head profile.
r=fileparts(mfilename('fullpath'));addpath(r,fullfile(fileparts(r),'literature_v8_research'));
name='hrg_wa_wz_calibrated';load_system(fullfile(r,'models',[name '.slx']));
c=getVariable(get_param(name,'ModelWorkspace'),'v8_saved_configuration');c=wz_setup(c);
fprintf('Synthetic fixture replay; direct angle has no online/FRP/temperature correction.\n');
open_system(name);scopes=find_system(name,'BlockType','Scope');
for k=1:numel(scopes),open_system(scopes{k});end
for label={'adc','iq','driver'}
 blocks=find_system(name,'LookUnderMasks','all','Name',['Spectrum_' label{1}]);
 for j=1:numel(blocks),set_param(blocks{j},'OpenAtSimulationStart','on');end
end
out=sim(name);wl_view_results(out,c);
% No close_system/close all: desktop waveforms remain open after simulation.
end
