function name=w9_build_bias(p,mode,voltage,step,saveModel)
% Native integrators explicitly expose the two equivalent spring descriptions.
name='hrg_wa_v9_bias_reference';if bdIsLoaded(name),close_system(name,0);end
assert(ismember(mode,{'bare','reference','double_count'}));new_system(name);
set_param(name,'SolverType','Fixed-step','Solver','ode4','FixedStep',num2str(step,17), ...
 'StopTime',num2str(p.carrier_duration_s),'ReturnWorkspaceOutputs','on');
w=2*pi*p.f0_hz;gamma=pi*p.f0_hz/p.quality_factor;P=p.electrostatic_P_per_s2_v2;
Kref=w*w*eye(2);Kbare=Kref+P*p.reference_bias_v^2;
if strcmp(mode,'bare'),spring=Kbare;counter=zeros(2);else,spring=Kref;counter=P*p.reference_bias_v^2;end
if strcmp(mode,'double_count'),counter=zeros(2);end
add_block('simulink/Continuous/Integrator',[name '/Displacement'], ...
 'InitialCondition','[0.8;0.6]','Position',[120 100 250 160]);
add_block('simulink/Continuous/Integrator',[name '/Velocity_Over_Omega0'], ...
 'InitialCondition','[0;0]','Position',[120 300 290 360]);
gain('Kinematic_Omega',w,[350 300 500 350]);
add_line(name,'Velocity_Over_Omega0/1','Kinematic_Omega/1');
add_line(name,'Kinematic_Omega/1','Displacement/1','autorouting','on');
gain('Mechanical_Spring',-spring/w,[350 30 560 80]);
gain('Full_Electrostatic_Feedback',P*voltage^2/w,[350 120 560 170]);
gain('Subtract_Reference_Bias',-counter/w,[350 200 560 250]);
gain('Passive_Damping',-2*gamma,[350 400 560 450]);
for label={'Mechanical_Spring','Full_Electrostatic_Feedback','Subtract_Reference_Bias'}
 add_line(name,'Displacement/1',[label{1} '/1'],'autorouting','on');
end
add_line(name,'Velocity_Over_Omega0/1','Passive_Damping/1');
add_block('simulink/Math Operations/Sum',[name '/Physical_Force_Balance'],'Inputs','++++','Position',[680 150 715 300]);
labels={'Mechanical_Spring','Full_Electrostatic_Feedback','Subtract_Reference_Bias','Passive_Damping'};
for k=1:4,add_line(name,[labels{k} '/1'],['Physical_Force_Balance/' num2str(k)],'autorouting','on');end
add_line(name,'Physical_Force_Balance/1','Velocity_Over_Omega0/1','autorouting','on');
tap('Displacement/1','q',[800 80 980 120]);tap('Velocity_Over_Omega0/1','p',[800 300 980 340]);
note=Simulink.Annotation(name,sprintf(['V9 H2: normalized physical carrier; state=[q,v/omega0]. Mode=%s; V=%g V.\n' ...
 'P is a synthetic mass-normalized small-signal electrostatic coefficient, not a measured head.'],mode,voltage));
note.Position=[60 560 1050 640];
if saveModel
 folder=fullfile(fileparts(mfilename('fullpath')),'models');if ~isfolder(folder),mkdir(folder);end
 save_system(name,fullfile(folder,[name '.slx']));print(['-s' name],'-dpng','-r110',fullfile(folder,[name '.png']));
end
 function gain(label,K,pos)
  if isscalar(K),K=K*eye(2);end
  add_block('simulink/Math Operations/Gain',[name '/' label],'Gain',mat2str(K,17), ...
   'Multiplication','Matrix(K*u)','Position',pos);
 end
 function tap(source,label,pos)
  add_block('simulink/Sinks/To Workspace',[name '/tap_' label],'VariableName',['tap_' label], ...
   'SaveFormat','Timeseries','Position',pos);
  add_line(name,source,['tap_' label '/1'],'autorouting','on');
  add_block('simulink/Sinks/Scope',[name '/Scope_' label],'Position',pos+[0 65 0 65]);
  add_line(name,source,['Scope_' label '/1'],'autorouting','on');
 end
end
