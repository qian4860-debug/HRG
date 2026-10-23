function w8_plot_results()
r=fileparts(mfilename('fullpath'));e=fullfile(r,'evidence');
addpath(fullfile(fileparts(r),'layered'));
wl_write_json(fullfile(e,'runtime_versions.json'),struct('MATLAB',ver('MATLAB'), ...
 'Simulink',ver('Simulink'),'DSP_System_Toolbox',ver('dsp'),'platform',computer));
groups={'linear_matrix','diagonal_cubic','calibration_drift'};
f=figure('Visible','off','Position',[80 80 1400 850]);
for j=1:3
 off=readmatrix(fullfile(e,[groups{j} '_0.csv']));on=readmatrix(fullfile(e,[groups{j} '_1.csv']));
 useOff=off(:,1)>=1;useOn=on(:,1)>=1;
 subplot(2,3,j);plot(off(useOff,1),off(useOff,2),on(useOn,1),on(useOn,2),'LineWidth',1.2);grid on;
 xlabel('Time (s)');ylabel('Angle error (deg)');title(strrep(groups{j},'_',' '));
 if j==1,legend('Uncalibrated','Frozen calibration','Location','best');end
 subplot(2,3,j+3);plot(off(:,1),off(:,4)-1,on(:,1),on(:,4)-1,'LineWidth',1.2);grid on;
 xlabel('Time (s)');ylabel('Physical normalized energy - 1');
end
sgtitle('8 s envelope; angle panels show acceptance window 1-8 s; synthetic fixture; noise disabled');
exportgraphics(f,fullfile(e,'envelope_comparison.png'),'Resolution',150);close(f);
f=figure('Visible','off','Position',[80 80 1250 800]);labels={'Original initialization','Warmup only','Warmup + calibration'};
report=jsondecode(fileread(fullfile(e,'studies.json')));
for k=0:2
 nav=readmatrix(fullfile(e,sprintf('hrg_wa_v8_carrier_%d_navigation.csv',k)));
 iq=readmatrix(fullfile(e,sprintf('hrg_wa_v8_carrier_%d_iq.csv',k)));
 epoch=report.carrierCases(k+1).metrics.angle.referenceEpochS;
 subplot(2,1,1);hold on;use=nav(:,1)>=epoch;
 plot(nav(use,1),nav(use,2)*180/pi-80*(nav(use,1)-epoch),'LineWidth',1.1);
 subplot(2,1,2);hold on;plot(iq(:,1),sum(iq(:,2:5).^2,2),'LineWidth',1.1);
end
subplot(2,1,1);grid on;xlabel('Time (s)');ylabel('Navigation error (deg)');legend(labels,'Location','best');
subplot(2,1,2);grid on;xlabel('Time (s)');ylabel('Observed normalized energy');ylim([0 1.5]);
sgtitle('1 s RF carrier; actual ADC/DAC and capacitor; noise disabled; early reference retained');
exportgraphics(f,fullfile(e,'carrier_comparison.png'),'Resolution',150);close(f);
f=figure('Visible','off','Position',[80 80 1250 500]);
a=readmatrix(fullfile(e,'hrg_wa_v8_carrier_2_adc_tail.csv'));
d=readmatrix(fullfile(e,'hrg_wa_v8_carrier_2_driver_tail.csv'));
subplot(1,2,1);plot((a(:,1)-a(1,1))*1e3,a(:,2:3));grid on;xlabel('Local time (ms)');ylabel('ADC voltage (V)');title('Final eight carrier cycles');
subplot(1,2,2);plot((d(:,1)-d(1,1))*1e3,d(:,2:3));grid on;xlabel('Local time (ms)');ylabel('Driver voltage (V)');
exportgraphics(f,fullfile(e,'carrier_waveforms.png'),'Resolution',150);close(f);
end
