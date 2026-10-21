function report = run_wa_validation()
% Scoreboards use analytic invariants, independent expm, and carrier ODE.
root=fileparts(mfilename('fullpath'));addpath(root);
if ~isfile(fullfile(root,'hrg_wa_envelope.slx')),build_wa_models();end
load_system(fullfile(root,'hrg_wa_envelope.slx'));
load_system(fullfile(root,'hrg_wa_carrier.slx'));
report=struct('matlab',version,'model','WA abstraction v1','tests',[]);
tests=struct('name',{},'metric',{},'limit',{},'pass',{});
% Exact energy decay and stationary azimuth, with no feedback.
p=ideal();p.loopEnable=0;p.omega=0;p.duration=10;p.gamma=.05;
o=runenv(p);t=o.iqlog.Time;E=o.iqlog.Data(:,5);
check('free_decay_relative_error',max(abs(E./(p.initialEnergy*exp(-2*p.gamma*t))-1)),1e-8);
check('zero_input_angle_rad',max(abs(o.navlog.Data(:,1))),1e-8);
% Several four-angle wraps in both directions. No plant truth is used by nav.
for rate=[-300 300]
    p=ideal();p.loopEnable=0;p.omega=rate*pi/180;p.duration=5;
    o=runenv(p);n=o.navlog.Data;tn=o.navlog.Time;
    check(sprintf('ideal_%+d_angle_rad',rate),max(abs(n(:,1)-p.omega*tn)),1e-7);
    check(sprintf('ideal_%+d_rate_rad_s',rate),abs(n(end,2)-p.omega),1e-7);
