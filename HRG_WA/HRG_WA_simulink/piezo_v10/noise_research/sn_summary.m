function sn_summary(T,root)
f=figure('Visible','off','Position',[50 50 1400 850]);tiledlayout(2,2);
nexttile;semilogy(1:height(T),T.before_angle,'o-',1:height(T),T.after_angle,'s-',1:height(T),T.physical_angle,'^-');yline(.1,'r--');legend('旧闭环','因果估计输出','机械真值误差');ylabel('角度RMS [°]');grid on
nexttile;semilogy(1:height(T),T.quadrature,'o-',1:height(T),T.PLL,'s-');yline(1e-3,'r--');legend('正交残差','锁相检测残差');grid on
nexttile;bar(T.passed);ylim([0 1.2]);title('原质量门限且机械真值同时通过');grid on
for k=1:3,nexttile(k);set(gca,'XTick',1:height(T),'XTickLabel',T.id,'XTickLabelRotation',45);end
nexttile(4);axis off;text(0,.95,sprintf('32帧因果端点估计，无未来数据。\n当前源中心时刻，一阶信号零偏移。\n原始IQ仍保留，机械真值另行检查。\n所有补偿仍依赖独立校准参考。\n通过%d/%d；不代表真实表头无参考自校准。',sum(T.passed),height(T)),'VerticalAlignment','top','FontSize',13);
exportgraphics(f,fullfile(root,'evidence','comparison.png'),'Resolution',140);close(f);
fid=fopen(fullfile(root,'evidence','index.html'),'w','n','UTF-8');fprintf(fid,'<!doctype html><meta charset="utf-8"><h1>500μV强噪声研究</h1><p>同门限；原始、估计、机械真值区分。校准参考条件不变。</p><img src="comparison.png" style="max-width:100%%"><table border="1"><tr><th>工况</th><th>之前RMS</th><th>估计RMS</th><th>机械RMS</th><th>通过</th></tr>');
for k=1:height(T),fprintf(fid,'<tr><td><a href="%s/quality_report.html">%s</a></td><td>%.6g</td><td>%.6g</td><td>%.6g</td><td>%d</td></tr>',T.id{k},T.id{k},T.before_angle(k),T.after_angle(k),T.physical_angle(k),T.passed(k));end
fprintf(fid,'</table>');fclose(fid);
end
