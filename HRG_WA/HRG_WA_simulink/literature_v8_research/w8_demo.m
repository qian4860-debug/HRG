function [out,c]=w8_demo()
% Replay the delivered SYNTHETIC-FIXTURE scenario; never silently calibrate a head.
r=fileparts(mfilename('fullpath'));w8_config();name='hrg_wa_v8_calibrated';
load_system(fullfile(r,'models',[name '.slx']));
c=getVariable(get_param(name,'ModelWorkspace'),'v8_saved_configuration');c=w8_setup(c);
fprintf('Research replay: synthetic fixture constants, not measured hardware calibration.\n');
open_system(name);scopes=find_system(name,'BlockType','Scope');
for k=1:numel(scopes),open_system(scopes{k});end
for label={'adc','iq','driver'}
 blocks=find_system(name,'LookUnderMasks','all','Name',['Spectrum_' label{1}]);
 for j=1:numel(blocks),set_param(blocks{j},'OpenAtSimulationStart','on');end
end
out=sim(name);wl_view_results(out,c);
end
