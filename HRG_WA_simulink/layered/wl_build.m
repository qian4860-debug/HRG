function name=wl_build(c)
% Progressive carrier closed-loop models assembled from MATLAB library blocks.
if nargin<1,c=wl_config(5);end
root=fileparts(mfilename('fullpath'));addpath(root);c=wl_setup(c);name=c.name;
work=fullfile(root,'_work');if ~isfolder(work),mkdir(work);end
Simulink.fileGenControl('set','CacheFolder',fullfile(work,'cache'),'CodeGenFolder',fullfile(work,'codegen'),'createDir',true);
load_system('simulink');load_system('dspsnks4');
if bdIsLoaded(name),close_system(name,0);end
new_system(name);
set_param(name,'Solver','ode4','SolverType','Fixed-step','FixedStep','wl_Tp', ...
 'StopTime','wl_stop','ReturnWorkspaceOutputs','on','SaveOutput','off', ...
 'AlgebraicLoopMsg','error','SignalInfNanChecking','error');
ss(name,'Environment',0,1,[20 70 150 140]);s=[name '/Environment'];
blk(s,'simulink/Sources/Clock','Time',[30 50 60 70]);mf(s,'Scenario','wl_input(u,wl_c)',4,[110 40 240 90]);wire(s,'Time/1','Scenario/1');wire(s,'Scenario/1','Out1/1');
blk(name,'simulink/Signal Routing/Demux','Scenario','Outputs','[2 1 1]','Position',[180 60 185 170]);wire(name,'Environment/1','Scenario/1');
ss(name,'Mechanical_Head',3,2,[270 60 450 165]);mechanical([name '/Mechanical_Head']);
ss(name,'Capacitive_CV_PGA_AA',2,1,[530 60 750 165]);frontend([name '/Capacitive_CV_PGA_AA']);
ss(name,'ADC_Clock_Conversion',2,2,[830 60 1040 165]);adc([name '/ADC_Clock_Conversion']);
ss(name,'NCO_IQ_CIC_FIR',2,1,[1110 60 1320 165]);digital([name '/NCO_IQ_CIC_FIR']);
ss(name,'Algorithms_Kalman_RLS_FRP',6,3,[1110 300 1360 440]);algorithms([name '/Algorithms_Kalman_RLS_FRP']);
ss(name,'Discrete_PI_AntiWindup',2,3,[760 300 1000 440]);controller([name '/Discrete_PI_AntiWindup']);
ss(name,'NCO',1,1,[480 330 640 410]);nco([name '/NCO']);
ss(name,'DAC_Driver_Force',2,3,[270 300 450 440]);driver([name '/DAC_Driver_Force']);
wire(name,'Scenario/1','Mechanical_Head/2');wire(name,'Scenario/2','Mechanical_Head/3');
wire(name,'DAC_Driver_Force/1','Mechanical_Head/1');wire(name,'Mechanical_Head/1','Capacitive_CV_PGA_AA/1');
wire(name,'DAC_Driver_Force/2','Capacitive_CV_PGA_AA/2');wire(name,'Capacitive_CV_PGA_AA/1','ADC_Clock_Conversion/1');
wire(name,'Mechanical_Head/2','ADC_Clock_Conversion/2');wire(name,'ADC_Clock_Conversion/1','NCO_IQ_CIC_FIR/1');
wire(name,'NCO/1','NCO_IQ_CIC_FIR/2');wire(name,'NCO_IQ_CIC_FIR/1','Algorithms_Kalman_RLS_FRP/1');
blk(name,'simulink/Discrete/Zero-Order Hold','Temperature_Sampling','SampleTime','wl_Tc','Position',[1410 190 1560 230]);
blk(name,'simulink/Discrete/Zero-Order Hold','Virtual_Command_Sampling','SampleTime','wl_Tc','Position',[1400 250 1560 290]);
wire(name,'Scenario/2','Temperature_Sampling/1');wire(name,'Scenario/3','Virtual_Command_Sampling/1');
wire(name,'Temperature_Sampling/1','Algorithms_Kalman_RLS_FRP/2');wire(name,'Virtual_Command_Sampling/1','Algorithms_Kalman_RLS_FRP/3');
blk(name,'simulink/Sources/Constant','Calibration_Fixture_Permit','Value','double(wl_c.calibrationPermit && wl_c.zeroRateCertified)','Position',[1090 490 1270 520]);
wire(name,'Calibration_Fixture_Permit/1','Algorithms_Kalman_RLS_FRP/4');
blk(name,'simulink/Discrete/Unit Delay','Public_Previous_Command','SampleTime','wl_Tc','InitialCondition','zeros(3,1)','Position',[820 490 1010 530]);
wire(name,'Discrete_PI_AntiWindup/3','Public_Previous_Command/1');wire(name,'Public_Previous_Command/1','Algorithms_Kalman_RLS_FRP/5');
wire(name,'Algorithms_Kalman_RLS_FRP/1','Discrete_PI_AntiWindup/1');wire(name,'Virtual_Command_Sampling/1','Discrete_PI_AntiWindup/2');
blk(name,'simulink/Discrete/Unit Delay','Control_Clock_Register','SampleTime','wl_Tc','InitialCondition','zeros(4,1)','Position',[490 230 670 270]);
wire(name,'Discrete_PI_AntiWindup/2','NCO/1');wire(name,'Discrete_PI_AntiWindup/1','Control_Clock_Register/1');
wire(name,'Control_Clock_Register/1','DAC_Driver_Force/1');wire(name,'NCO/1','DAC_Driver_Force/2');
wire(name,'ADC_Clock_Conversion/2','Algorithms_Kalman_RLS_FRP/6');
observe(name,'Mechanical_Head/1','head_displacement',c.fsPlant,'normalized displacement');
observe(name,'Mechanical_Head/2','head_velocity',c.fsPlant,'normalized displacement/s');
observe(name,'Algorithms_Kalman_RLS_FRP/2','navigation',1/c.head.Ts,'rad and rad/s');
observe(name,'Algorithms_Kalman_RLS_FRP/3','algorithm_diagnostics',1/c.head.Ts,'mixed diagnostic units');
observe(name,'Discrete_PI_AntiWindup/3','control_commands',1/c.head.Ts,'1/s and Hz');
annotation=Simulink.Annotation(name,sprintf(['V%d: LIBRARY-BASED WHOLE-ANGLE HRG MIXED-SIGNAL CLOSED LOOP\n' ...
 'Double-click subsystems: each signal stage has Scope, Spectrum Analyzer and logging.\n' ...
 'Mechanical truth goes only to observers; controllers consume sampled I/Q.\n' ...
 'All circuit scales are assumed. Run wl_setup(wl_config(%d)) before parameter sweeps.'],c.stage,c.stage));
