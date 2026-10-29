function [Ad,Bd,x0,H,A,B]=p10e_plant(p)
% State pairs: motional charge C,charge velocity C/s,driver V,sensor V,amp V,AFE V.
w=2*pi*p.f0;J=[0 -1;1 0];A=zeros(12);B=zeros(12,2);
A(1:2,3:4)=eye(2);A(3:4,1:2)=-w^2*eye(2);A(3:4,3:4)=-2*p.gamma*eye(2);
if p.Omega~=0
 assert(~isempty(p.B),'Unknown B: only stationary electrical testing is permitted');
 A(3:4,3:4)=A(3:4,3:4)-4*p.B*p.Omega*J;
end
A(3:4,5:6)=p.b*eye(2);A(3:4,7:8)=p.kappa*eye(2);
A(5:6,5:6)=-eye(2)/p.driver_tau;B(5:6,:)=eye(2)/p.driver_tau;
A(7:8,7:8)=-(1/p.Rs+p.G0)/p.Cs*eye(2);A(7:8,3:4)=-eye(2)/p.Cs;
A(7:8,:)=A(7:8,:)+p.Cds/p.Cs*A(5:6,:);B(7:8,:)=p.Cds/p.Cs*B(5:6,:);
A(9:10,7:8)=eye(2)/(p.Rs*p.Cf);A(9:10,9:10)=-eye(2)/(p.Rf*p.Cf);
A(11:12,9:10)=2*pi*p.afe_bw*eye(2);A(11:12,11:12)=-2*pi*p.afe_bw*eye(2);
E=expm([A B;zeros(2,14)]*p.Ts);Ad=E(1:12,1:12);Bd=E(1:12,13:14);
x0=zeros(12,1);x0(1:2)=.3*p.charge_target_C*[cos(p.alpha0);sin(p.alpha0)];
s=1i*w;H=-s/((1+p.Rs*p.G0+s*p.Rs*p.Cs)*p.Cf*(s+1/(p.Rf*p.Cf))*(1+s/(2*pi*p.afe_bw)));
end
