function name=w7_build(c,saveArtifacts)
% Extend a fresh in-memory library model; never load/overwrite accepted SLX files.
if nargin<1,c=w7_config();end
if nargin<2,saveArtifacts=true;end
c=w7_setup(c);name=wl_build(c,false);r=fileparts(mfilename('fullpath'));
annotations=find_system(name,'FindAll','on','Type','annotation');
for h=annotations(:)',delete(get_param(h,'Object'));end
% Public controller interface remains envelope4, NCO Hz, commands3.
s=[name '/Discrete_PI_AntiWindup'];
set_param([s '/Controller_State'],'InitialCondition','zeros(17,1)');
delete_line(s,'Head_Parameters/1','Tick_Input/4');delete_block([s '/Head_Parameters']);
set_param([s '/Tick_Input'],'Inputs','3');
set_param([s '/Legacy_PI_Slew_Adapter'],'MATLABFcn','w7_control_tick(u,wl_c)','OutputDimensions','33');
set_param([s '/Tick_Outputs'],'Outputs','[17 4 1 3 8]');
tap(s,'Tick_Outputs/5','v7_controller');
s=[name '/NCO_IQ_CIC_FIR'];
set_param([s '/Mixer_Input'],'Inputs','3');
add_block('simulink/Sources/Clock',[s '/Measured_Clock'],'Position',[20 310 60 340]);
add_line(s,'Measured_Clock/1','Mixer_Input/3','autorouting','on');
set_param([s '/IQ_Mixer'],'MATLABFcn','w7_mix(u,wl_c)');
set_param([s '/IQ_Fixed_Format'],'MATLABFcn','w7_iq(u,wl_c)');
% Actual nonlinear electrode force is optional and is inside the feedback.
s=[name '/DAC_Driver_Force'];
delete_line(s,'Driver_Rails/1','Voltage_To_Force_Acceleration/1');
delete_line(s,'Voltage_To_Force_Acceleration/1','Out1/1');
delete_line(s,'Voltage_To_Force_Acceleration/1','tap_force/1');
if c.observers,delete_line(s,'Voltage_To_Force_Acceleration/1','Scope_force/1');end
if c.spectra,delete_line(s,'Voltage_To_Force_Acceleration/1','Spectrum_Sample_force/1');end
delete_block([s '/Voltage_To_Force_Acceleration']);
add_block('simulink/Signal Routing/Mux',[s '/Voltage_And_Displacement'],'Inputs','2','Position',[2000 90 2005 220]);
add_block('simulink/Signal Routing/From',[s '/Physical_Displacement'],'GotoTag','v7_displacement','Position',[1780 200 1940 240]);
add_line(s,'Physical_Displacement/1','Voltage_And_Displacement/2','autorouting','on');
add_block('built-in/MATLABFcn',[s '/Voltage_To_Force_Acceleration'], ...
 'MATLABFcn','w7_force(u,wl_c)','OutputDimensions','2','Position',[2060 80 2260 130]);
add_line(s,'Voltage_And_Displacement/1','Voltage_To_Force_Acceleration/1','autorouting','on');
add_line(s,'Voltage_To_Force_Acceleration/1','Out1/1','autorouting','on');
add_line(s,'Voltage_To_Force_Acceleration/1','tap_force/1','autorouting','on');
if c.observers,add_line(s,'Voltage_To_Force_Acceleration/1','Scope_force/1','autorouting','on');end
if c.spectra,add_line(s,'Voltage_To_Force_Acceleration/1','Spectrum_Sample_force/1','autorouting','on');end
add_block('simulink/Signal Routing/Goto',[name '/Mechanical_Head/V7_Displacement'], ...
 'GotoTag','v7_displacement','TagVisibility','global','Position',[850 100 1000 140]);
add_line([name '/Mechanical_Head'],'Displacement/1','V7_Displacement/1','autorouting','on');
if strcmp(c.v7.tdmMode,'switched'),switched();else
 add_line(s,'Driver_Rails/1','Voltage_And_Displacement/1','autorouting','on');