annotation.Position=[20 560 1150 650];
set_param(name,'Location',[20 40 1470 850]);
% Keep each delivered test/architecture model's exact clock and scenario.
set_param(name,'UserData',rmfield(c,'legacyP'),'UserDataPersistent','on');
set_param(name,'PostLoadFcn',sprintf('addpath(fileparts(fileparts(get_param(''%s'',''FileName'')))); wl_setup(get_param(''%s'',''UserData''));',name,name));
folder=fullfile(root,'models');if ~isfolder(folder),mkdir(folder);end
save_system(name,fullfile(folder,[name '.slx']));
print(['-s' name],'-dpng','-r120',fullfile(folder,[name '.png']));
fprintf('Built %s with library scopes and spectrum analyzers.\n',name);
end

function mechanical(s)
blk(s,'simulink/Continuous/Integrator','Velocity','InitialCondition','wl_v0','Position',[590 80 630 120]);
blk(s,'simulink/Continuous/Integrator','Displacement','InitialCondition','wl_q0','Position',[700 80 740 120]);
blk(s,'simulink/Math Operations/Sum','Force_Sum','Inputs','+++++','Position',[500 70 520 190]);
gain(s,'Damping','-wl_D',[260 200 360 240]);gain(s,'Stiffness','-wl_K',[260 260 360 300]);
gain(s,'Coriolis_Jv','-4*wl_c.head.bryan*wl_J',[260 330 400 370]);
gain(s,'Euler_Jq','-2*wl_c.head.bryan*wl_J',[260 400 400 440]);
blk(s,'simulink/Signal Routing/Demux','Rates','Outputs','2','Position',[90 330 95 410]);
blk(s,'simulink/Math Operations/Product','Coriolis','Inputs','2','Position',[430 320 460 350]);
blk(s,'simulink/Math Operations/Product','Euler','Inputs','2','Position',[430 400 460 430]);
wire(s,'In1/1','Force_Sum/1');wire(s,'Velocity/1','Damping/1');wire(s,'Damping/1','Force_Sum/2');
wire(s,'Displacement/1','Stiffness/1');wire(s,'Stiffness/1','Force_Sum/3');
wire(s,'Velocity/1','Coriolis_Jv/1');wire(s,'Displacement/1','Euler_Jq/1');
wire(s,'In2/1','Rates/1');wire(s,'Coriolis_Jv/1','Coriolis/1');wire(s,'Rates/1','Coriolis/2');
wire(s,'Euler_Jq/1','Euler/1');wire(s,'Rates/2','Euler/2');
wire(s,'Coriolis/1','Force_Sum/4');wire(s,'Euler/1','Force_Sum/5');
% Thermal force and varying stiffness are actual plant perturbations.
blk(s,'simulink/Sources/Random Number','Brownian_Force','Mean','[0;0]','Variance','wl_brownVariance*[1;1]', ...
 'Seed','[wl_c.seed+501;wl_c.seed+502]','SampleTime','wl_Tp','Position',[230 500 360 540]);
