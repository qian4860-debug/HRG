function report=h68_physics_checks
here=fileparts(mfilename('fullpath'));c=h68_config('continuous',0);p=c.p;
[~,~,~,A]=pcn_plant(p);M=A(1:4,1:4);ev=eig(M);ev=ev(imag(ev)>0);
f=sort(imag(ev)/(2*pi));analytic=sqrt((2*pi*c.head.f_modes_Hz).^2-p.gamma_intrinsic^2)/(2*pi);
assert(max(abs(f-analytic'))<1e-8);
R=[cos(p.stiffness_axis) -sin(p.stiffness_axis);sin(p.stiffness_axis) cos(p.stiffness_axis)];
x0=[R(:,1);zeros(2,1)];x1=expm(M)*x0;
q0=R(:,1)'*x0(1:2);v0=R(:,1)'*x0(3:4);q1=R(:,1)'*x1(1:2);v1=R(:,1)'*x1(3:4);
wd=2*pi*analytic(1);a0=hypot(q0,(v0+p.gamma_intrinsic*q0)/wd);a1=hypot(q1,(v1+p.gamma_intrinsic*q1)/wd);
assert(abs(a1/a0-exp(-p.gamma_intrinsic))<1e-9);
c=h68_config('tdm_shared',.5);x=c.Ad*c.x0+c.Bd*[.2;-.1];
shared=c.electrode*x;driver=c.p.drive_matrix*x(5:6);assert(max(abs(shared-driver))<1e-12);
report=struct('damped_modes_Hz',f','analytic_damped_modes_Hz',analytic, ...
 'one_second_amplitude_ratio',a1/a0,'analytic_ratio',exp(-p.gamma_intrinsic), ...
 'shared_electrode_driver_delta_V',max(abs(shared-driver)),'passed',true);
% Tiny-step independent KCL check of amplified drive feedthrough.
cc=h68_config('continuous',0,struct('Cds',1e-12,'fs',6800*1e6));
dx=cc.Bd*[.1;0];vs=cc.electrode*dx;
expected=(cc.p.Cds/cc.p.Cs)*cc.p.pre_gain*cc.p.power_gain*.1/cc.p.driver_tau(1)*cc.Ts;
report.feedthrough_first_step_ratio=vs(1)/expected;
assert(abs(report.feedthrough_first_step_ratio-1)<.001);
fid=fopen(fullfile(here,'physics_checks.json'),'w','n','UTF-8');fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));fclose(fid);
end