end
% Damping and stiffness axes are physically rotated by FOUR rim angles.
p=ideal();p.loopEnable=0;p.omega=.4;p.splitHz=.04;p.dgamma=.003;p.duration=4;
o=runenv(p);z0=wa_initial(p);
Ad=axisTensor(p.dampingAxis);Ak=axisTensor(p.stiffnessAxis);
A=-p.gamma*eye(2)-.5*p.dgamma*Ad-1i*pi*p.splitHz*Ak-2*p.bryan*p.omega*[0 -1;1 0];
expected=expm(A*p.duration)*z0;
actual=o.zlog.Data(end,1:2).'+1i*o.zlog.Data(end,3:4).';
check('split_damping_expm_state_error',max(abs(actual-expected)),1e-8);
% Three loop closure including PLL detuning, plus recovery from ellipse.
p=ideal();p.initialQuadRatio=.15;p.detuningHz=.2;p.duration=20;
o=runenv(p);iq=o.iqlog.Data;c=o.ctrllog.Data;
check('closed_energy_error',abs(iq(end,5)-1),.005);
check('closed_quadrature_ratio',abs(iq(end,6)/iq(end,5)),.002);
check('pll_frequency_error_hz',abs(c(end,3)-p.detuningHz),.005);
check('closed_rate_error_deg_s',abs(o.navlog.Data(end,2)-p.omega)*180/pi,.02);
closed=o;
% Virtual precession is an actuator injection, removed only at navigation.
p=ideal();p.omega=0;p.virtualRate=120*pi/180;p.duration=6;
o=runenv(p);
check('virtual_cancel_angle_rad',abs(o.navlog.Data(end,1)),1e-7);
check('virtual_cancel_rate_rad_s',abs(o.navlog.Data(end,2)),1e-7);
% Temperature shifts resonance, tested through measured PLL correction.
p=ideal();p.temperature=26;p.duration=20;
o=runenv(p);target=p.f0*p.temperatureCoeff;
check('temperature_pll_error_hz',abs(o.ctrllog.Data(end,3)-target),.005);
% Gain mismatch must visibly change angle: a deliberately nonideal case.
p=ideal();p.loopEnable=0;p.detect=diag([1.05 .95]);p.duration=3;
o=runenv(p);err=max(abs(o.navlog.Data(:,1)-p.omega*o.navlog.Time));
check('gain_error_observable_inverse_rad',1/max(err,eps),1/(.1*pi/180));
% Invalid measurements freeze navigation and re-anchor without a jump.
p=ideal();pv=wa_pack(p);s=zeros(4,1);d=wa_initial(p);
meas=wa_measure([real(d);imag(d);0;pv]);
y=wa_nav_step([meas;s;0;pv]);s=y(1:4);
bad=meas;bad(5)=0;bad(7:8)=0;
y=wa_nav_step([bad;s;0;pv]);
assert(y(7)==0 && y(1)==s(1) && y(2)==s(2),'Dropout did not freeze state');
s=y(1:4);meas(7:8)=[cos(1.2);sin(1.2)];
y=wa_nav_step([meas;s;0;pv]);check('dropout_reanchor_jump_rad',abs(y(5)-s(2)),eps);
% Carrier reference with constant rate: analytic 4-state matrix exponential.
p=ideal();p.loopEnable=0;p.duration=.02;p.fullStep=1/(100*p.f0);p.splitHz=.04;
wa_setup(p);o=sim('hrg_wa_carrier','StopTime',num2str(p.duration,17));
w=2*pi*p.f0;J=[0 -1;1 0];
D=2*p.gamma*eye(2);K=w*w*eye(2)-w*2*pi*p.splitHz*axisTensor(p.stiffnessAxis);
Af=[zeros(2) eye(2);-K -D-4*p.bryan*p.omega*J];
z0=wa_initial(p);x0=[real(z0);-w*imag(z0)];
xexact=expm(Af*p.duration)*x0;
x=o.carrierlog.Data(end,:).';
% Compare displacement and velocity/w0 in the same displacement units.
scale=[1;1;1/w;1/w];
check('carrier_matrix_expm_normalized_error',norm(scale.*(x-xexact))/norm(scale.*xexact),2e-4);
% Reconstruct rotating envelope from independently simulated carrier states.
tc=o.carrierlog.Time;xc=o.carrierlog.Data;
zc=(xc(:,1:2)-1i*xc(:,3:4)/w).*exp(-1i*w*tc);
A=-p.gamma*eye(2)-1i*pi*p.splitHz*axisTensor(p.stiffnessAxis)-2*p.bryan*p.omega*J;
ze=expm(A*p.duration)*z0;
check('carrier_vs_envelope_error',norm(zc(end,:).'-ze)/norm(ze),.002);
% A wrong Coriolis sign really changes the simulated navigation output.
p=ideal();p.loopEnable=0;p.duration=2;
o=runenv(p);wrong=p;wrong.bryan=.30;pv=wa_pack(wrong);state=zeros(4,1);
for k=1:size(o.iqlog.Data,1)
    result=wa_nav_step([o.iqlog.Data(k,:).';state;0;pv]);state=result(1:4);
end
negativeError=abs(result(5)-p.omega*p.duration);
check('wrong_bryan_negative_control_missed',double(negativeError<.01),0);
% Smooth direction reversal: oracle integrates the actual table analytically.
p=ideal();p.loopEnable=0;p.duration=4;wa_setup(p);
t=(0:p.Ts:p.duration).';rate=100*pi/180*sin(pi*t);
assignin('base','wa_input',[t rate 25+zeros(size(t)) zeros(size(t))]);
o=sim('hrg_wa_envelope','StopTime','4');
oracle=cumtrapz(t,rate);
check('rate_reversal_angle_error_rad',max(abs(o.navlog.Data(:,1)-oracle)),1e-6);
% The actual shared head profile includes split/damping/channel errors.
p=wa_parameters();p.duration=16;o=runenv(p);
tail=o.iqlog.Time>12;
check('nominal_profile_energy_error',max(abs(o.iqlog.Data(tail,5)-p.energyTarget)),.02);
check('nominal_profile_quadrature_ratio',max(abs(o.iqlog.Data(tail,6)./o.iqlog.Data(tail,5))),.03);
check('nominal_profile_rate_error_deg_s',max(abs(o.navlog.Data(tail,2)-p.omega))*180/pi,1);
report.tests=tests;report.pass=all([tests.pass]);
report.referenceNote='Analytic/expm checks are independent of plant RHS; all tolerances fixed in source.';
outdir=fullfile(root,'evidence');if ~isfolder(outdir),mkdir(outdir);end
fid=fopen(fullfile(outdir,'validation_results.json'),'w');fwrite(fid,jsonencode(report,PrettyPrint=true),'char');fclose(fid);
% Text vectors are intentionally versioned, unlike disposable .mat outputs.
tableout=table(closed.iqlog.Time,closed.iqlog.Data(:,5),closed.iqlog.Data(:,6),closed.ctrllog.Data(:,3), ...
 'VariableNames',{'time_s','energy','quadrature','pll_hz'});
writetable(tableout(1:20:end,:),fullfile(outdir,'closed_loop_trace.csv'));
fig=figure('Visible','off','Position',[50 50 1000 650]);
subplot(2,2,1);plot(closed.iqlog.Time,closed.iqlog.Data(:,5));grid on;ylabel('Normalized energy');xlabel('Time (s)');
subplot(2,2,2);plot(closed.iqlog.Time,closed.iqlog.Data(:,6));grid on;ylabel('Quadrature invariant');xlabel('Time (s)');
subplot(2,2,3);plot(closed.ctrllog.Time,closed.ctrllog.Data(:,3));grid on;ylabel('PLL correction (Hz)');xlabel('Time (s)');
subplot(2,2,4);plot(closed.navlog.Time,closed.navlog.Data(:,2)*180/pi);grid on;ylabel('Estimated rate (deg/s)');xlabel('Time (s)');
exportgraphics(fig,fullfile(root,'validation_plot.png'));close(fig);
assert(report.pass,'Behavioral scoreboard failed');
fprintf('PASS: %d behavioral scoreboard checks.\n',numel(tests));

    function check(name,metric,limit)
        passed=isfinite(metric)&&metric<=limit;
        tests(end+1)=struct('name',name,'metric',metric,'limit',limit,'pass',passed);
        fprintf('%s: %.12g <= %.12g : %d\n',name,metric,limit,passed);
    end
end
function p=ideal()
p=wa_parameters();
p.dgamma=0;p.splitHz=0;p.duffingHz=0;p.detect=eye(2);p.detectPhase=[0;0];p.drive=eye(2);
end
function o=runenv(p)
wa_setup(p);o=sim('hrg_wa_envelope','StopTime',num2str(p.duration,17));
end
function A=axisTensor(theta)
A=[cos(4*theta) sin(4*theta);sin(4*theta) -cos(4*theta)];
end