blk(s,'simulink/Math Operations/Sum','All_Forces','Inputs','++++','Position',[550 90 570 180]);
blk(s,'simulink/Math Operations/Dot Product','Q_Norm_Squared','Position',[700 480 760 520]);
blk(s,'simulink/Math Operations/Dot Product','V_Norm_Squared','Position',[700 560 760 600]);
wire(s,'Displacement/1','Q_Norm_Squared/1');wire(s,'Displacement/1','Q_Norm_Squared/2');
wire(s,'Velocity/1','V_Norm_Squared/1');wire(s,'Velocity/1','V_Norm_Squared/2');
gain(s,'Velocity_Energy_Scale','1/(2*pi*wl_c.head.f0)^2',[820 560 960 600]);wire(s,'V_Norm_Squared/1','Velocity_Energy_Scale/1');
blk(s,'simulink/Math Operations/Sum','Modal_Energy_Estimate','Inputs','++','Position',[1000 490 1020 570]);
wire(s,'Q_Norm_Squared/1','Modal_Energy_Estimate/1');wire(s,'Velocity_Energy_Scale/1','Modal_Energy_Estimate/2');
gain(s,'Energy_Frequency_Coefficient','-2*(2*pi*wl_c.head.f0)*(2*pi*wl_c.head.duffingHz)',[1080 500 1300 550]);wire(s,'Modal_Energy_Estimate/1','Energy_Frequency_Coefficient/1');
blk(s,'simulink/Math Operations/Product','Energy_Dependent_Stiffness','Inputs','2','Position',[1380 490 1420 540]);
wire(s,'Energy_Frequency_Coefficient/1','Energy_Dependent_Stiffness/1');wire(s,'Displacement/1','Energy_Dependent_Stiffness/2');wire(s,'Energy_Dependent_Stiffness/1','All_Forces/4');
if evalin('base','wl_c.temperatureRampCPerS')~=0
 mux(s,'Temperature_Input',2,[120 580 125 650]);mf(s,'Temperature_Stiffness','wl_temperature_force(u,wl_c)',2,[210 580 410 630]);
 wire(s,'Displacement/1','Temperature_Input/1');wire(s,'In3/1','Temperature_Input/2');wire(s,'Temperature_Input/1','Temperature_Stiffness/1');
else
 blk(s,'simulink/Sources/Constant','Temperature_Stiffness','Value','[0;0]','Position',[210 580 410 630]);
end
wire(s,'Force_Sum/1','All_Forces/1');wire(s,'Brownian_Force/1','All_Forces/2');wire(s,'Temperature_Stiffness/1','All_Forces/3');
wire(s,'All_Forces/1','Velocity/1');wire(s,'Velocity/1','Displacement/1');wire(s,'Displacement/1','Out1/1');wire(s,'Velocity/1','Out2/1');
end
function frontend(s)
gain(s,'Electrode_Assembly','wl_c.head.detect',[100 50 230 90]);wire(s,'In1/1','Electrode_Assembly/1');
mf(s,'Differential_Parallel_Plates','wl_capacitance(u,wl_c)',2,[280 40 470 100]);wire(s,'Electrode_Assembly/1','Differential_Parallel_Plates/1');
gain(s,'Capacitance_To_Voltage','wl_cvGain',[500 45 640 90]);wire(s,'Differential_Parallel_Plates/1','Capacitance_To_Voltage/1');
gain(s,'Parasitic_Drive_Feedthrough','wl_c.feedthroughF/wl_c.cfF',[280 160 480 200]);wire(s,'In2/1','Parasitic_Drive_Feedthrough/1');
blk(s,'simulink/Math Operations/Sum','Charge_Sum','Inputs','++','Position',[680 55 700 130]);
wire(s,'Capacitance_To_Voltage/1','Charge_Sum/1');wire(s,'Parasitic_Drive_Feedthrough/1','Charge_Sum/2');
if evalin('base','wl_c.stage')==2
 gain(s,'Feedback_Rf_Cf','1',[750 55 900 105]);
else
 blk(s,'simulink/Continuous/State-Space','Feedback_Rf_Cf','A','-eye(2)/wl_cvTau','B','eye(2)/wl_cvTau', ...
  'C','-eye(2)','D','eye(2)','Position',[750 55 900 105]);
