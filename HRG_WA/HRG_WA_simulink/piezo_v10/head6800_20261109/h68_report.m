function h68_report
here=fileparts(mfilename('fullpath'));addpath(here);
for mode={'continuous','tdm_shared'}
 m=['hrg_6800_' mode{1}];load_system(fullfile(here,'models',[m '.slx']));
 cleanup=onCleanup(@() close_system(m,0));
 set_param(m,'PaperOrientation','landscape');
 print(['-s' m],'-dpng','-r120',fullfile(here,[m '_blocks.png']));
 c=h68_config(mode{1},.5,struct('duration',.004,'log_decimation',10));
 assignin(get_param(m,'ModelWorkspace'),'c',c);out=sim(m);y=out.trace;
 t=(0:size(y,1)-1)'*c.logDecimation*c.Ts*1e6;
 fig=figure('Visible','off','Position',[80 80 1200 800]);
 tiledlayout(4,1,'TileSpacing','compact');
 nexttile;stairs(t,y(:,2:4),'LineWidth',1);ylabel('Switch state');legend('Drive','Sense connected','Valid ADC');ylim([-.1 1.2]);grid on;
 title([strrep(mode{1},'_',' ') ' | 6800 Hz | ADC ' num2str(c.p.fs/1e6) ' MSPS']);
 nexttile;plot(t,y(:,18:19));ylabel('Electrode (V)');legend('X','Y');grid on;
 nexttile;plot(t,y(:,5:6));ylabel('ADC (V)');grid on;
 nexttile;plot(t,y(:,7:8));ylabel('DAC command (V)');xlabel('Time (us)');grid on;
 exportgraphics(fig,fullfile(here,[m '_timing.png']),'Resolution',120);close(fig);
 clear cleanup
end
end
