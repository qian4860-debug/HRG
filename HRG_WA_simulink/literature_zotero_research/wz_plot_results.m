function wz_plot_results()
r=fileparts(mfilename('fullpath'));e=fullfile(r,'evidence');
report=jsondecode(fileread(fullfile(e,'carrier_study.json')));
direct=readmatrix(fullfile(e,'carrier_direct_navigation.csv'));
old=readmatrix(fullfile(e,'carrier_legacy_navigation.csv'));
epoch=report.directAngle.referenceEpochS;
[~,id]=min(abs(direct(:,1)-epoch));[~,io]=min(abs(old(:,1)-epoch));
ed=(direct(:,2)-direct(id,2))*180/pi-80*(direct(:,1)-epoch);
eo=(old(:,2)-old(io,2))*180/pi-80*(old(:,1)-epoch);
f=figure('Visible','off','Position',[80 80 1300 850]);
subplot(2,2,1);use=direct(:,1)>=epoch;
plot(old(use,1),eo(use),direct(use,1),ed(use),'LineWidth',1.2);grid on;
xlabel('Time (s)');ylabel('Relative angle error (deg)');
legend('Filtered rate integrated','Direct geometric angle','Location','best');
title('Same physical carrier and exact 22-bit IQ codes');
subplot(2,2,2);use=direct(:,1)>=.5;
plot(direct(use,1),ed(use),'LineWidth',1.2);grid on;
xlabel('Time (s)');ylabel('Direct angle error (deg)');
title(sprintf('Acceptance window: RMS %.6g deg',report.directAngle.rmsDeg));
iq=readmatrix(fullfile(e,'carrier_iq.csv'));
subplot(2,2,3);plot(iq(:,1),iq(:,2:5),'LineWidth',1);grid on;
xlabel('Time (s)');ylabel('Normalized IQ');legend('I_x','I_y','Q_x','Q_y','Location','best');
subplot(2,2,4);q=readmatrix(fullfile(e,'coherent_adc_azimuth.csv'));
plot(q(:,1)*180/pi,q(:,2)*1e3);grid on;
xlabel('Physical pattern angle (deg)');ylabel('Isolated ADC angle error (mrad)');
title('10-bit coherent ADC oracle; not the closed-loop run');
sgtitle('Research evidence: synthetic calibration; noise disabled; no ARW/Allan claim');
exportgraphics(f,fullfile(e,'zotero_model_comparison.png'),'Resolution',150);close(f);
end
