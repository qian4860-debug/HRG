function name=w9_build_envelope(p,inverse,omega,step,saveModel)
name='hrg_wa_v9_identification';if bdIsLoaded(name),close_system(name,0);end
new_system(name);set_param(name,'SolverType','Fixed-step','Solver','ode4','FixedStep',num2str(step,17), ...
 'StopTime',num2str(p.envelope_duration_s),'ReturnWorkspaceOutputs','on');
gamma=pi*p.f0_hz/p.quality_factor;
axis=[cos(4*p.damping_axis_rad) sin(4*p.damping_axis_rad);sin(4*p.damping_axis_rad) -cos(4*p.damping_axis_rad)];
Gamma=gamma*eye(2)+p.damping_anisotropy_per_s/2*axis;J=[0 -1;1 0];
A=-Gamma-2*p.bryan*omega*J;
add_block('simulink/Continuous/Integrator',[name '/Physical_Envelope'], ...
 'InitialCondition',mat2str([cos(2*.137);sin(2*.137)],17),'Position',[100 100 220 160]);
add_block('simulink/Math Operations/Gain',[name '/Mechanical_Decay_And_Coriolis'], ...
 'Gain',mat2str(A,17),'Multiplication','Matrix(K*u)','Position',[320 50 540 110]);
add_line(name,'Physical_Envelope/1','Mechanical_Decay_And_Coriolis/1');
add_line(name,'Mechanical_Decay_And_Coriolis/1','Physical_Envelope/1','autorouting','on');
add_block('simulink/Math Operations/Gain',[name '/Actual_Detection'], ...
 'Gain',mat2str(p.sense_matrix,17),'Multiplication','Matrix(K*u)','Position',[300 200 470 260]);
add_block('simulink/Discontinuities/Quantizer',[name '/Measured_Baseband_Resolution'], ...
 'QuantizationInterval',num2str(p.fixture_adc_step,17),'Position',[530 200 700 260]);
add_block('simulink/Math Operations/Gain',[name '/Frozen_Fixture_Calibration'], ...
 'Gain',mat2str(inverse,17),'Multiplication','Matrix(K*u)','Position',[760 200 970 260]);
add_line(name,'Physical_Envelope/1','Actual_Detection/1');
add_line(name,'Actual_Detection/1','Measured_Baseband_Resolution/1');
add_line(name,'Measured_Baseband_Resolution/1','Frozen_Fixture_Calibration/1');
tap('Physical_Envelope/1','truth',[240 350 420 390]);
tap('Measured_Baseband_Resolution/1','raw',[500 350 680 390]);
tap('Frozen_Fixture_Calibration/1','calibrated',[780 350 960 390]);
note=Simulink.Annotation(name,['V9 H1: continuous real slow envelope; no quadrature/PLL/RF claim. ' ...
 'Truth tap is verification only. Estimator reads public measured/corrected traces.']);note.Position=[50 470 1000 540];
if saveModel
 folder=fullfile(fileparts(mfilename('fullpath')),'models');if ~isfolder(folder),mkdir(folder);end
 save_system(name,fullfile(folder,[name '.slx']));print(['-s' name],'-dpng','-r110',fullfile(folder,[name '.png']));
end
 function tap(source,label,pos)
  add_block('simulink/Sinks/To Workspace',[name '/tap_' label],'VariableName',['tap_' label], ...
   'SaveFormat','Timeseries','Position',pos);
  add_line(name,source,['tap_' label '/1'],'autorouting','on');
  add_block('simulink/Sinks/Scope',[name '/Scope_' label],'Position',pos+[0 65 0 65]);
  add_line(name,source,['Scope_' label '/1'],'autorouting','on');
 end
end
