function three_angle_lift_plot(folder)
% 第48号记分板只展示已验证的无量化帧级结果，不暗示低位数硬件性能。
arguments
    folder (1,:) char=fileparts(mfilename('fullpath'))
end
r=jsondecode(fileread(fullfile(folder,'numeric_lift_verification.json')));
f=figure('Visible','off','Color','white','Position',[100 100 1300 850]);
cleanup=onCleanup(@() close(f)); %#ok<NASGU>
tiledlayout(2,1,'TileSpacing','compact');
nexttile; hold on;
for k=1:2
    mode=r.lift_long_runs(k).mode;t=readtable(fullfile(folder,[mode '_lift_20s.csv']));
    plot(t.t_center_s,t.published_minus_truth_rad*1000,'LineWidth',1.4);
end
grid on;xlabel('时间 / s');ylabel('相对初始锚点的角误差 / mrad');
title('20秒无量化帧级闭环：保留分时机电载荷与原AGC/正交控制');
legend({'分时不复用','配阻复用'},'Location','best');
nexttile; rates=zeros(6,2);
for k=1:2,rates(:,k)=r.lift_long_runs(k).slopes_mechanical_readout_total_mrad_s(:,3);end
bar(rates);hold on;yline(.25,'k--');yline(-.25,'k--');grid on;
xticks(1:6);xticklabels({'0.02–0.06','0.08–0.12','1–2','5–6','10–11','19–20'});
xlabel('评分窗口 / s');ylabel('角速率误差 / mrad/s');
title('不同时间窗口分别评分：短时通过不等于长期准确');
legend({'分时不复用','配阻复用'},'Location','best');
set(findall(f,'Type','axes'),'Color','white','XColor','black','YColor','black','GridColor',[.6 .6 .6]);
set(findall(f,'Type','text'),'Color','black','Interpreter','none');
set(findall(f,'Type','legend'),'Color','white','TextColor','black');
exportgraphics(f,fullfile(folder,'numeric_lift_scoreboard.png'),'Resolution',150);
end
