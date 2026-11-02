function mdl=quality_build()
root=quality_setup;old=fullfile(fileparts(root),'revision_v10_2_cn','models','hrg_wa_v10_2_cn_modular.slx');
mdl='hrg_wa_quality_monitor';folder=fullfile(root,'models');if ~exist(folder,'dir'),mkdir(folder);end
% 先在文件系统复制，再仅加载副本，避免Save As修改原模型保存状态。
if bdIsLoaded(mdl),close_system(mdl,0);end
copyfile(old,fullfile(folder,[mdl '.slx']));load_system(fullfile(folder,[mdl '.slx']));
path=[mdl '/Quality_Monitor'];add_block('simulink/Ports & Subsystems/Subsystem',path,'Position',[830 350 1110 460]);Simulink.SubSystem.deleteContents(path);
add_block('simulink/Sources/In1',[path '/Diagnostics'],'Position',[25 80 55 100]);
add_block('simulink/User-Defined Functions/Level-2 MATLAB S-Function',[path '/Read_Only_Quality'],'FunctionName','quality_sfun','Parameters','p','Position',[110 60 300 120]);add_line(path,'Diagnostics/1','Read_Only_Quality/1');
names={'归一化能量','归一化Q残差','正交残差','锁相检测残差','时间戳差值_us','有效性','锁相频率_Hz','能量误差_百分比'};
ix={'1','[2 3]','4','5','[6 7 8]','9','10','11'};
for k=1:numel(names)
 tap=['Tap' num2str(k)];add_block('simulink/Signal Routing/Selector',[path '/' tap],'InputPortWidth','11','Indices',ix{k},'Position',[380 45*k 440 25+45*k]);
 add_block('simulink/Sinks/Scope',[path '/' names{k}],'OpenAtSimulationStart','off','Position',[510 45*k 650 25+45*k]);
 add_line(path,'Read_Only_Quality/1',[tap '/1'],'autorouting','on');add_line(path,[tap '/1'],[names{k} '/1']);
end
a=Simulink.Annotation(path,sprintf('闭环质量｜只读观察\nQ按目标电荷归一化；无效帧残差显示NaN。\n时间差依次为：end-start、center-start、available-end，单位μs。\n锁相残差为I·Q/E，无量纲，非直接以rad计的相位角。\n最终角度误差在仿真后按完整帧源中心评分，见quality_demo。'));a.Position=[20 -100];
add_line(mdl,'Digital_Control_and_DAC/2','Quality_Monitor/1','autorouting','on');
save_system(mdl);close_system(mdl,0);load_system(fullfile(folder,[mdl '.slx']));
end
