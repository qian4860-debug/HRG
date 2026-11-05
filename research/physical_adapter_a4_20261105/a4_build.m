function mdl=a4_build(p,c,z)
root=fileparts(mfilename('fullpath'));mdl='hrg_wa_a4_physical_adapter';
if bdIsLoaded(mdl),close_system(mdl,0);end
new_system(mdl);mw=get_param(mdl,'ModelWorkspace');assignin(mw,'p',p);assignin(mw,'c',c);assignin(mw,'z',z);
set_param(mdl,'Solver','FixedStepDiscrete','FixedStep','p.Ts','StopTime','p.duration','ReturnWorkspaceOutputs','on');
add_block('simulink/User-Defined Functions/Level-2 MATLAB S-Function',[mdl '/Piezo_12_State'],'FunctionName','a4_plant_sfun','Parameters','p,z','Position',[80 90 260 150]);
add_block('simulink/User-Defined Functions/Level-2 MATLAB S-Function',[mdl '/ADC_Noise_and_Quantization'],'FunctionName','a4_adc_sfun','Parameters','p,z','Position',[330 90 530 150]);
add_block('simulink/User-Defined Functions/Level-2 MATLAB S-Function',[mdl '/Digital_Control_and_D0_Adapter'],'FunctionName','a4_controller_sfun','Parameters','p,c','Position',[610 90 850 170]);
add_line(mdl,'Piezo_12_State/1','ADC_Noise_and_Quantization/1');
add_line(mdl,'ADC_Noise_and_Quantization/1','Digital_Control_and_D0_Adapter/1');
add_line(mdl,'Digital_Control_and_D0_Adapter/1','Piezo_12_State/1','autorouting','on');
ports={'Piezo_12_State/1','ADC_Noise_and_Quantization/1','Digital_Control_and_D0_Adapter/1','Digital_Control_and_D0_Adapter/2'};
names={'plant','adc','dac','diagnostics'};
for k=1:4
 add_block('simulink/Sinks/To Workspace',[mdl '/Log_' names{k}],'VariableName',['a4_' names{k}],'SaveFormat','Timeseries','Position',[120+250*mod(k-1,2) 280+100*floor((k-1)/2) 270+250*mod(k-1,2) 310+100*floor((k-1)/2)]);
 add_line(mdl,ports{k},['Log_' names{k} '/1'],'autorouting','on');
 add_block('simulink/Sinks/Scope',[mdl '/Scope_' names{k}],'Position',[700+90*mod(k-1,2) 280+100*floor((k-1)/2) 750+90*mod(k-1,2) 310+100*floor((k-1)/2)]);
 add_line(mdl,ports{k},['Scope_' names{k} '/1'],'autorouting','on');
end
note=Simulink.Annotation(mdl,sprintf('A4 最小旋转闭环：合成端口与独立合成标定\nD0整数接口在控制反馈中；原RTL通过离线端口轨迹回放核对\n关闭预测/张量/虚拟进动/IQ平滑；真值仅评分\n非A2/A3完整接入、非实物验收、未测环路裕量'));note.Position=[70 490];
if ~exist(fullfile(root,'models'),'dir'),mkdir(fullfile(root,'models'));end
save_system(mdl,fullfile(root,'models',[mdl '.slx']));
end
