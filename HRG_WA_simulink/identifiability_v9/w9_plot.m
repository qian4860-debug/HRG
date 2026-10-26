function w9_plot()
r=fileparts(mfilename('fullpath'));e=fullfile(r,'evidence');
core=jsondecode(fileread(fullfile(e,'core_study.json')));rf=jsondecode(fileread(fullfile(e,'rf_study.json')));
f=figure('Visible','off','Position',[50 50 1400 900]);
d=readmatrix(fullfile(e,'envelope_+80_1.csv'));t=d(:,1);angle=@(x)unwrap(angleComplex(x))/4;
truth=angle(d(:,2:3));raw=angle(d(:,4:5));cal=angle(d(:,6:7));
subplot(2,2,1);plot(t,1e6*((raw-raw(1))-(truth-truth(1))),t,1e6*((cal-cal(1))-(truth-truth(1))));
grid on;xlabel('Time (s)');ylabel('Physical pattern angle error (urad)');legend('Uncalibrated','Frozen reference calibration');
title('Held-out envelope: rotating pattern, no AGC');
cases=core.envelopeCases([core.envelopeCases.stepS]==.005);rate=[cases.rateDegS];
subplot(2,2,2);plot(rate,1e3*arrayfun(@(x)x.raw.ds,cases),'o-',rate,1e3*arrayfun(@(x)x.corrected.ds,cases),'s-');
yline(1e3*core.trueDampingCoefficients(3),'--');grid on;
xlabel('External rate (deg/s)');ylabel('Fitted sine damping coefficient (10^{-3}/s)');
legend('Uncalibrated','Calibrated','Physical coefficient','Location','best');
title('Small residual alone does not identify the right mechanism');
for k=0:1
 n=readmatrix(fullfile(e,sprintf('rf_%d_navigation.csv',k)));epoch=rf.cases(k+1).directAngle.epochS;
 first=find(n(:,4)>.5,1);err=(n(:,2)-n(first,2))*180/pi-80*(n(:,1)-epoch);
 subplot(2,2,3);hold on;use=n(:,1)>=epoch;plot(n(use,1),err(use),'LineWidth',1.2);
 if k==1
  subplot(2,2,4);use=n(:,1)>=.5;plot(n(use,1),err(use)*pi/180*1e6,'LineWidth',1.2);grid on;
  xlabel('Time (s)');ylabel('Calibrated angle error (urad)');title('RF held-out window; noise disabled');
 end
end
subplot(2,2,3);grid on;xlabel('Time (s)');ylabel('Relative inertial angle error (deg)');legend('Calibration off','Frozen calibration on','Location','best');
title('Actual RF: same configured head, ADC/DAC and controller');
sgtitle('V9 causal experiments: synthetic independent reference, no hardware or stochastic-noise claim');
exportgraphics(f,fullfile(e,'identification_and_rf.png'),'Resolution',150);close(f);
f=figure('Visible','off','Position',[50 50 1300 550]);
cases=core.biasCases;V=core.profile.reference_bias_v;h=core.profile.carrier_reference_step_s;
mode={'bare','reference','double_count'};split=zeros(3,2);error=zeros(1,2);
for j=1:3
 for k=1:2
  c=cases([cases.voltageV]==V&strcmp({cases.mode},mode{j})&[cases.stepS]==h/2^(k-1));
  split(j,k)=1e3*abs(diff(c.frequencyHz));
  if j==1,error(k)=abs(c.frequencyHz(1)-5000);end
 end
end
subplot(1,2,1);bar(split);set(gca,'XTickLabel',{'Bare + full electrostatic','Reference + residual','Double counted'});
ylabel('Split at reference voltage (mHz)');grid on;legend('h=1.25 us','h=.625 us','Location','best');
title('A physical bookkeeping fault survives refinement');
subplot(1,2,2);loglog([h h/2]*1e6,error*1e6,'o-','LineWidth',1.3);grid on;
xlabel('Integration step (us)');ylabel('Common frequency error (uHz)');title(sprintf('Step halving reduces error %.3g times',error(1)/error(2)));
sgtitle('Native Simulink carrier mechanics: correctly equivalent representations and a deliberate fault');
exportgraphics(f,fullfile(e,'bias_and_convergence.png'),'Resolution',150);close(f);
end

function a=angleComplex(x)
a=atan2(2*x(:,1).*x(:,2),x(:,1).^2-x(:,2).^2);
end