end
wire(s,'Charge_Sum/1','Feedback_Rf_Cf/1');
noise(s,'CV_Noise','wl_cvNoiseVariance',601,[750 200 900 240]);
blk(s,'simulink/Math Operations/Sum','CV_Noisy','Inputs','++','Position',[950 65 970 125]);
wire(s,'Feedback_Rf_Cf/1','CV_Noisy/1');wire(s,'CV_Noise/1','CV_Noisy/2');
lowpass(s,'CV_Finite_Bandwidth','wl_c.cvBandwidthHz',[1020 60 1170 110]);wire(s,'CV_Noisy/1','CV_Finite_Bandwidth/1');
gain(s,'PGA','wl_c.pgaGain',[1020 260 1140 300]);wire(s,'CV_Finite_Bandwidth/1','PGA/1');
noise(s,'PGA_Noise','wl_pgaNoiseVariance',611,[1050 350 1190 390]);
blk(s,'simulink/Sources/Constant','Offset','Value','wl_c.afeOffsetV','Position',[1050 420 1190 460]);
blk(s,'simulink/Math Operations/Sum','PGA_Input','Inputs','+++','Position',[1230 270 1250 360]);
wire(s,'PGA/1','PGA_Input/1');wire(s,'PGA_Noise/1','PGA_Input/2');wire(s,'Offset/1','PGA_Input/3');
lowpass(s,'PGA_Finite_Bandwidth','wl_c.pgaBandwidthHz',[1300 280 1460 330]);wire(s,'PGA_Input/1','PGA_Finite_Bandwidth/1');
blk(s,'simulink/Discontinuities/Saturation','AFE_Rails','UpperLimit','wl_c.afeLimitV','LowerLimit','-wl_c.afeLimitV','Position',[1510 280 1640 330]);
wire(s,'PGA_Finite_Bandwidth/1','AFE_Rails/1');lowpass(s,'Anti_Alias','wl_c.antiAliasHz',[1690 280 1830 330]);wire(s,'AFE_Rails/1','Anti_Alias/1');wire(s,'Anti_Alias/1','Out1/1');
observe(s,'Capacitance_To_Voltage/1','cv_ideal',evalin('base','wl_c.fsPlant'),'V');
observe(s,'CV_Finite_Bandwidth/1','cv_actual',evalin('base','wl_c.fsPlant'),'V');
observe(s,'PGA_Finite_Bandwidth/1','pga',evalin('base','wl_c.fsPlant'),'V');
observe(s,'Anti_Alias/1','anti_alias',evalin('base','wl_c.fsPlant'),'V');
end
function adc(s)
% Signed channel skew: delay the appropriate channel, never use future samples.
blk(s,'simulink/Signal Routing/Demux','Channels','Outputs','2','Position',[70 50 75 140]);wire(s,'In1/1','Channels/1');
blk(s,'simulink/Continuous/Transport Delay','Skew_X','DelayTime','max(-wl_c.channelSkewS,0)','Position',[100 20 240 55]);
blk(s,'simulink/Continuous/Transport Delay','Skew_Y','DelayTime','max(wl_c.channelSkewS,0)','Position',[100 120 240 155]);
mux(s,'Skewed_Channels',2,[280 40 285 130]);wire(s,'Channels/1','Skew_X/1');wire(s,'Channels/2','Skew_Y/1');wire(s,'Skew_X/1','Skewed_Channels/1');wire(s,'Skew_Y/1','Skewed_Channels/2');
blk(s,'simulink/Discrete/Zero-Order Hold','Sample_Hold','SampleTime','wl_Ta','Position',[330 50 460 90]);wire(s,'Skewed_Channels/1','Sample_Hold/1');
% First-order aperture perturbation from clean mechanical velocity, separate
% from additive front-end noise; approximation is explicitly bounded in validate.
gain(s,'Velocity_To_Voltage_Derivative','wl_detectGain',[110 200 290 240]);wire(s,'In2/1','Velocity_To_Voltage_Derivative/1');
blk(s,'simulink/Discrete/Zero-Order Hold','Derivative_Sample','SampleTime','wl_Ta','Position',[330 200 470 240]);wire(s,'Velocity_To_Voltage_Derivative/1','Derivative_Sample/1');
blk(s,'simulink/Sources/Random Number','Common_Clock_Jitter','Mean','0','Variance','wl_jitterVariance','Seed','wl_c.seed+621','SampleTime','wl_Ta','Position',[320 300 480 340]);
blk(s,'simulink/Math Operations/Product','Aperture_Error','Inputs','2','Position',[520 210 560 250]);wire(s,'Derivative_Sample/1','Aperture_Error/1');wire(s,'Common_Clock_Jitter/1','Aperture_Error/2');
blk(s,'simulink/Math Operations/Sum','Sampled_Input','Inputs','++','Position',[610 80 630 160]);wire(s,'Sample_Hold/1','Sampled_Input/1');wire(s,'Aperture_Error/1','Sampled_Input/2');
if strcmp(evalin('base','wl_c.adcArchitecture'),'sigma_delta')
 sdm(s,'ADC_Quantizer_INL');wire(s,'Sampled_Input/1','ADC_Quantizer_INL/1');
