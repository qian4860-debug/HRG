function three_angle_split_bias_plot(folder)
% 记分板取共用电极复用版的20秒输出、理想更新反例与有限位数对照。
arguments
    folder (1,:) char=fileparts(mfilename('fullpath'))
end
static=jsondecode(fileread(fullfile(folder,'split_bias_verification.json')));
step=jsondecode(fileread(fullfile(folder,'split_step_recovery.json')));
converter=jsondecode(fileread(fullfile(folder,'split_bias_converter.json')));
shared=static.modes(strcmp({static.modes.mode},'tdm_shared'));
f=figure('Visible','off','Color','white','Position',[100 100 1150 920]);
cleanup=onCleanup(@() close(f)); %#ok<NASGU>
tiledlayout(3,1,'TileSpacing','compact');
nexttile; ids=[4 7 6 5]; % 按真值排序后对比测量输出方向。
[truth,ix]=sort(1000*[shared.cases(ids).truth_rad_s]); ids=ids(ix);
y=zeros(4,2);
for k=1:4,y(k,:)=shared.cases(ids(k)).error_raw_corrected_mrad_s(end,:)+truth(k);end
plot(truth,truth,'k--',truth,y(:,1),'s-',truth,y(:,2),'o-','LineWidth',1.5);
grid on;xlabel('输入角速率 / mrad/s');ylabel('输出角速率 / mrad/s');
title('20 s 无量化复用模型，19–20 s 评分');legend({'理想','原始','补偿'},'Location','best');
nexttile;s=step.cases(7);x=(1:size(s.post_step_error_mrad_s,1))*step.window_s;
plot(x,s.post_step_error_mrad_s,'LineWidth',1.5);hold on;yline(.25,'k--');yline(-.25,'k--');
grid on; xlabel('距频差阶跃的时间 / s');ylabel('角速率误差 / mrad/s');
title('零速下频差从 50 降至 25 mHz，假设 0.5 s 后取得新读数');
legend({'原始','沿用旧读数','刷新读数'},'Location','best');
nexttile;v=zeros(6,2);
for k=1:6,v(k,:)=converter.cases(k).error_raw_corrected_mrad_s(end,:);end
bar(v);hold on;yline(.25,'k--');yline(-.25,'k--');grid on;
xticks(1:6);xticklabels({'10位 / -1','10位 / 0','10位 / +1','16位 / -1','16位 / 0','16位 / +1'});
ylabel('角速率误差 / mrad/s');xlabel('ADC 位数与输入角速率（mrad/s）');
title('逐拍复用模型，160–240 ms 评分，14 位 DAC');legend({'原始','补偿'},'Location','best');
set(findall(f,'Type','axes'),'Color','white','XColor','black','YColor','black');
set(findall(f,'Type','text'),'Color','black','Interpreter','none');
set(findall(f,'Type','legend'),'Color','white','TextColor','black');
exportgraphics(f,fullfile(folder,'split_bias_scoreboard.png'),'Resolution',140);
end
