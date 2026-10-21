function build_wa_models()
% Reproducible visible Simulink assembly using core Simulink blocks only.
root=fileparts(mfilename('fullpath'));addpath(root);wa_setup();
load_system('simulink');
name='hrg_wa_envelope'; fresh(name);
set_param(name,'Solver','ode4','SolverType','Fixed-step','FixedStep','wa_Ts', ...
 'StopTime','wa_duration','ReturnWorkspaceOutputs','on','SaveOutput','off');
add_block('simulink/Sources/From Workspace',[name '/Rate_Temperature_Virtual'], ...
 'VariableName','wa_input','Position',[30 100 180 140]);
add_block('simulink/Signal Routing/Demux',[name '/Inputs'],'Outputs','[1 1 1]','Position',[210 95 215 170]);
add_block('simulink/Sources/Constant',[name '/Head_Parameters'],'Value','wa_p','Position',[30 240 180 280]);
add_block('simulink/Continuous/Integrator',[name '/Modal_Envelope'],'InitialCondition','wa_z0','Position',[480 90 530 130]);
add_block('simulink/Continuous/Integrator',[name '/Reference_Phase'],'InitialCondition','0','Position',[480 300 530 340]);
add_block('simulink/Continuous/Integrator',[name '/PI_States'],'InitialCondition','[0;0;0]','Position',[760 300 810 340]);
fcn(name,'Detection_IQ','wa_measure(u)',10,[680 80 850 130]);
mux(name,'Detect_Input',3,[625 70 630 160]);
line(name,'Modal_Envelope/1','Detect_Input/1');line(name,'Reference_Phase/1','Detect_Input/2');line(name,'Head_Parameters/1','Detect_Input/3');
line(name,'Detect_Input/1','Detection_IQ/1');
mux(name,'Control_Input',5,[890 90 895 260]);
fcn(name,'Energy_Quadrature_PLL','wa_controller(u)',11,[940 110 1130 170]);
add_block('simulink/Signal Routing/Demux',[name '/Control_Outputs'],'Outputs','[4 3 1 3]','Position',[1170 105 1175 250]);
line(name,'Detection_IQ/1','Control_Input/1');line(name,'PI_States/1','Control_Input/2');
line(name,'Reference_Phase/1','Control_Input/3');line(name,'Inputs/3','Control_Input/4');line(name,'Head_Parameters/1','Control_Input/5');
line(name,'Control_Input/1','Energy_Quadrature_PLL/1');line(name,'Energy_Quadrature_PLL/1','Control_Outputs/1');
line(name,'Control_Outputs/2','PI_States/1');line(name,'Control_Outputs/3','Reference_Phase/1');
mux(name,'Plant_Input',5,[300 60 305 230]);
fcn(name,'Two_Mode_Plant','wa_plant_rhs(u)',4,[340 90 440 140]);
line(name,'Modal_Envelope/1','Plant_Input/1');line(name,'Control_Outputs/1','Plant_Input/2');line(name,'Inputs/1','Plant_Input/3');
line(name,'Inputs/2','Plant_Input/4');line(name,'Head_Parameters/1','Plant_Input/5');line(name,'Plant_Input/1','Two_Mode_Plant/1');line(name,'Two_Mode_Plant/1','Modal_Envelope/1');
line(name,'Rate_Temperature_Virtual/1','Inputs/1');
% Navigation has an explicit sampled-data state loop, separate from plant truth.
add_block('simulink/Discrete/Zero-Order Hold',[name '/IQ_Sampling'],'SampleTime','wa_Ts','Position',[680 440 780 480]);
add_block('simulink/Discrete/Unit Delay',[name '/Navigation_Memory'],'SampleTime','wa_Ts', ...
 'InitialCondition','[0;0;0;0]','Position',[1100 560 1170 600]);
