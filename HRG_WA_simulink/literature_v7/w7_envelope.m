function name=w7_envelope(c,saveArtifacts)
% Separate fast PI/PIR research model. No switched-carrier equivalence claims.
assert(strcmp(c.v7.tdmMode,'continuous')&&strcmp(c.v7.actuationMode,'linear'), ...
 'Envelope harness cannot validate switched acquisition or nonlinear electrostatic RF force');
assert(~c.noiseEnable,'V7 envelope excludes carrier noise. Set noiseEnable=false or use w7_sim.');
if nargin<2,saveArtifacts=true;end
c=w7_setup(c);name=[c.name '_envelope'];r=fileparts(mfilename('fullpath'));
if bdIsLoaded(name),close_system(name,0);end
new_system(name);set_param(name,'Solver','ode4','SolverType','Fixed-step','FixedStep','wl_Tc', ...
 'StopTime','wl_stop','ReturnWorkspaceOutputs','on','SaveOutput','off','AlgebraicLoopMsg','error');
add_block('simulink/Continuous/Integrator',[name '/Mechanical_Envelope'],'InitialCondition','wl_env_z0','Position',[450 80 510 130]);
add_block('simulink/Continuous/Integrator',[name '/NCO_Offset'],'Position',[1100 550 1150 590]);
add_block('simulink/Sources/Clock',[name '/Clock'],'Position',[20 260 60 290]);
f('Scenario','wl_input(u,wl_c)',4,[110 250 300 300]);wire('Clock/1','Scenario/1');
add_block('simulink/Signal Routing/Demux',[name '/Inputs'],'Outputs','[1 1 1 1]','Position',[340 220 345 360]);wire('Scenario/1','Inputs/1');
add_block('simulink/Sources/Constant',[name '/Parameters'],'Value','wl_p','Position',[20 390 160 430]);
mux('Plant_Input',5,[230 50 235 190]);f('Averaged_Mechanics','wa_plant_rhs(u)',4,[280 70 400 130]);
wire('Mechanical_Envelope/1','Plant_Input/1');
wire('Inputs/1','Plant_Input/3');wire('Inputs/3','Plant_Input/4');wire('Parameters/1','Plant_Input/5');
wire('Plant_Input/1','Averaged_Mechanics/1');wire('Averaged_Mechanics/1','Mechanical_Envelope/1');
mux('Sense_Input',2,[560 60 565 150]);wire('Mechanical_Envelope/1','Sense_Input/1');wire('NCO_Offset/1','Sense_Input/2');
f('Nominal_AFE_ADC','wl_env_sense(u,wl_c)',4,[610 70 790 120]);wire('Sense_Input/1','Nominal_AFE_ADC/1');
% wl_env_sense includes actual RF path; the same frozen nominal inverse is used.
f('Calibrated_IQ','w7_iq(u,wl_c)',4,[830 70 1020 120]);wire('Nominal_AFE_ADC/1','Calibrated_IQ/1');
add_block('simulink/Discrete/Zero-Order Hold',[name '/Control_Sampling'],'SampleTime','wl_Tc','Position',[1080 70 1250 120]);wire('Calibrated_IQ/1','Control_Sampling/1');
add_block('simulink/Discrete/Discrete Filter',[name '/Finite_CIC_FIR'],'Numerator','conv(conv(wl_fir,[.5 .5]),[.5 .5])', ...
 'Denominator','1','SampleTime','wl_Tc','Position',[1310 70 1510 120]);wire('Control_Sampling/1','Finite_CIC_FIR/1');
add_block('simulink/Discrete/Delay',[name '/Pipeline'],'DelayLength','wl_c.pipelineCtrl+1','SampleTime','wl_Tc','InitialCondition','0','Position',[1560 70 1720 120]);wire('Finite_CIC_FIR/1','Pipeline/1');
f('Invariants','wl_invariants(u)',10,[1780 70 1920 120]);wire('Pipeline/1','Invariants/1');
mux('Control_Input',3,[700 350 705 520]);wire('Invariants/1','Control_Input/1');wire('Inputs/4','Control_Input/3');
add_block('simulink/Discrete/Unit Delay',[name '/State'],'SampleTime','wl_Tc','InitialCondition','zeros(17,1)','Position',[400 500 560 540]);
wire('State/1','Control_Input/2');
f('Measured_PI_PIR','w7_control_tick(u,wl_c)',33,[780 370 1020 430]);wire('Control_Input/1','Measured_PI_PIR/1');
add_block('simulink/Signal Routing/Demux',[name '/Control_Outputs'],'Outputs','[17 4 1 3 8]','Position',[1080 330 1085 510]);wire('Measured_PI_PIR/1','Control_Outputs/1');wire('Control_Outputs/1','State/1');
add_block('simulink/Math Operations/Gain',[name '/Hz_To_RadS'],'Gain','2*pi','Position',[930 550 1050 590]);wire('Control_Outputs/3','Hz_To_RadS/1');wire('Hz_To_RadS/1','NCO_Offset/1');
add_block('simulink/Discrete/Unit Delay',[name '/Command_Register'],'SampleTime','wl_Tc','InitialCondition','zeros(4,1)','Position',[400 360 560 400]);wire('Control_Outputs/2','Command_Register/1');
mux('Drive_Input',2,[250 450 255 540]);wire('Command_Register/1','Drive_Input/1');wire('NCO_Offset/1','Drive_Input/2');
f('Drive_Equivalent','wl_env_drive(u,wl_c)',4,[50 80 190 140]);wire('Drive_Input/1','Drive_Equivalent/1');wire('Drive_Equivalent/1','Plant_Input/2');
tap('Mechanical_Envelope/1','envelope',4);tap('Pipeline/1','iq',4);tap('Control_Outputs/4','control_commands',3);tap('Control_Outputs/5','v7_controller',8);
ann=Simulink.Annotation(name,'V7 averaged PI/PIR harness: no RF quantization, alias, TDM, SINAD or zero-state carrier signoff. Filter approximates low-frequency delay only.');ann.Position=[20 850 1700 910];
assignin(get_param(name,'ModelWorkspace'),'v7_saved_configuration',rmfield(c,'legacyP'));
set_param(name,'PostLoadFcn',sprintf('addpath(fileparts(fileparts(get_param(''%s'',''FileName'')))); w7_setup(getVariable(get_param(''%s'',''ModelWorkspace''),''v7_saved_configuration''));',name,name));
if saveArtifacts
 folder=fullfile(r,'models');if ~isfolder(folder),mkdir(folder);end
 save_system(name,fullfile(folder,[name '.slx']));print(['-s' name],'-dpng','-r100',fullfile(folder,[name '.png']));
end
 function f(n,ex,dim,pos),add_block('built-in/MATLABFcn',[name '/' n],'MATLABFcn',ex,'OutputDimensions',num2str(dim),'Position',pos);end
 function mux(n,N,pos),add_block('simulink/Signal Routing/Mux',[name '/' n],'Inputs',num2str(N),'Position',pos);end
 function wire(a,b),add_line(name,a,b,'autorouting','on');end
 function tap(src,label,N)
  x=80+numel(find_system(name,'SearchDepth',1,'BlockType','ToWorkspace'))*440;n=['tap_' label];
  add_block('simulink/Sinks/To Workspace',[name '/' n],'VariableName',n,'SaveFormat','Timeseries','Position',[x 700 x+180 740]);wire(src,[n '/1']);
  add_block('simulink/Sinks/Scope',[name '/Scope_' label],'Position',[x+220 700 x+280 740]);wire(src,['Scope_' label '/1']);
  assert(N>0);
 end
end
