function [Ad,Bd,x0,A,B]=p101_plant(p)
% Motional-charge coordinates: mechanical damping is intrinsic short-circuit
% damping ONLY. Sensor loading remains in explicit electrical states.
w=2*pi*p.f0;J=[0 -1;1 0];R=@(t)[cos(t) -sin(t);sin(t) cos(t)];
assert(p.gamma_intrinsic>abs(p.damping_half_difference));
assert(p.Omega==0||(~isempty(p.B)&&isfinite(p.B)&&p.B>0));
K=R(p.stiffness_axis)*diag((w+[-1 1]*pi*p.split_hz).^2)*R(p.stiffness_axis)';
D=R(p.damping_axis)*diag(2*(p.gamma_intrinsic+[1 -1]*p.damping_half_difference))*R(p.damping_axis)';
A=zeros(12);B=zeros(12,2);A(1:2,3:4)=eye(2);A(3:4,1:2)=-K;A(3:4,3:4)=-D;
if p.Omega~=0,A(3:4,3:4)=A(3:4,3:4)-4*p.B*p.Omega*J;end
A(3:4,5:6)=p.b*p.drive_matrix;A(3:4,7:8)=p.kappa*eye(2);
A(5:6,5:6)=-diag(1./p.driver_tau);B(5:6,:)=diag(1./p.driver_tau);
A(7:8,7:8)=-(1/p.Rs+p.G0)/p.Cs*eye(2);A(7:8,3:4)=-eye(2)/p.Cs;
A(7:8,:)=A(7:8,:)+p.Cds/p.Cs*A(5:6,:);B(7:8,:)=p.Cds/p.Cs*B(5:6,:);
A(9:10,7:8)=eye(2)/(p.Rs*p.Cf);A(9:10,9:10)=-eye(2)/(p.Rf*p.Cf);
A(11:12,9:10)=diag(2*pi*p.afe_bw)*p.detect_matrix;A(11:12,11:12)=-diag(2*pi*p.afe_bw);
E=expm([A B;zeros(2,14)]*p.Ts);Ad=E(1:12,1:12);Bd=E(1:12,13:14);
x0=zeros(12,1);x0(1:2)=p.initial_fraction*p.charge_target*[cos(p.theta0);sin(p.theta0)];
end
