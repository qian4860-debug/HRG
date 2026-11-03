function a1_report()
% 各量分开显示，拒绝结果与导航精度分开解释；图窗可由a1_demo只读打开。
root=fileparts(mfilename('fullpath'));s=jsondecode(fileread(fullfile(root,'evidence','scores.json')));
rows=s.cases;N=s.summary.primary_cases;names={'joint_loading','no_loading','raw_second_order'};
errors=zeros(N,3);
for k=1:3
 selected=rows(strcmp({rows.mode},names{k}));errors(:,k)=[selected.heldout_max_relative]';
end
main=rows(strcmp({rows.mode},'joint_loading'));e=jsondecode(fileread(fullfile(root,'evidence','joint_loading','estimates.json')));
f=figure('Visible','off','Position',[50 50 1400 850]);tiledlayout(2,2);
nexttile;bar(1:N,log10(max(errors,1e-15)));grid on;xlabel('工况编号');ylabel('log10(最大留出相对误差)');
title('电路参考面、加载与留出频点验证');legend('去嵌+共同加载','去嵌但忽略加载','AFE直接二阶拟合','Location','northwest');
nexttile;positive=find([main.expected_eligible]);v=zeros(numel(positive),2);
for j=1:numel(positive),k=positive(j);v(j,:)=[main(k).raw_angle_rms_rad main(k).candidate_angle_rms_rad];end
bar(positive,log10(max(v,1e-15)));grid on;xlabel('无噪充分信息工况');ylabel('log10(相对模态角RMS [rad])');
title('独立运动留出｜各自首帧定义增量');legend('原始AFE包络','去嵌并校正度量','Location','best');
nexttile;kappas=[e.cases.kappa];kappas(kappas<=0)=NaN;plot(1:N,kappas,'o-');yline(1e-6,'--');grid on;set(gca,'YScale','log');
xlabel('工况编号');ylabel('共同加载耦合参数κ [模型SI单位]');title('κ由多负载数据估计｜负值不画入对数轴');
nexttile;flags=[[e.cases.geometry_eligible]' [e.cases.electrical_model_compatible]' [e.cases.eligible]'];
imagesc(flags);clim([0 1]);colormap(gca,[.85 .3 .25;.2 .65 .35]);colorbar('Ticks',[0 1],'TickLabels',{'拒绝','满足'});
xticks(1:3);xticklabels({'几何信息','留出模型吻合','允许更新'});yticks(1:N);ylabel('工况编号');title('门控分开显示｜拒绝不是精度通过');
sgtitle('A1：静止压电端口辨识｜合成参数与独立夹持电路校准｜非硬件验收');
exportgraphics(f,fullfile(root,'evidence','a1_dashboard.png'),'Resolution',140);close(f);
end
