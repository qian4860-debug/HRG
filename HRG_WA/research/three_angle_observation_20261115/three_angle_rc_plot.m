function three_angle_rc_plot(folder)
% 从已经完成的回执生成记分板；黑线为暂定筛选线，不能解释为器件指标。
arguments
    folder (1,:) char = fileparts(mfilename('fullpath'))
end
r=jsondecode(fileread(fullfile(folder,'rc_verification.json')));
names=string({r.estimates.scenario});
delta=reshape([r.cases.topology_delta_mrad_s],4,[])';
absolute=reshape([r.cases.total_slope_mrad_s],4,[])';
rmsAngle=reshape([r.cases.topology_rms_mrad],4,[])';
f=figure('Visible','off','Position',[100 100 1400 1100],'Color','white');
clean=onCleanup(@() close(f)); %#ok<NASGU>
tiledlayout(3,1,'TileSpacing','compact');
nexttile; bar(delta(:,2:4)); hold on;
yline(.05,'k--'); yline(-.05,'k--'); grid on;
xticks(1:numel(names)); xticklabels(names); ylabel('mrad/s');
title('拓扑间发布角斜率差：独立电气估计后冻结阻值');
legend({'固定 3.333 kΩ','真实参数配阻','带噪尾波估计配阻'},'Location','best');
nexttile; bar(rmsAngle(:,2:4)); hold on;
yline(.01,'k--'); grid on;
xticks(1:numel(names)); xticklabels(names); ylabel('mrad');
title('拓扑间角差 RMS：10 位对照仍超过 0.01 mrad 筛选线');
nexttile; bar(absolute); hold on;
yline(.25,'k--'); yline(-.25,'k--'); grid on;
xticks(1:numel(names)); xticklabels(names); ylabel('mrad/s');
title('相对机体真值的斜率误差：配阻通过不等于角度准确');
legend({'分时不复用参考','固定 3.333 kΩ','真实参数配阻','带噪尾波估计配阻'},'Location','best');
% 显式固定白底黑字，避免桌面深色主题导出为浅灰文字/白色纸面。
set(findall(f,'Type','axes'),'Color','white','XColor','black','YColor','black', ...
    'GridColor',[.6 .6 .6],'TickLabelInterpreter','none');
set(findall(f,'Type','text'),'Color','black','Interpreter','none');
set(findall(f,'Type','legend'),'Color','white','TextColor','black','EdgeColor',[.5 .5 .5]);
exportgraphics(f,fullfile(folder,'rc_scoreboard.png'),'Resolution',150);
end
