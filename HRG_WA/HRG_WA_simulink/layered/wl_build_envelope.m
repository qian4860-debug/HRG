function name=wl_build_envelope(c)
% Fast long-run algorithm harness, with explicit equivalent-interface labeling.
assert(strcmp(c.adcArchitecture,'nyquist') && strcmp(c.dacArchitecture,'nyquist'), ...
 'Bitstream architectures require the carrier model, not envelope equivalence.');
root=fileparts(mfilename('fullpath'));addpath(root);source=sprintf('hrg_wa_v%d',c.stage);
path=fullfile(root,'models',[source '.slx']);
if ~isfile(path),raw=c;raw.name=source;wl_build(raw);end
if ~bdIsLoaded(source),load_system(path);end
c=wl_setup(c);name=[source '_envelope'];
if bdIsLoaded(name),close_system(name,0);end
new_system(name);set_param(name,'Solver','ode4','SolverType','Fixed-step','FixedStep','wl_Tc', ...
 'StopTime','wl_stop','ReturnWorkspaceOutputs','on','SaveOutput','off','AlgebraicLoopMsg','error');
b('simulink/Sources/Clock','Time',[20 30 50 50]);
f('Scenario','wl_input(u,wl_c)',4,[90 20 250 70]);w('Time/1','Scenario/1');
b('simulink/Signal Routing/Demux','Inputs',[290 20 295 130],'Outputs','[1 1 1 1]');w('Scenario/1','Inputs/1');
z=wa_initial(c.head);assignin('base','wl_env_z0',[real(z);imag(z)]);
b('simulink/Continuous/Integrator','Modal_State',[500 180 550 230],'InitialCondition','wl_env_z0');
b('simulink/Continuous/Integrator','Reference_Offset',[600 390 650 440]);
b('simulink/Sources/Constant','Parameters',[20 230 150 270],'Value','wl_p');
mx('Plant_Inputs',5,[210 150 215 320]);
f('Envelope_ODE','wa_plant_rhs(u)',4,[300 170 440 230]);
w('Modal_State/1','Plant_Inputs/1');w('Inputs/1','Plant_Inputs/3');w('Inputs/3','Plant_Inputs/4');w('Parameters/1','Plant_Inputs/5');
w('Plant_Inputs/1','Envelope_ODE/1');w('Envelope_ODE/1','Modal_State/1');
mx('Sense_Inputs',2,[620 150 625 250]);w('Modal_State/1','Sense_Inputs/1');w('Reference_Offset/1','Sense_Inputs/2');
f('Narrowband_CV_ADC_Equivalent','wl_env_sense(u,wl_c)',4,[680 170 930 230]);w('Sense_Inputs/1','Narrowband_CV_ADC_Equivalent/1');
noiseVar=(c.cvEquivalentNoiseVrtHz^2*c.pgaGain^2+c.pgaNoiseVrtHz^2)/(evalin('base','wl_detectGain')^2)/c.head.Ts*c.noiseEnable;
assignin('base','wl_env_noise',noiseVar);
b('simulink/Sources/Random Number','Envelope_Noise',[680 290 880 330],'Mean','zeros(4,1)', ...
 'Variance','wl_env_noise*ones(4,1)','Seed','wl_c.seed+[701;702;703;704]','SampleTime','wl_Tc');
b('simulink/Math Operations/Sum','Observed_IQ',[980 180 1000 250],'Inputs','++');w('Narrowband_CV_ADC_Equivalent/1','Observed_IQ/1');w('Envelope_Noise/1','Observed_IQ/2');
f('IQ_Equivalent_Quantizer','wl_env_adc(u,wl_c,wl_detectGain)',4,[1050 180 1270 230]);w('Observed_IQ/1','IQ_Equivalent_Quantizer/1');
b('simulink/Discrete/Zero-Order Hold','Control_Sampling',[1320 180 1460 230],'SampleTime','wl_Tc');w('IQ_Equivalent_Quantizer/1','Control_Sampling/1');
b('simulink/Discrete/Discrete Filter','FIR',[1510 180 1640 230],'Numerator','wl_fir','Denominator','1','SampleTime','wl_Tc');w('Control_Sampling/1','FIR/1');
f('Phase_Format','wl_iq_quantize(u,wl_c)',4,[1690 180 1840 230]);w('FIR/1','Phase_Format/1');
b('simulink/Discrete/Delay','Equivalent_Latency',[1880 180 2020 230], ...
 'DelayLength','wl_c.pipelineCtrl+2','InitialCondition','0','SampleTime','wl_Tc');w('Phase_Format/1','Equivalent_Latency/1');