else
 mf(s,'ADC_Quantizer_INL','wl_adc_transfer(u,wl_c)',2,[690 80 900 130]);wire(s,'Sampled_Input/1','ADC_Quantizer_INL/1');
end
blk(s,'simulink/Discrete/Delay','Conversion_Latency','DelayLength','wl_c.adcDelay','SampleTime','wl_Ta','InitialCondition','0','Position',[950 85 1110 130]);
transition(s,'ADC_Clock_Boundary','wl_Ta',[900 180 1090 220]);
wire(s,'ADC_Quantizer_INL/1','ADC_Clock_Boundary/1');wire(s,'ADC_Clock_Boundary/1','Conversion_Latency/1');wire(s,'Conversion_Latency/1','Out1/1');
mf(s,'Overrange_Comparator','double(any(abs(u)>=wl_c.adcFsV))',1,[690 380 920 430]);wire(s,'Sampled_Input/1','Overrange_Comparator/1');
blk(s,'simulink/Discrete/Discrete Filter','CIC_Contamination_Window','Numerator','ones(1,wl_R*wl_c.cicStages)','Denominator','1','SampleTime','wl_Ta','Position',[980 380 1210 430]);wire(s,'Overrange_Comparator/1','CIC_Contamination_Window/1');
blk(s,'simulink/Discrete/Zero-Order Hold','Overrange_Control_Sample','SampleTime','wl_Tc','Position',[1270 380 1470 430]);wire(s,'CIC_Contamination_Window/1','Overrange_Control_Sample/1');
blk(s,'simulink/Discrete/Discrete Filter','FIR_Contamination_Window','Numerator','ones(1,numel(wl_fir))','Denominator','1','SampleTime','wl_Tc','Position',[1530 380 1750 430]);wire(s,'Overrange_Control_Sample/1','FIR_Contamination_Window/1');
blk(s,'simulink/Discrete/Delay','Overrange_Alignment','DelayLength','wl_c.pipelineCtrl','SampleTime','wl_Tc','InitialCondition','0','Position',[1810 380 2000 430]);wire(s,'FIR_Contamination_Window/1','Overrange_Alignment/1');
mf(s,'Contaminated','double(u>0)',1,[2050 380 2180 430]);wire(s,'Overrange_Alignment/1','Contaminated/1');wire(s,'Contaminated/1','Out2/1');
observe(s,'Sample_Hold/1','sample_hold',evalin('base','wl_c.fsAdc'),'V');
observe(s,'Conversion_Latency/1','adc',evalin('base','wl_c.fsAdc'),'V');
end
function digital(s)
transition(s,'ADC_Output_Hold','0',[30 190 180 230]);wire(s,'In1/1','ADC_Output_Hold/1');
blk(s,'simulink/Signal Routing/Mux','Mixer_Input','Inputs','2','Position',[120 50 125 130]);wire(s,'ADC_Output_Hold/1','Mixer_Input/1');wire(s,'In2/1','Mixer_Input/2');
mf(s,'IQ_Mixer','wl_mix(u,wl_detectGain)',4,[180 60 350 110]);wire(s,'Mixer_Input/1','IQ_Mixer/1');
transition(s,'Mixer_Clock_Boundary','wl_Ta',[180 250 370 290]);wire(s,'IQ_Mixer/1','Mixer_Clock_Boundary/1');
last='Mixer_Clock_Boundary/1';stages=evalin('base','wl_c.cicStages');
for k=1:stages
 n=sprintf('CIC_Equivalent_Boxcar_%d',k);
 blk(s,'simulink/Discrete/Discrete Filter',n,'Numerator','wl_boxcar','Denominator','1','SampleTime','wl_Ta','Position',[400+170*(k-1) 60 550+170*(k-1) 110]);
 wire(s,last,[n '/1']);last=[n '/1'];
