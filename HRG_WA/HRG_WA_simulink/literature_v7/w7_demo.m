function [out,c]=w7_demo(scenario)
% Desktop replay keeps ordinary Figures alive after the simulation stops.
if nargin<1,scenario='continuous';end
opt=struct;
switch lower(scenario)
 case 'continuous'
 case 'pir',opt.controlMode='PIR';
 case 'switched',opt.tdmMode='switched';
 case 'tia',opt.readoutMode='tia';
 case 'electrostatic',opt.actuationMode='electrostatic';
 case 'startup'
 otherwise,error('Unknown scenario. Use continuous/pir/switched/tia/electrostatic/startup');
end
c=w7_config([],opt);c.name=['hrg_wa_v7_demo_' lower(scenario)];
if strcmpi(scenario,'startup')
 c.head.initialEnergy=0;c.head.initialQuadRatio=0;c.inputRate=0;
 c.head.splitHz=0;c.head.dgamma=0;c.head.duffingHz=0;c.head.detect=eye(2);c.head.drive=eye(2);
end
name=w7_build(c,false);open_system(name);
if usejava('desktop')
 for label={'iq','adc','driver','v7_timing','v7_acquisition'}
  blocks=find_system(name,'LookUnderMasks','all','Name',['Scope_' label{1}]);
  for j=1:numel(blocks),set_param(blocks{j},'OpenAtSimulationStart','on');end
 end
end
c=w7_setup(c);out=sim(name);fig=wl_view_results(out,c);set(fig,'Name',['HRG WA V7 - ' scenario]);
assignin('base','out_v7',out);assignin('base','v7_configuration',c);
end
