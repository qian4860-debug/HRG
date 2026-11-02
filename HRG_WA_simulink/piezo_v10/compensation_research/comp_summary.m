function comp_summary(T,root)
f=figure('Visible','off','Position',[60 60 1600 800]);tiledlayout(1,2);
nexttile;semilogy(T.before_angle,'o-');hold on;semilogy(T.after_angle,'s-');yline(.1,'r--');grid on;set(gca,'XTick',1:height(T),'XTickLabel',T.id,'XTickLabelRotation',60);legend('补偿前','补偿后','门限');ylabel('机体角度RMS [°]');title('相同参数、同一评分门限，无真值偏置拟合');
nexttile;semilogy(1:height(T),T.quadrature,'o-',1:height(T),T.PLL,'s-');yline(1e-3,'r--');grid on;set(gca,'XTick',1:height(T),'XTickLabel',T.id,'XTickLabelRotation',60);legend('正交残差','锁相检测残差');title(sprintf('补偿后质量通过 %d/%d',sum(T.passed),height(T)));
exportgraphics(f,fullfile(root,'evidence','comparison.png'),'Resolution',140);close(f);
fid=fopen(fullfile(root,'evidence','index.html'),'w','n','UTF-8');fprintf(fid,'<!doctype html><meta charset="utf-8"><title>补偿研究</title><h1>补偿前后：固定质量门限</h1><p>独立合成标定/张量参考，不是硬件自动辨识。点击工况查看同一质量面板。</p><img src="comparison.png" style="max-width:100%%"><table border="1"><tr><th>工况</th><th>之前角度RMS</th><th>之后角度RMS</th><th>通过</th><th>未通过项</th></tr>');
for k=1:height(T),fprintf(fid,'<tr><td><a href="%s/quality_report.html">%s</a></td><td>%.7g</td><td>%.7g</td><td>%d</td><td>%s</td></tr>',T.id{k},T.label{k},T.before_angle(k),T.after_angle(k),T.passed(k),T.failed_checks{k});end
fprintf(fid,'</table>');fclose(fid);
end