end
blk(s,'simulink/Discrete/Zero-Order Hold','Decimate_To_Control','SampleTime','wl_Tc','Position',[1000 60 1170 110]);wire(s,last,'Decimate_To_Control/1');
blk(s,'simulink/Discrete/Discrete Filter','FIR_Compensation','Numerator','wl_fir','Denominator','1','SampleTime','wl_Tc','Position',[1220 60 1390 110]);wire(s,'Decimate_To_Control/1','FIR_Compensation/1');
mf(s,'IQ_Fixed_Format','wl_iq_quantize(u,wl_c)',4,[1450 60 1600 110]);wire(s,'FIR_Compensation/1','IQ_Fixed_Format/1');
transition(s,'Control_Clock_Boundary','wl_Tc',[1450 250 1630 290]);wire(s,'IQ_Fixed_Format/1','Control_Clock_Boundary/1');
blk(s,'simulink/Discrete/Delay','Digital_Pipeline','DelayLength','wl_c.pipelineCtrl','SampleTime','wl_Tc','InitialCondition','0','Position',[1650 60 1800 110]);wire(s,'Control_Clock_Boundary/1','Digital_Pipeline/1');wire(s,'Digital_Pipeline/1','Out1/1');
observe(s,'Mixer_Clock_Boundary/1','mixer',evalin('base','wl_c.fsAdc'),'normalized IQ');
observe(s,'Decimate_To_Control/1','cic',evalin('base','1/wl_Tc'),'normalized IQ');
observe(s,'FIR_Compensation/1','fir',evalin('base','1/wl_Tc'),'normalized IQ');
observe(s,'Digital_Pipeline/1','iq',evalin('base','1/wl_Tc'),'normalized IQ');
end
function algorithms(s)
blk(s,'simulink/User-Defined Functions/Level-2 MATLAB S-Function','Existing_MATLAB_Algorithms', ...
 'FunctionName','wl_algorithms_sfun','Parameters','wl_c','Position',[230 60 470 200]);
for k=1:6,wire(s,sprintf('In%d/1',k),sprintf('Existing_MATLAB_Algorithms/%d',k));end
blk(s,'simulink/Signal Routing/Demux','Outputs','Outputs','[10 4 21]','Position',[540 70 545 220]);wire(s,'Existing_MATLAB_Algorithms/1','Outputs/1');
for k=1:3,wire(s,sprintf('Outputs/%d',k),sprintf('Out%d/1',k));end
end
function controller(s)
mux(s,'Tick_Input',4,[180 70 185 240]);
blk(s,'simulink/Discrete/Unit Delay','Controller_State','InitialCondition','zeros(6,1)','SampleTime','wl_Tc','Position',[270 300 440 350]);
blk(s,'simulink/Sources/Constant','Head_Parameters','Value','wl_p','Position',[30 300 150 350]);
mf(s,'Legacy_PI_Slew_Adapter','wl_control_tick(u,wl_c)',14,[250 100 480 160]);
wire(s,'In1/1','Tick_Input/1');wire(s,'Controller_State/1','Tick_Input/2');wire(s,'In2/1','Tick_Input/3');wire(s,'Head_Parameters/1','Tick_Input/4');wire(s,'Tick_Input/1','Legacy_PI_Slew_Adapter/1');
blk(s,'simulink/Signal Routing/Demux','Tick_Outputs','Outputs','[6 4 1 3]','Position',[540 80 545 240]);wire(s,'Legacy_PI_Slew_Adapter/1','Tick_Outputs/1');wire(s,'Tick_Outputs/1','Controller_State/1');
wire(s,'Tick_Outputs/2','Out1/1');wire(s,'Tick_Outputs/3','Out2/1');wire(s,'Tick_Outputs/4','Out3/1');
end
function nco(s)
blk(s,'simulink/Sources/Constant','Nominal_Hz','Value','wl_c.head.f0','Position',[20 150 140 190]);
blk(s,'simulink/Math Operations/Sum','Frequency','Inputs','++','Position',[200 60 220 140]);wire(s,'In1/1','Frequency/1');wire(s,'Nominal_Hz/1','Frequency/2');
gain(s,'Radians_Per_Second','2*pi',[270 70 380 110]);wire(s,'Frequency/1','Radians_Per_Second/1');
 transition(s,'Frequency_Output_Hold','0',[270 230 450 270]);wire(s,'Radians_Per_Second/1','Frequency_Output_Hold/1');
 blk(s,'simulink/Continuous/Integrator','Phase','Position',[440 70 480 110]);wire(s,'Frequency_Output_Hold/1','Phase/1');wire(s,'Phase/1','Out1/1');
end
function driver(s)
mux(s,'Modulator_Input',2,[110 60 115 160]);wire(s,'In1/1','Modulator_Input/1');wire(s,'In2/1','Modulator_Input/2');
mf(s,'Force_Envelope_To_Drive_V','wl_modulate(u,wl_c,wl_hToV)',2,[180 70 390 130]);wire(s,'Modulator_Input/1','Force_Envelope_To_Drive_V/1');
blk(s,'simulink/Discrete/Zero-Order Hold','DAC_Update_Hold','SampleTime','wl_Ta','Position',[440 70 590 120]);wire(s,'Force_Envelope_To_Drive_V/1','DAC_Update_Hold/1');
if strcmp(evalin('base','wl_c.dacArchitecture'),'sigma_delta')
 sdm(s,'DAC_Quantizer_INL');wire(s,'DAC_Update_Hold/1','DAC_Quantizer_INL/1');
