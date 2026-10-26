function out=w9_demo(kind)
% Desktop replay only. Scopes remain open. No synthetic hardware signoff.
if nargin<1,kind='rf';end
r=fileparts(mfilename('fullpath'));w9_setup();
switch kind
 case 'rf',name='hrg_wa_v9_frozen_calibration';
 case 'identification',name='hrg_wa_v9_identification';
 case 'bias',name='hrg_wa_v9_bias_reference';
 otherwise,error('Choose rf, identification, or bias');
end
load_system(fullfile(r,'models',[name '.slx']));open_system(name);
scopes=find_system(name,'BlockType','Scope');for k=1:numel(scopes),open_system(scopes{k});end
if strcmp(kind,'rf')
 for label={'adc','iq','driver'}
  b=find_system(name,'LookUnderMasks','all','Name',['Spectrum_' label{1}]);
  for j=1:numel(b),set_param(b{j},'OpenAtSimulationStart','on');end
 end
end
out=sim(name);
end