mux(name,'Navigation_Input',4,[835 435 840 550]);
fcn(name,'Angle_Unwrap_Bryan','wa_nav_step(u)',8,[900 445 1050 495]);
add_block('simulink/Signal Routing/Demux',[name '/Navigation_Outputs'],'Outputs','[4 4]','Position',[1090 440 1095 510]);
line(name,'Detection_IQ/1','IQ_Sampling/1');line(name,'IQ_Sampling/1','Navigation_Input/1');line(name,'Navigation_Memory/1','Navigation_Input/2');
line(name,'Inputs/3','Navigation_Input/3');line(name,'Head_Parameters/1','Navigation_Input/4');line(name,'Navigation_Input/1','Angle_Unwrap_Bryan/1');
line(name,'Angle_Unwrap_Bryan/1','Navigation_Outputs/1');line(name,'Navigation_Outputs/1','Navigation_Memory/1');
sink(name,'Modal_Envelope/1','zlog',[570 15 650 45]);
sink(name,'Detection_IQ/1','iqlog',[940 20 1020 50]);
sink(name,'Control_Outputs/4','ctrllog',[1220 220 1300 250]);
sink(name,'Navigation_Outputs/2','navlog',[1210 440 1310 480]);
sink(name,'Reference_Phase/1','psilog',[560 310 640 345]);
annotation=Simulink.Annotation(name, sprintf(['WHOLE-ANGLE HRG: COMPLEX ENVELOPE\n' ...
 'Physical rim angle theta = atan2(S,R)/4; rate = -theta_dot/Bryan.\n' ...
 'Energy, quadrature and reference phase controlled; azimuth remains free.\n' ...
 'Run wa_setup; model parameters are unmeasured assumptions. SI units.']));
annotation.Position=[30 370 560 470];
set_param(name,'Location',[30 40 1400 820]);
set_param(name,'PostLoadFcn',sprintf('addpath(fileparts(get_param(''%s'',''FileName''))); wa_setup;',name));
save_system(name,fullfile(root,[name '.slx']));
print(['-s' name],'-dpng','-r140',fullfile(root,'envelope_diagram.png'));
close_system(name,0);
% Full carrier plant: two generalized displacements and two velocities.
name='hrg_wa_carrier';fresh(name);
set_param(name,'Solver','ode4','SolverType','Fixed-step','FixedStep','wa_full_step', ...
 'StopTime','.05','ReturnWorkspaceOutputs','on','SaveOutput','off');
add_block('simulink/Sources/From Workspace',[name '/Rate_Acceleration_Temperature_Force'], ...
 'VariableName','wa_full_input','Position',[30 85 250 135]);
add_block('simulink/Sources/Constant',[name '/Head_Parameters'],'Value','wa_p','Position',[30 190 210 230]);
add_block('simulink/Continuous/Integrator',[name '/Displacement_Velocity'],'InitialCondition','wa_q0','Position',[700 85 760 135]);
mux(name,'Mechanical_Inputs',3,[320 70 325 230]);
fcn(name,'Coupled_Second_Order_ODE','wa_full_rhs(u)',4,[410 90 630 150]);
line(name,'Displacement_Velocity/1','Mechanical_Inputs/1');line(name,'Rate_Acceleration_Temperature_Force/1','Mechanical_Inputs/2');
line(name,'Head_Parameters/1','Mechanical_Inputs/3');line(name,'Mechanical_Inputs/1','Coupled_Second_Order_ODE/1');
line(name,'Coupled_Second_Order_ODE/1','Displacement_Velocity/1');sink(name,'Displacement_Velocity/1','carrierlog',[830 85 930 135]);
annotation=Simulink.Annotation(name,sprintf(['CARRIER MODEL: qdd + (D+4*B*Omega*J)qd + (K+2*B*Omega_dot*J)q = F/m\n' ...
 'X and Y are symmetric n=2 generalized modes. Unit modal mass.\n' ...
 'Direct second-order equation; independent reference for envelope averaging.']));
annotation.Position=[50 300 850 390];
set_param(name,'PostLoadFcn',sprintf('addpath(fileparts(get_param(''%s'',''FileName''))); wa_setup;',name));
set_param(name,'Location',[30 40 1050 650]);save_system(name,fullfile(root,[name '.slx']));
print(['-s' name],'-dpng','-r140',fullfile(root,'carrier_diagram.png'));close_system(name,0);
disp('Built both Simulink models.');
end

function fresh(name)
if bdIsLoaded(name),close_system(name,0);end
new_system(name);
end
function fcn(name,block,expression,n,pos)
add_block('built-in/MATLABFcn',[name '/' block], ...
 'MATLABFcn',expression,'OutputDimensions',num2str(n),'Position',pos);
end
function mux(name,block,n,pos)
add_block('simulink/Signal Routing/Mux',[name '/' block],'Inputs',num2str(n),'Position',pos);
end
function line(name,from,to)
add_line(name,from,to,'autorouting','on');
end
function sink(name,source,variable,pos)
add_block('simulink/Sinks/To Workspace',[name '/' variable], ...
 'VariableName',variable,'SaveFormat','Timeseries','Position',pos);
line(name,source,[variable '/1']);
end
