function name=w8_build(c,domain,saveArtifacts)
% Fresh V7 library construction, then explicit additive substitutions only.
if nargin<1,c=w8_config();end
if nargin<2,domain='carrier';end
if nargin<3,saveArtifacts=false;end
assert(ismember(domain,{'carrier','envelope'}));c=w8_setup(c);
if strcmp(domain,'carrier')
 name=w7_build(c,false);
 set_param([name '/NCO_IQ_CIC_FIR/IQ_Fixed_Format'],'MATLABFcn','w8_iq(u,wl_c)');
 set_param([name '/PI_PIR_Startup/Measured_PI_PIR_Startup'],'MATLABFcn','w8_control_tick(u,wl_c)');
 delete_line(name,'NCO_IQ_CIC_FIR/1','Algorithms_Kalman_RLS_FRP/1');
 add_block('simulink/Sources/Clock',[name '/Filter_Warmup_Clock'],'Position',[1100 700 1140 730]);
 add_block('simulink/Signal Routing/Mux',[name '/IQ_And_Public_Time'],'Inputs','2','Position',[1180 620 1185 730]);
 add_block('built-in/MATLABFcn',[name '/Feedback_Warmup_Validity'],'MATLABFcn','w8_feedback_gate(u,wl_c)', ...
  'OutputDimensions','4','Position',[1230 620 1450 670]);
 add_line(name,'NCO_IQ_CIC_FIR/1','IQ_And_Public_Time/1','autorouting','on');
 add_line(name,'Filter_Warmup_Clock/1','IQ_And_Public_Time/2','autorouting','on');
 add_line(name,'IQ_And_Public_Time/1','Feedback_Warmup_Validity/1','autorouting','on');
 add_line(name,'Feedback_Warmup_Validity/1','Algorithms_Kalman_RLS_FRP/1','autorouting','on');
 if c.v8.correlatedThermalNoise
  s=[name '/Mechanical_Head'];D=evalin('base','wl_D');
  L=chol(D/(2*c.head.gamma),'lower');
  add_block('simulink/Math Operations/Gain',[s '/FDT_Correlated_Thermal_Force'], ...
   'Gain',mat2str(L,17),'Multiplication','Matrix(K*u)','Position',[375 500 545 540]);
  delete_line(s,'Brownian_Force/1','All_Forces/2');
  add_line(s,'Brownian_Force/1','FDT_Correlated_Thermal_Force/1','autorouting','on');
  add_line(s,'FDT_Correlated_Thermal_Force/1','All_Forces/2','autorouting','on');
 end
else
 name=w7_envelope(c,false);
 set_param([name '/Nominal_AFE_ADC'],'MATLABFcn','w8_env_sense(u,wl_c)');
 set_param([name '/Calibrated_IQ'],'MATLABFcn','w8_iq(u,wl_c)');
 set_param([name '/Measured_PI_PIR'],'MATLABFcn','w8_control_tick(u,wl_c)');
end
annotations=find_system(name,'FindAll','on','Type','annotation');
for h=annotations(:)',delete(get_param(h,'Object'));end
a=Simulink.Annotation(name,sprintf(['V8 RESEARCH ON V7\nFrozen fixture calibration before invariants; separate actuator inverse.\n' ...
 'Carrier: exact capacitor and FDT matrix noise. Envelope: cubic electrode fundamental before AFE.\n' ...
 'No online truth compensation; synthetic calibration is not measured hardware identification.']));
a.Position=[20 1200 1300 1300];
assignin(get_param(name,'ModelWorkspace'),'v8_saved_configuration',rmfield(c,'legacyP'));
set_param(name,'PostLoadFcn',sprintf('addpath(fileparts(fileparts(get_param(''%s'',''FileName'')))); w8_setup(getVariable(get_param(''%s'',''ModelWorkspace''),''v8_saved_configuration''));',name,name));
if saveArtifacts
 r=fileparts(mfilename('fullpath'));folder=fullfile(r,'models');if ~isfolder(folder),mkdir(folder);end
 save_system(name,fullfile(folder,[name '.slx']));
 print(['-s' name],'-dpng','-r100',fullfile(folder,[name '.png']));
end
end
