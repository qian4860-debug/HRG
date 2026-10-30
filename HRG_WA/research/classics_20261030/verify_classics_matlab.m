function verify_classics_matlab
% Independent MATLAB matrix-exponential check; no sealed V10 files modified.
here=fileparts(mfilename('fullpath'));J=[0 -1;1 0];p2=[0 -1i;1i 0];
checks=struct('rotation_generator',norm(-1i*p2-J)<1e-14);
w=1000;gam=.02;d=.01;h=.1;k=.55;Omega=.1;td=.2;tw=.4;
anis=@(t)[cos(2*t) sin(2*t);sin(2*t) -cos(2*t)];
G=gam*eye(2)+d/2*anis(td)+k*Omega*J-1i*h/2*anis(tw);
A=[zeros(2) eye(2);-w*w*eye(2)+w*h*anis(tw) -2*gam*eye(2)-d*anis(td)-2*k*Omega*J];
C0=[.8+.1i;.4-.2i];v0=real((-G-1i*w*eye(2))*C0);x0=[real(C0);v0];
t=linspace(0,.2,401);err=zeros(size(t));
for n=1:numel(t)
 full=expm(A*t(n))*x0;
 avg=real(expm(-G*t(n))*C0*exp(-1i*w*t(n)));
 err(n)=norm(full(1:2)-avg);
end
checks.carrier_vs_averaged_small_parameter_fixture=max(err)<1e-3;
% Differentiate quadratic readout using an exact affine propagator, rather
% than reproducing the Python canonical differential equations.
F=[.1-.2i;.03+.04i];C=C0;Cd=-G*C+1i*F/(2*w);
dt=1e-6;aug=[-G 1i*F/(2*w);zeros(1,3)];
pp=expm(aug*dt)*[C;1];pm=expm(-aug*dt)*[C;1];
der=(measure(pp(1:2))-measure(pm(1:2)))/(2*dt);
analytic=[2*real(C'*Cd);2*real(C'*p2*Cd);2*real(C'*diag([1 -1])*Cd);2*real(C'*[0 1;1 0]*Cd);2*(C.'*Cd)];
checks.quadratic_derivative_vs_exact_affine_propagation=max(abs(der-analytic))<1e-8;
b=.001;Kp=6500;Ki=25000;gamPI=.5;poles=eig([-(gamPI+b*Kp) -b*Ki;1 0]);
checks.PI_poles=all(real(poles)<0)&&max(abs(sort(imag(poles))-[-sqrt(12.75);sqrt(12.75)]))<1e-12;
result=struct('matlab',version,'synthetic_only',true,'checks',checks,...
 'max_carrier_averaging_displacement_error_normalized',max(err),...
 'max_quadratic_derivative_error',max(abs(der-analytic)),...
 'PI_pole_real',real(poles),'PI_pole_imag',imag(poles),...
 'boundary','Small-parameter independent theory fixture; not a new V10, Simulink, RTL or real-head acceptance');
fid=fopen(fullfile(here,'matlab_checks.json'),'w');fwrite(fid,jsonencode(result,PrettyPrint=true));fclose(fid);
disp(result);assert(all(structfun(@(x)x,result.checks)));
end
function m=measure(C)
m=[real(C'*C);real(C'*[0 -1i;1i 0]*C);real(C'*diag([1 -1])*C);real(C'*[0 1;1 0]*C);C.'*C];
end
