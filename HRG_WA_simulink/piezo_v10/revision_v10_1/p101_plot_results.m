function p101_plot_results()
root=fileparts(mfilename('fullpath'));ev=fullfile(root,'evidence');
f=figure('Visible','off','Position',[100 100 1100 750]);tiledlayout(2,2);
a=readtable(fullfile(ev,'baseline_frames.csv'));p=jsondecode(fileread(fullfile(ev,'parameters.json')));
nexttile;plot(a.source_center_s,a.error_rad/p.B*180/pi);grid on;xlabel('Window center (s)');ylabel('Body-angle error (deg)');title('Carrier: no truth alignment or offset fitting');
d=readmatrix(fullfile(ev,'low_rate_traces.csv'));
nexttile;plot(d(:,1),d(:,8),d(:,1),d(:,15)-2*d(:,1));grid on;xlabel('Time (s)');ylabel('Corrected modal angle (rad)');legend('Pinned WA','Ideal envelope Cp=2 rad/s','Location','best');title('300 s envelope study; distinct from fast-carrier Cp=0.2');
nexttile;plot(d(:,1),d(:,7),d(:,1),d(:,14));grid on;xlabel('Time (s)');ylabel('Required voltage (V)');title('Synthetic force demand; no head voltage rating');legend('WA','Ideal envelope Cp=2 rad/s','Location','best');
nexttile;axis off;text(0,.85,'Evidence boundaries','FontWeight','bold');
text(0,.65,'40 kHz carrier: 12 SI states, dimensionless ZOH');
text(0,.5,'1 kHz demod: source-center timestamp and validity');
text(0,.35,'Budget: independent 5000-trial Monte Carlo per angle');
text(0,.2,'Thermal fit: separate physical plant and fitted controller');
text(0,.05,'All numerical head values are synthetic fixtures');
exportgraphics(f,fullfile(ev,'validation_overview.png'),'Resolution',150);close(f);
end