end
tap([name '/Capacitive_CV_PGA_AA'],'PGA_Finite_Bandwidth/1','accept_afe_request');
tap([name '/DAC_Driver_Force'],'Driver_Slew/1','accept_driver_request');
tap([name '/NCO'],'Phase/1','accept_nco_phase');
set_param([name '/Discrete_PI_AntiWindup/Legacy_PI_Slew_Adapter'],'Name','Measured_PI_PIR_Startup');
set_param([name '/Discrete_PI_AntiWindup'],'Name','PI_PIR_Startup');
ann=Simulink.Annotation(name,sprintf(['V7 LITERATURE-BASED RESEARCH BRANCH\n' ...
 'Measured-IQ PI/PIR; bounded startup; fixed nominal complex calibrations.\n' ...
 'Optional D/unload/read/unload switching and exact finite-window IQ Gram matrix.\n' ...
 'All physical scales remain assumptions. Inspect V7 derivation and scoreboards.']));
ann.Position=[20 1200 1250 1320];
% Keep observation blocks clear of the added switched acquisition circuit.
if strcmp(c.v7.tdmMode,'switched')
 parent=[name '/ADC_Clock_Conversion'];logs=find_system(parent,'SearchDepth',1,'BlockType','ToWorkspace');
 for j=1:numel(logs)
  label=erase(get_param(logs{j},'Name'),'tap_');x=50+(j-1)*540;
  set_param(logs{j},'Position',[x 1350 x+190 1390]);
  relocate(['Scope_' label],[x+220 1350 x+290 1390]);
  relocate(['Spectrum_Sample_' label],[x 1450 x+130 1490]);
  relocate(['Spectrum_Channel_' label],[x+170 1450 x+240 1490]);
  relocate(['Spectrum_' label],[x+300 1450 x+500 1500]);
 end
end
assignin(get_param(name,'ModelWorkspace'),'v7_saved_configuration',rmfield(c,'legacyP'));
set_param(name,'PostLoadFcn',sprintf('addpath(fileparts(fileparts(get_param(''%s'',''FileName'')))); w7_setup(getVariable(get_param(''%s'',''ModelWorkspace''),''v7_saved_configuration''));',name,name));
if saveArtifacts
 folder=fullfile(r,'models');if ~isfolder(folder),mkdir(folder);end
 save_system(name,fullfile(folder,[name '.slx']));
 print(['-s' name],'-dpng','-r100',fullfile(folder,[name '.png']));
