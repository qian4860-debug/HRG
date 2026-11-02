function report=quality_report(out,p,visible)
% 源中心评分与中文可视化；真值只用于本函数的离线比较。
root=quality_setup;if nargin<3,visible=true;end
if isa(out,'Simulink.SimulationOutput')
 r=struct('t',out.p103_diagnostics.Time,'d',out.p103_diagnostics.Data,'u',out.p103_dac.Data);
else,r=out;end
[metrics,frame]=pcn_metrics(r,p);d=r.d;ix=find(d(:,9)>0 & [true;diff(d(:,9))~=0]);
assert(~isempty(ix),'quality:frames','No complete demodulation frame available');f=d(ix,:);t=f(:,12);
y=zeros(numel(ix),11);for k=1:numel(ix),y(k,:)=quality_values(f(k,:)',p)';end
valid=logical(y(:,9));hold=valid&t>.6*p.duration;
angle=NaN(size(t));if ~isempty(p.B),angle=-frame.error_rad/p.B*180/pi;end
qRMS=NaN;quadRMS=NaN;pllRMS=NaN;energyMean=NaN;
if any(hold)
 qRMS=sqrt(mean(sum(y(hold,2:3).^2,2)));quadRMS=sqrt(mean(y(hold,4).^2));pllRMS=sqrt(mean(y(hold,5).^2));energyMean=mean(y(hold,1));
end
expected=[p.Tc-p.Ts,(p.Tc-p.Ts)/2,p.Ts]*1e6;timingError=max(abs(y(:,6:8)-expected),[],'all');
% 工程演示门限，在报告前声明；不是制造商指标。
checks=struct('valid_fraction',mean(valid)>=.95,'normalized_energy',abs(energyMean-1)<.05,...
 'quadrature',quadRMS<1e-3,'PLL_detector',pllRMS<1e-3,'timestamps',timingError<1e-6,...
 'body_angle',isfinite(metrics.angle_rms_deg)&&metrics.angle_rms_deg<.1,'no_DAC_clip',metrics.dac_clip_samples==0);
report=struct('metrics',metrics,'checks',checks,'normalized_Q_RMS',qRMS,'normalized_energy_mean',energyMean,...
 'quadrature_RMS',quadRMS,'PLL_detector_RMS',pllRMS,'timestamp_max_error_us',timingError,...
 'scope','Synthetic fixture; last 40% valid frames; no truth offset/delay fit; no hardware or ARW claim');
passed=all(structfun(@logical,checks));status='通过';if ~passed,status='未通过或数据不足';end
textReport=sprintf(['闭环质量报告：%s\n'...
 '合成仿真，稳态评分区间：t > %.3f s；按源窗口中心，每帧一次。\n'...
 '有效帧：%d / %d（%.2f%%），门限≥95%%\n'...
 '归一化能量均值：%.9f；目标1，允许均值偏差<5%%\n'...
 '归一化Q向量 RMS：%.6g（描述量，未单独设通过门限）\n'...
 '正交残差 2(IxQy-IyQx)/E RMS：%.6g，门限<1e-3\n'...
 '锁相检测残差 (I·Q)/E RMS：%.6g，门限<1e-3（无量纲）\n'...
 '窗口长度 / 中心偏移 / 发布时间差：%.4f / %.4f / %.4f μs\n'...
 '时间戳最大偏差：%.6g μs，门限<1e-6 μs\n'...
 '机体角度误差 RMS：%.8f°，门限<0.1°；未知B时不可评分\n'...
 '建幅时间：%.7f s；DAC截幅累计：%d；输出裕量：%.6f V\n'...
 '不做真值偏置/延迟拟合；无效帧不评分；短记录不估计ARW。\n'...
 '所有通过门限为本工程合成演示门限，不是实际表头验收指标。'],...
 status,.6*p.duration,sum(valid),numel(valid),100*mean(valid),energyMean,qRMS,quadRMS,pllRMS,expected(1),expected(2),expected(3),timingError,metrics.angle_rms_deg,metrics.build_time_s,metrics.dac_clip_samples,metrics.dac_margin_V);
folder=fullfile(root,'evidence');if ~exist(folder,'dir'),mkdir(folder);end
pcn_json(fullfile(folder,'quality_results.json'),report);
tableOut=table(t,valid,y(:,1),y(:,2),y(:,3),y(:,4),y(:,5),y(:,6),y(:,7),y(:,8),angle,...
 'VariableNames',{'source_center_s','valid','energy_normalized','Qx_normalized','Qy_normalized','quadrature','PLL_detector','window_us','center_offset_us','publication_delay_us','body_angle_error_deg'});
writetable(tableOut,fullfile(folder,'quality_frames.csv'));
fid=fopen(fullfile(folder,'quality_report.txt'),'w','n','UTF-8');fprintf(fid,'%s\n',textReport);fclose(fid);
fid=fopen(fullfile(folder,'quality_report.html'),'w','n','UTF-8');fprintf(fid,'<!doctype html><meta charset="utf-8"><title>闭环质量报告</title><style>body{font:18px/1.8 sans-serif;margin:40px}pre{white-space:pre-wrap}img{max-width:100%%}</style><h1>闭环质量报告</h1><pre>%s</pre><img src="quality_dashboard.png">',strrep(strrep(textReport,'<','&lt;'),'>','&gt;'));fclose(fid);
v='off';if visible,v='on';end
fig=figure('Name','闭环质量分项曲线','Visible',v,'Position',[60 60 1450 950]);tiledlayout(3,3,'TileSpacing','compact');
nexttile;stairs(t,double(valid));ylim([-.1 1.1]);title('完整帧有效性');ylabel('0无效 / 1有效');grid on
nexttile;plot(t,y(:,1));yline(1,'--');title('归一化能量 E/q目标²');grid on
nexttile;plot(t,100*(y(:,1)-1));title('能量相对误差 [%]');grid on
nexttile;plot(t,y(:,2:3));title('Q残差 / q目标');legend('Qx','Qy');grid on
nexttile;plot(t,y(:,4));title('正交残差：2(IxQy-IyQx)/E');grid on
nexttile;plot(t,y(:,5));title('锁相检测残差：I·Q/E');grid on
nexttile;plot(t,y(:,6:8));title('时间戳差值 [μs]');legend('end-start','center-start','available-end','Location','best');grid on
nexttile;plot(t,angle);title('机体角度误差 [°]，无真值对齐');grid on
nexttile;axis off;text(0,.95,strjoin({['总体：' status],sprintf('有效率 %.2f%%',100*mean(valid)),sprintf('角度RMS %.6f°',metrics.angle_rms_deg),sprintf('建幅 %.4f s',metrics.build_time_s),'评分：后40%有效帧','合成工况；不代表硬件精度'},newline),'VerticalAlignment','top','FontSize',12,'Interpreter','none');
sgtitle('闭环质量｜各量分开显示｜横轴为源窗口中心时间 [s]');
exportgraphics(fig,fullfile(folder,'quality_dashboard.png'),'Resolution',130);
txt=figure('Name','闭环质量中文数值与判定','Visible',v,'Position',[100 100 1250 650]);
annotation(txt,'textbox',[.03 .03 .94 .94],'String',textReport,'Interpreter','none','FontSize',13,'EdgeColor','none');
exportgraphics(txt,fullfile(folder,'quality_text.png'),'Resolution',130);fprintf('%s\n',textReport);
if ~visible,close(fig);close(txt);end
end