add_block([source '/Algorithms_Kalman_RLS_FRP'],[name '/Algorithms'],'Position',[1680 450 1970 620]);
add_block([source '/Discrete_PI_AntiWindup'],[name '/Controller'],'Position',[1120 450 1400 590]);
b('simulink/Sources/Constant','Fixture_Permit',[1500 680 1650 720],'Value','double(wl_c.calibrationPermit && wl_c.zeroRateCertified)');
b('simulink/Sources/Constant','ADC_Overrange_Bypass',[1500 750 1650 790],'Value','0');
b('simulink/Discrete/Unit Delay','Previous_Public_Command',[1120 700 1310 740],'InitialCondition','zeros(3,1)','SampleTime','wl_Tc');
w('Equivalent_Latency/1','Algorithms/1');w('Inputs/3','Algorithms/2');w('Inputs/4','Algorithms/3');w('Fixture_Permit/1','Algorithms/4');w('Previous_Public_Command/1','Algorithms/5');
w('ADC_Overrange_Bypass/1','Algorithms/6');
w('Algorithms/1','Controller/1');w('Inputs/4','Controller/2');w('Controller/3','Previous_Public_Command/1');
b('simulink/Discrete/Unit Delay','Control_Register',[800 500 980 550],'InitialCondition','zeros(4,1)','SampleTime','wl_Tc');w('Controller/1','Control_Register/1');
mx('Drive_Input',2,[660 500 665 600]);w('Control_Register/1','Drive_Input/1');w('Reference_Offset/1','Drive_Input/2');
f('Driver_Equivalent','wl_env_drive(u,wl_c)',4,[400 500 600 560]);w('Drive_Input/1','Driver_Equivalent/1');w('Driver_Equivalent/1','Plant_Inputs/2');
b('simulink/Math Operations/Gain','Hz_To_Radians',[760 390 900 430],'Gain','2*pi');w('Controller/2','Hz_To_Radians/1');w('Hz_To_Radians/1','Reference_Offset/1');
tap('Modal_State/1','envelope');tap('Equivalent_Latency/1','iq');tap('Algorithms/2','navigation');tap('Algorithms/3','algorithm_diagnostics');
ann=Simulink.Annotation(name,sprintf(['FAST ALGORITHM HARNESS: ENVELOPE EQUIVALENTS ONLY\n' ...
 'Uses real legacy Kalman/RLS/parameter-KF/FRP helpers and public measured I/Q.\n' ...
 'No carrier aliasing, SDM bitstreams or converter SINAD claims from this model.']));ann.Position=[20 800 1200 900];
assignin(get_param(name,'ModelWorkspace'),'wl_saved_configuration',rmfield(c,'legacyP'));
set_param(name,'PostLoadFcn',sprintf('addpath(fileparts(fileparts(get_param(''%s'',''FileName'')))); wl_setup(getVariable(get_param(''%s'',''ModelWorkspace''),''wl_saved_configuration''));',name,name));
save_system(name,fullfile(root,'models',[name '.slx']));
print(['-s' name],'-dpng','-r100',fullfile(root,'models',[name '.png']));
    function b(src,n,pos,varargin),add_block(src,[name '/' n],'Position',pos,varargin{:});end
    function f(n,expr,dim,pos),b('built-in/MATLABFcn',n,pos,'MATLABFcn',expr,'OutputDimensions',num2str(dim));end
    function mx(n,inputs,pos),b('simulink/Signal Routing/Mux',n,pos,'Inputs',num2str(inputs));end
    function w(a,d),add_line(name,a,d,'autorouting','on');end
    function tap(src,label)
        pos=[100+300*numel(find_system(name,'SearchDepth',1,'BlockType','ToWorkspace')) 1000];
        n=['tap_' label];b('simulink/Sinks/To Workspace',n,[pos pos+[200 40]],'VariableName',n,'SaveFormat','Timeseries');w(src,[n '/1']);
        n=['Scope_' label];b('simulink/Sinks/Scope',n,[pos+[0 80] pos+[100 120]]);w(src,[n '/1']);
    end
end
