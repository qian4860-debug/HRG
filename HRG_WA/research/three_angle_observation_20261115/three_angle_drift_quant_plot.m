function three_angle_drift_quant_plot(folder)
% 第47号记分板：显示频差/窗口变化、三路误差分解和未挑选种子的低位数结果。
arguments
    folder (1,:) char = fileparts(mfilename('fullpath'))
end
r=jsondecode(fileread(fullfile(folder,'drift_quant_verification.json')));
f=figure('Visible','off','Position',[100 100 1450 1100],'Color','white');
cleanup=onCleanup(@() close(f)); %#ok<NASGU>
tiledlayout(3,1,'TileSpacing','compact');
nexttile; idx=[1 2 5 6 9 10]; rates=zeros(numel(idx),2);
for k=1:numel(idx), rates(k,:)=[r.cases(idx(k)).windows.total_mrad_s]; end
bar(rates); hold on; yline(.25,'k--'); yline(-.25,'k--'); grid on;
xticks(1:6); xticklabels({'连续 Δf=0','连续 50mHz','分时不复用 Δf=0','分时不复用 50mHz','复用 Δf=0','复用 50mHz'});
ylabel('mrad/s'); title('相同初角下，频差与前后窗口对绝对角速率误差的影响');
legend({'20–60 ms','80–120 ms'},'Location','best');
nexttile; idx=[10 17 18 19 20 21 22]; parts=zeros(numel(idx),3);
for k=1:numel(idx)
    w=r.cases(idx(k)).windows(2);
    parts(k,:)=[w.mechanical_mrad_s w.readout_mrad_s w.publication_mrad_s];
end
bar(parts); grid on; xticks(1:numel(idx));
xticklabels({'16位','12位','10位','10位/1.5V','10位/抖动种子1','10位/抖动种子2','10位/抖动种子3'});
ylabel('mrad/s'); title('后窗误差分解：量化后分量与机械分量分别评分');
legend({'机械－真值','干净CV－机械','发布－干净CV'},'Location','best');
nexttile; idx=[18 20 21 22 23 24 25 26]; rates=zeros(numel(idx),2);
for k=1:numel(idx), rates(k,:)=[r.cases(idx(k)).windows.total_mrad_s]; end
bar(rates); hold on; yline(.25,'k--'); yline(-.25,'k--'); grid on;
xticks(1:numel(idx)); xticklabels({'零速/无抖动','零速/种子1','零速/种子2','零速/种子3', ...
    '负低速/无抖动','负低速/种子2','正低速/无抖动','正低速/种子2'});
ylabel('mrad/s'); title('0.5 LSB RMS 非减法抖动固定后做种子与正负低速留出验证');
legend({'20–60 ms','80–120 ms'},'Location','best');
set(findall(f,'Type','axes'),'Color','white','XColor','black','YColor','black', ...
    'GridColor',[.6 .6 .6],'TickLabelInterpreter','none');
set(findall(f,'Type','text'),'Color','black','Interpreter','none');
set(findall(f,'Type','legend'),'Color','white','TextColor','black','EdgeColor',[.5 .5 .5]);
exportgraphics(f,fullfile(folder,'drift_quant_scoreboard.png'),'Resolution',150);
end