else
 mf(s,'DAC_Quantizer_INL','wl_quantize(u,wl_c.dacBits,wl_c.dacFsV,wl_c.dacInlCubic)',2,[640 70 830 120]);wire(s,'DAC_Update_Hold/1','DAC_Quantizer_INL/1');
end
transition(s,'DAC_Clock_Boundary','wl_Ta',[650 230 840 270]);wire(s,'DAC_Quantizer_INL/1','DAC_Clock_Boundary/1');
blk(s,'simulink/Discrete/Delay','DAC_Latency','DelayLength','wl_c.dacDelay','SampleTime','wl_Ta','InitialCondition','0','Position',[880 70 1030 120]);wire(s,'DAC_Clock_Boundary/1','DAC_Latency/1');
gain(s,'Drive_Matrix','diag(wl_c.driverGain)*wl_c.head.drive',[1090 70 1270 120]);wire(s,'DAC_Latency/1','Drive_Matrix/1');
transition(s,'DAC_Output_Hold','0',[1090 300 1270 340]);wire(s,'Drive_Matrix/1','DAC_Output_Hold/1');
lowpass(s,'Driver_Output_Pole','wl_c.driverBandwidthHz',[1320 70 1480 120]);wire(s,'DAC_Output_Hold/1','Driver_Output_Pole/1');
noise(s,'Driver_Noise','wl_driverNoiseVariance',631,[1330 230 1480 270]);
blk(s,'simulink/Math Operations/Sum','Noisy_Driver','Inputs','++','Position',[1530 80 1550 160]);wire(s,'Driver_Output_Pole/1','Noisy_Driver/1');wire(s,'Driver_Noise/1','Noisy_Driver/2');
blk(s,'simulink/Discontinuities/Rate Limiter','Driver_Slew','RisingSlewLimit','wl_c.driverSlewVPerS','FallingSlewLimit','-wl_c.driverSlewVPerS','Position',[1610 80 1750 130]);wire(s,'Noisy_Driver/1','Driver_Slew/1');
blk(s,'simulink/Discontinuities/Saturation','Driver_Rails','UpperLimit','wl_c.driverLimitV','LowerLimit','-wl_c.driverLimitV','Position',[1800 80 1940 130]);wire(s,'Driver_Slew/1','Driver_Rails/1');
gain(s,'Voltage_To_Force_Acceleration','wl_forceGain',[1990 80 2200 130]);wire(s,'Driver_Rails/1','Voltage_To_Force_Acceleration/1');
wire(s,'Voltage_To_Force_Acceleration/1','Out1/1');wire(s,'Driver_Rails/1','Out2/1');wire(s,'DAC_Quantizer_INL/1','Out3/1');
observe(s,'Force_Envelope_To_Drive_V/1','dac_requested',evalin('base','wl_c.fsPlant'),'V');
observe(s,'DAC_Latency/1','dac',evalin('base','wl_c.fsAdc'),'V');
observe(s,'Driver_Rails/1','driver',evalin('base','wl_c.fsPlant'),'V');
observe(s,'Voltage_To_Force_Acceleration/1','force',evalin('base','wl_c.fsPlant'),'normalized acceleration');
end
function ss(parent,name,ni,no,pos)
s=[parent '/' name];blk(parent,'simulink/Ports & Subsystems/Subsystem',name,'Position',pos);Simulink.SubSystem.deleteContents(s);
for k=1:ni,blk(s,'simulink/Sources/In1',sprintf('In%d',k),'Port',num2str(k),'Position',[20 40+60*k 50 60+60*k]);end
for k=1:no,blk(s,'simulink/Sinks/Out1',sprintf('Out%d',k),'Port',num2str(k),'Position',[2400 40+70*k 2430 60+70*k]);end
end
function sdm(parent,name)
% Explicit first-order, leaky 1-bit sigma-delta reference, not paper's CIFF4.
ss(parent,name,1,1,[690 80 900 130]);s=[parent '/' name];
gain(s,'Normalize','1/wl_c.sdmReferenceV',[120 60 250 110]);wire(s,'In1/1','Normalize/1');
blk(s,'simulink/Math Operations/Sum','Input_Minus_Feedback','Inputs','+-','Position',[300 60 320 140]);wire(s,'Normalize/1','Input_Minus_Feedback/1');
blk(s,'simulink/Discrete/Discrete Filter','Leaky_Integrator','Numerator','1','Denominator','[1 -wl_c.sdmLeak]','SampleTime','wl_Ta','Position',[380 70 540 120]);wire(s,'Input_Minus_Feedback/1','Leaky_Integrator/1');
blk(s,'simulink/Discontinuities/Relay','One_Bit_Quantizer','OnSwitchValue','0','OffSwitchValue','0', ...
 'OnOutputValue','1','OffOutputValue','-1','Position',[600 70 760 120]);wire(s,'Leaky_Integrator/1','One_Bit_Quantizer/1');