end
 function tap(parent,source,label)
  serial=numel(find_system(parent,'SearchDepth',1,'BlockType','ToWorkspace'));
  pos=[50+mod(serial,3)*520 700+floor(serial/3)*200];
  n=['tap_' label];add_block('simulink/Sinks/To Workspace',[parent '/' n], ...
   'VariableName',n,'SaveFormat','Timeseries','MaxDataPoints',num2str(c.maxLogPoints),'Position',[pos pos+[190 40]]);
  add_line(parent,source,[n '/1'],'autorouting','on');
  if c.observers&&startsWith(label,'v7_')
   n=['Scope_' label];add_block('simulink/Sinks/Scope',[parent '/' n],'Position',[pos+[220 0] pos+[290 40]]);
   add_line(parent,source,[n '/1'],'autorouting','on');
  end
  if c.spectra&&ismember(label,{'v7_acquisition','v7_electrode_voltage'})
   sample=['Spectrum_Sample_' label];select=['Spectrum_Channel_' label];n=['Spectrum_' label];
   add_block('simulink/Discrete/Zero-Order Hold',[parent '/' sample],'SampleTime','wl_Tp','Position',[pos+[0 80] pos+[130 120]]);
   add_block('simulink/Signal Routing/Selector',[parent '/' select],'NumberOfDimensions','1', ...
    'IndexOptionArray',{'Index vector (dialog)'},'IndexParamArray',{'1'},'InputPortWidth','2','Position',[pos+[170 80] pos+[240 120]]);
   add_block(sprintf('dspsnks4/Spectrum\nAnalyzer'),[parent '/' n], ...
    'SampleRateSource','Property','SampleRate',num2str(c.fsPlant),'OpenAtSimulationStart','off', ...
    'SpectrumType','Power','SpectrumUnits','dBV','Title',[label ' voltage power spectrum'], ...
    'Position',[pos+[300 80] pos+[500 130]]);
   add_line(parent,source,[sample '/1'],'autorouting','on');add_line(parent,[sample '/1'],[select '/1'],'autorouting','on');
   add_line(parent,[select '/1'],[n '/1'],'autorouting','on');
  end
 end
 function switched()
  % One deterministic plant-clock timing source, observable at native rate.
  add_block('simulink/Sources/Digital Clock',[name '/V7_TDM_Clock'],'SampleTime','wl_Tp','Position',[20 1080 80 1110]);
  add_block('built-in/MATLABFcn',[name '/V7_Switch_Timing'],'MATLABFcn','w7_switches(u,wl_c)', ...
   'OutputDimensions','4','Position',[120 1080 320 1130]);
  add_line(name,'V7_TDM_Clock/1','V7_Switch_Timing/1','autorouting','on');
  add_block('simulink/Signal Routing/Goto',[name '/V7_Timing'],'GotoTag','v7_timing','TagVisibility','global','Position',[360 1080 500 1120]);
  add_line(name,'V7_Switch_Timing/1','V7_Timing/1','autorouting','on');tap(name,'V7_Switch_Timing/1','v7_timing');
  s=[name '/DAC_Driver_Force'];
  add_block('simulink/Signal Routing/From',[s '/Timing'],'GotoTag','v7_timing','Position',[20 440 130 480]);
  add_block('simulink/Signal Routing/Demux',[s '/Gates'],'Outputs','4','Position',[160 400 165 550]);
  add_line(s,'Timing/1','Gates/1','autorouting','on');
  % Peak voltage increase is BEFORE the DAC quantizer/rails and is logged.
  delete_line(s,'Force_Envelope_To_Drive_V/1','DAC_Update_Hold/1');
  add_block('simulink/Math Operations/Product',[s '/Duty_Correct_Command'],'Position',[430 430 470 470]);
  add_block('simulink/Math Operations/Gain',[s '/Inverse_Drive_Duty'],'Gain','sum(wl_c.v7.slotCycles)/wl_c.v7.slotCycles(1)','Position',[520 430 710 470]);
  add_line(s,'Force_Envelope_To_Drive_V/1','Duty_Correct_Command/1','autorouting','on');
  add_line(s,'Gates/1','Duty_Correct_Command/2','autorouting','on');
  add_line(s,'Duty_Correct_Command/1','Inverse_Drive_Duty/1','autorouting','on');
  add_line(s,'Inverse_Drive_Duty/1','DAC_Update_Hold/1','autorouting','on');
  delete_line(s,'Force_Envelope_To_Drive_V/1','tap_dac_requested/1');
  add_line(s,'Inverse_Drive_Duty/1','tap_dac_requested/1','autorouting','on');
  % Physical electrode disconnect removes driver tails/noise during read/unload.
  add_block('simulink/Math Operations/Product',[s '/Electrode_Disconnect'],'Position',[2000 430 2040 470]);
  add_line(s,'Driver_Rails/1','Electrode_Disconnect/1','autorouting','on');add_line(s,'Gates/1','Electrode_Disconnect/2','autorouting','on');
  add_line(s,'Electrode_Disconnect/1','Voltage_And_Displacement/1','autorouting','on');
  delete_line(s,'Driver_Rails/1','Out2/1');add_line(s,'Electrode_Disconnect/1','Out2/1','autorouting','on');
  tap(s,'Electrode_Disconnect/1','v7_electrode_voltage');
  % Finite read acquisition, retained charge, unload relaxation, switch injection.
  s=[name '/ADC_Clock_Conversion'];
  add_block('simulink/Signal Routing/From',[s '/Timing'],'GotoTag','v7_timing','Position',[20 650 130 690]);
  add_block('simulink/Signal Routing/Demux',[s '/Gates'],'Outputs','4','Position',[170 620 175 790]);add_line(s,'Timing/1','Gates/1','autorouting','on');
  add_block('simulink/Discrete/Zero-Order Hold',[s '/Acquisition_Input'],'SampleTime','wl_Tp','Position',[250 620 400 660]);add_line(s,'In1/1','Acquisition_Input/1','autorouting','on');
  add_block('simulink/Discrete/Unit Delay',[s '/Stored_Charge'],'SampleTime','wl_Tp','InitialCondition','[0;0]','Position',[250 950 410 990]);
  add_block('simulink/Math Operations/Sum',[s '/Acquisition_Error'],'Inputs','+-','Position',[450 620 470 700]);
  add_line(s,'Acquisition_Input/1','Acquisition_Error/1','autorouting','on');add_line(s,'Stored_Charge/1','Acquisition_Error/2','autorouting','on');
  add_block('simulink/Math Operations/Gain',[s '/Read_RC'],'Gain','1-exp(-wl_Tp/wl_c.v7.acquisitionTauS)','Position',[520 620 720 660]);add_line(s,'Acquisition_Error/1','Read_RC/1','autorouting','on');
  add_block('simulink/Math Operations/Product',[s '/Read_Update'],'Position',[770 620 810 660]);add_line(s,'Read_RC/1','Read_Update/1','autorouting','on');add_line(s,'Gates/2','Read_Update/2','autorouting','on');
  add_block('simulink/Math Operations/Gain',[s '/Unload_RC'],'Gain','exp(-wl_Tp/wl_c.v7.unloadTauS)-1','Position',[520 750 720 790]);add_line(s,'Stored_Charge/1','Unload_RC/1','autorouting','on');
  add_block('simulink/Math Operations/Product',[s '/Unload_Update'],'Position',[770 750 810 790]);add_line(s,'Unload_RC/1','Unload_Update/1','autorouting','on');add_line(s,'Gates/3','Unload_Update/2','autorouting','on');
  add_block('simulink/Discrete/Unit Delay',[s '/Previous_Read_Gate'],'SampleTime','wl_Tp','InitialCondition','0','Position',[250 1100 420 1140]);add_line(s,'Gates/2','Previous_Read_Gate/1','autorouting','on');
  add_block('simulink/Math Operations/Sum',[s '/Switch_Edge'],'Inputs','+-','Position',[470 1060 490 1140]);add_line(s,'Gates/2','Switch_Edge/1','autorouting','on');add_line(s,'Previous_Read_Gate/1','Switch_Edge/2','autorouting','on');
  add_block('simulink/Math Operations/Gain',[s '/Charge_Injection'],'Gain','wl_c.v7.switchChargeC(:)/wl_c.v7.sampleCapF','Multiplication','Matrix(K*u)','Position',[540 1060 740 1100]);add_line(s,'Switch_Edge/1','Charge_Injection/1','autorouting','on');
  add_block('simulink/Math Operations/Sum',[s '/Acquired_Voltage'],'Inputs','++++','Position',[880 640 900 800]);
  add_line(s,'Stored_Charge/1','Acquired_Voltage/1','autorouting','on');add_line(s,'Read_Update/1','Acquired_Voltage/2','autorouting','on');add_line(s,'Unload_Update/1','Acquired_Voltage/3','autorouting','on');add_line(s,'Charge_Injection/1','Acquired_Voltage/4','autorouting','on');
  add_line(s,'Acquired_Voltage/1','Stored_Charge/1','autorouting','on');
  delete_line(s,'In1/1','Channels/1');add_line(s,'Acquired_Voltage/1','Channels/1','autorouting','on');
  tap(s,'Acquired_Voltage/1','v7_acquisition');
 end
 function relocate(n,pos)
  h=getSimulinkBlockHandle([parent '/' n]);if h~=-1,set_param(h,'Position',pos);end
 end
end
