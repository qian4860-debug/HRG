function stress_summary(T,root)
% 各工况使用相同门限；绿色通过、红色失败。
folder=fullfile(root,'evidence');fig=figure('Visible','off','Position',[80 80 1500 900]);tiledlayout(2,2);
nexttile;b=bar(T.angle_RMS_deg,'FaceColor','flat');colors=repmat([.8 .2 .15],height(T),1);colors(T.passed==1,:)=repmat([.15 .6 .3],sum(T.passed==1),1);b.CData=colors;yline(.1,'r--');set(gca,'YScale','log','XTick',1:height(T),'XTickLabel',T.id,'XTickLabelRotation',55);ylim([min(T.angle_RMS_deg)/2,max(T.angle_RMS_deg)*2]);ylabel('机体角度RMS [°]');title('固定门限0.1°；颜色按全部指标判定');grid on
nexttile;semilogy(1:height(T),T.quadrature_RMS,'o-',1:height(T),T.PLL_RMS,'s-');yline(1e-3,'r--');set(gca,'XTick',1:height(T),'XTickLabel',T.id,'XTickLabelRotation',55);legend('正交残差','锁相检测残差');title('固定门限1e-3');grid on
nexttile;bar(100*(T.energy_mean-1));set(gca,'XTick',1:height(T),'XTickLabel',T.id,'XTickLabelRotation',55);ylabel('平均能量误差 [%]');title('门限±5%；纵轴自动放大微小误差');grid on
nexttile;axis off;text(0,.95,sprintf('合成非理想工况：%d\n通过：%d；未通过：%d\n全部工况保持相同评分定义与门限。\n噪声5μV包含3个独立种子。\n标定只改控制器，plant真值保持不变。\n短时离散点不证明完整工作范围或ARW。',height(T),sum(T.passed),sum(~T.passed)),'VerticalAlignment','top','FontSize',14);
exportgraphics(fig,fullfile(folder,'comparison.png'),'Resolution',140);close(fig);
fid=fopen(fullfile(folder,'index.html'),'w','n','UTF-8');fprintf(fid,'<!doctype html><meta charset="utf-8"><title>非理想工况验证</title><style>body{font:17px sans-serif;margin:30px}table{border-collapse:collapse}td,th{padding:8px;border:1px solid #ccc}img{max-width:100%%}</style><h1>同面板非理想工况验证</h1><p>固定门限，源中心评分，后40%%有效帧；合成参数，不代表硬件认证。点击工况查看相同面板及中文报告。</p><img src="comparison.png"><table><tr><th>工况</th><th>结果</th><th>角度RMS[°]</th><th>正交RMS</th><th>锁相残差RMS</th><th>未满足项</th></tr>');
for k=1:height(T)
 s='通过';if ~T.passed(k),s='未通过';end
 fprintf(fid,'<tr><td><a href="%s/quality_report.html">%s</a></td><td>%s</td><td>%.7g</td><td>%.5g</td><td>%.5g</td><td>%s</td></tr>',T.id{k},T.label{k},s,T.angle_RMS_deg(k),T.quadrature_RMS(k),T.PLL_RMS(k),T.failed_checks{k});
end
fprintf(fid,'</table>');fclose(fid);
end