blk(s,'simulink/Discrete/Unit Delay','Feedback_Delay','SampleTime','wl_Ta','InitialCondition','0','Position',[430 250 580 300]);
wire(s,'One_Bit_Quantizer/1','Feedback_Delay/1');wire(s,'Feedback_Delay/1','Input_Minus_Feedback/2');
gain(s,'Reference_Voltage','wl_c.sdmReferenceV',[830 70 1000 120]);wire(s,'One_Bit_Quantizer/1','Reference_Voltage/1');wire(s,'Reference_Voltage/1','Out1/1');
end
function observe(s,from,label,fs,units)
c=evalin('base','wl_c');persistent serial;if isempty(serial),serial=0;end;serial=serial+1;
pos=[50+mod(serial,4)*340 800+floor(mod(serial,16)/4)*140];
logname=['tap_' label];
blk(s,'simulink/Sinks/To Workspace',logname,'VariableName',logname,'SaveFormat','Timeseries', ...
 'MaxDataPoints',num2str(c.maxLogPoints),'Position',[pos pos+[190 40]]);wire(s,from,[logname '/1']);
if c.observers
 n=['Scope_' label];blk(s,'simulink/Sinks/Scope',n,'Position',[pos+[210 0] pos+[260 40]]);wire(s,from,[n '/1']);
 set_param([s '/' n],'OpenAtSimulationStart','off');
end
if c.spectra && ~contains(label,{'diagnostics','navigation','commands'})
 % Select the first physical channel; do not mix vector channels into frames.
 select=['Spectrum_Channel_' label];
 blk(s,'simulink/Signal Routing/Selector',select,'NumberOfDimensions','1','IndexOptionArray',{'Index vector (dialog)'}, ...
  'IndexParamArray',{'1'},'InputPortWidth',num2str(2+2*ismember(label,{'mixer','cic','fir','iq'})), ...
  'Position',[pos+[0 60] pos+[80 100]]);wire(s,from,[select '/1']);
 n=['Spectrum_' label];src=sprintf('dspsnks4/Spectrum\nAnalyzer');
 blk(s,src,n,'Position',[pos+[120 60] pos+[270 110]], ...
  'OpenAtSimulationStart','off','SampleRateSource','Property','SampleRate',num2str(fs), ...
  'Title',[label ' [' units ']'],'RBWSource','Property','RBW',num2str(max(fs/1024,1)));
 wire(s,[select '/1'],[n '/1']);
end
end
function lowpass(s,n,f,pos)
value=evalin('base',f);
if isinf(value)
 gain(s,n,'1',pos);
else
 blk(s,'simulink/Continuous/State-Space',n,'A',['-2*pi*' f '*eye(2)'],'B',['2*pi*' f '*eye(2)'], ...
  'C','eye(2)','D','zeros(2)','Position',pos);
end
end
function transition(s,n,Ts,pos)
% Single-task, fixed-step scheduling: use the latest available value. Extra
% deterministic transfer buffers would add undocumented ADC/control latency.
% Hardware/RTL register latency is modeled explicitly by Delay/Unit Delay.
blk(s,'built-in/RateTransition',n,'OutPortSampleTimeOpt','Specify','OutPortSampleTime',Ts, ...
 'Integrity','off','Deterministic','off','InitialCondition','0','Position',pos);
end
function noise(s,n,var,seed,pos)
blk(s,'simulink/Sources/Random Number',n,'Mean','[0;0]','Variance',[var '*[1;1]'], ...
 'Seed',sprintf('[wl_c.seed+%d;wl_c.seed+%d]',seed,seed+1),'SampleTime','wl_Tp','Position',pos);
end
function gain(s,n,v,pos)
blk(s,'simulink/Math Operations/Gain',n,'Gain',v,'Multiplication','Matrix(K*u)','Position',pos);
end
function mf(s,n,expr,dim,pos)
blk(s,'built-in/MATLABFcn',n,'MATLABFcn',expr,'OutputDimensions',num2str(dim),'Position',pos);
end
function mux(s,n,inputs,pos)
blk(s,'simulink/Signal Routing/Mux',n,'Inputs',num2str(inputs),'Position',pos);
end
function wire(s,a,b)
add_line(s,a,b,'autorouting','on');
end
function blk(s,source,name,varargin)
if numel(varargin)==1,varargin={'Position',varargin{1}};end
add_block(source,[s '/' name],varargin{:});
end
