function w7_plot_results()
r=fileparts(mfilename('fullpath'));folder=fullfile(r,'evidence');
piData=readmatrix(fullfile(folder,'pi_envelope.csv'));pirData=readmatrix(fullfile(folder,'pir_envelope.csv'));
f=figure('Visible','off','Position',[100 100 1150 780]);tiledlayout(3,1);
sel=piData(:,1)>=20;selR=pirData(:,1)>=20;
nexttile;plot(piData(sel,1),100*(piData(sel,2)-1),pirData(selR,1),100*(pirData(selR,2)-1));grid on;
ylabel('E error (%)');legend('PI','PIR');title('Actual 20-40 s comparison; fixed gains, measured harmonic tuning');
nexttile;plot(piData(sel,1),piData(sel,3),pirData(selR,1),pirData(selR,3));grid on;ylabel('Q / E');legend('PI','PIR');
nexttile;x=readmatrix(fullfile(folder,'pir_controller.csv'));plot(x(:,1),x(:,4)/(2*pi));grid on;ylabel('Measured harmonic (Hz)');xlabel('Time (s)');
exportgraphics(f,fullfile(folder,'pi_pir.png'),'Resolution',150);close(f);
f=figure('Visible','off','Position',[100 100 1150 680]);tiledlayout(2,1);
x=readmatrix(fullfile(folder,'zero_state_startup_iq.csv'));E=sum(x(:,2:5).^2,2);
mech=readmatrix(fullfile(folder,'zero_state_startup_mechanical_energy.csv'));
nexttile;plot(x(:,1),E,mech(:,1),mech(:,2));hold on;yline(1,'--');grid on;legend('Calibrated IQ E','Mechanical E','Target');ylabel('Normalized energy');title('Actual zero-state carrier startup (not a precharged capture)');
nexttile;x=readmatrix(fullfile(folder,'zero_state_startup_controller.csv'));stairs(x(:,1),x(:,2));grid on;ylabel('State: 0 excite, 1 maintain, 2 timeout');xlabel('Time (s)');
exportgraphics(f,fullfile(folder,'startup.png'),'Resolution',150);close(f);
f=figure('Visible','off','Position',[100 100 1150 800]);tiledlayout(3,1);
x=readmatrix(fullfile(folder,'switched_v7_timing_tail.csv'));epoch=x(1,1);
nexttile;stairs((x(:,1)-epoch)*1e3,x(:,2:5));grid on;legend('Drive','Read','Unload','Valid');ylabel('Gate');title('Actual switched carrier, last eight carrier cycles');
x=readmatrix(fullfile(folder,'switched_v7_electrode_voltage_tail.csv'));
nexttile;plot((x(:,1)-epoch)*1e3,x(:,2:3));grid on;ylabel('Electrode V');
x=readmatrix(fullfile(folder,'switched_v7_acquisition_tail.csv'));a=readmatrix(fullfile(folder,'switched_adc_tail.csv'));
nexttile;plot((x(:,1)-epoch)*1e3,x(:,2));hold on;stairs((a(:,1)-epoch)*1e3,a(:,2));grid on;legend('Finite acquisition','ADC with latency');ylabel('Readout V');xlabel('Time from tail start (ms)');
exportgraphics(f,fullfile(folder,'tdm.png'),'Resolution',150);close(f);
f=figure('Visible','off','Position',[100 100 1000 600]);x=readmatrix(fullfile(folder,'cv_noise_increment_psd.csv'));
semilogy(x(2:end,1),sqrt(x(2:end,2)));grid on;xlabel('Frequency (Hz)');ylabel('Rate increment ASD (rad/s/sqrt(Hz))');
title('Short paired CV noise response; insufficient duration for ARW or Allan bias');
exportgraphics(f,fullfile(folder,'noise_increment.png'),'Resolution',150);close(f);
end
