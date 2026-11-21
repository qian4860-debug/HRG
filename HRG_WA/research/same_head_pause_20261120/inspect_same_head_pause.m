function inspect_same_head_pause(project,folder)
% 运行同一表头三条轨迹，在共同时间轴上检查停驱损失与恢复驱动的量程。
% 对照使用相同机械与 C/V 初值，未限幅轨迹一旦越过 DAC 量程仅供请求量诊断。
arguments
    project (1,:) char=fileparts(fileparts(fileparts(mfilename('fullpath'))))
    folder (1,:) char=fileparts(mfilename('fullpath'))
end
addpath(fullfile(project,'research','three_mode_split_20261113'), ...
    fullfile(project,'research','three_angle_observation_20261115'));
c=three_mode_split_config('tdm_shared',.0003,.05,28.125,5,40, ...
    struct('Cs',720e-12,'bleed_R',1/(720e-12/2e-6-1e-10),'dac_bits',40));
c.periodicCarrier=true; L=three_angle_frame_lift(c);
model='hrg_same_head_pause'; opened=bdIsLoaded(model);
if ~opened, load_system(fullfile(folder,[model '.slx'])); end
cleanup=onCleanup(@()closeNew(model,opened)); %#ok<NASGU>
fig=figure('Visible','off','Color','white','Position',[50 50 980 630]);
closeFig=onCleanup(@()close(fig)); %#ok<NASGU>
layout=tiledlayout(fig,2,1,'TileSpacing','compact'); axes1=nexttile(layout); hold(axes1,'on');
axes2=nexttile(layout); hold(axes2,'on'); colors=[.09 .30 .48;.79 .25 .13;.02 .47 .35];
set([axes1 axes2],'Color','white','XColor',[.15 .15 .15],'YColor',[.15 .15 .15],'GridColor',[.6 .6 .6]);
names={'持续驱动','停驱后直接恢复（请求量）','停驱后限制包络'};
profiles=[0 0;1 0;1 1]; limit=min(c.dacMax,-c.dacMin);
for j=1:3
    input=Simulink.SimulationInput(model);
    input=input.setVariable('c',c,'Workspace',model);input=input.setVariable('L',L,'Workspace',model);
    input=input.setVariable('pauseStart',1,'Workspace',model);
    input=input.setVariable('pauseWidth',profiles(j,1),'Workspace',model);
    input=input.setVariable('useLimiter',profiles(j,2),'Workspace',model);
    out=sim(input); a=out.liftTrace; t=(0:size(a,1)-1)'*L.T;
    cmd=a(:,c.stateCount+(1:4)); env=max(hypot(cmd(:,1:2),cmd(:,3:4)),[],2);
    amplitude=sqrt(sum(a(:,c.stateCount+(5:8)).^2,2));
    % 请求量超限后，线性模型的响应用 NaN 隐去。驱动图保留请求值便于比较。
    if j==2
        invalid=find(env>=limit,1); if ~isempty(invalid),amplitude(invalid:end)=NaN;end
    end
    plot(axes1,t,amplitude,'Color',colors(j,:),'LineWidth',1.5,'DisplayName',names{j});
    plot(axes2,t,env,'Color',colors(j,:),'LineWidth',1.5,'DisplayName',names{j});
end
yline(axes2,limit,'--','DAC 正弦包络上限','Color',[.3 .3 .3],'HandleVisibility','off');
ylabel(axes1,'C/V 解调幅值（归一化）'); ylabel(axes2,'每帧最大驱动包络（V）'); xlabel(axes2,'时间（s）');
title(axes1,'配阻分时复用 · 50 mHz · +0.3 mrad/s','Color','black'); ylim(axes1,[.4 1.1]);
legend(axes1,'Location','southeast','Color','white','TextColor','black');
for ax=[axes1 axes2]
    grid(ax,'on'); xlim(ax,[0.5 4]);
    xline(ax,1,':','停驱','Color',[.3 .3 .3],'HandleVisibility','off');
    xline(ax,2,':','复驱','Color',[.3 .3 .3],'HandleVisibility','off');
end
exportgraphics(fig,fullfile(folder,'same_head_waveforms.png'),'Resolution',150);
end

function closeNew(model,alreadyOpen)
% 保留运行前已在用户桌面打开的模型。
if ~alreadyOpen, close_system(model,0);end
end
