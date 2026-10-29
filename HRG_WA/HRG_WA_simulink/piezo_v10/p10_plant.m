function [Ad,Bd,x0,H,A,B]=p10_plant(p)
% states: displacement,velocity,driver voltage,sensor-port voltage,
% charge-amplifier output,AFE output; each state is a two-vector.
w=2*pi*p.f0;J=[0 -1;1 0];A=zeros(12);B=zeros(12,2);
A(1:2,3:4)=eye(2);
A(3:4,1:2)=-diag((w+[-1 1]*pi*p.split_hz).^2);
A(3:4,3:4)=-diag(w/p.Q+[1 -1]*2*p.damping_delta)-4*p.B*p.Omega*J;
A(3:4,5:6)=p.theta_d/p.mass*diag([1 p.drive_y]);
A(3:4,7:8)=p.theta_s/p.mass*eye(2);
A(5:6,5:6)=-eye(2)/p.driver_tau;B(5:6,:)=eye(2)/p.driver_tau;
A(7:8,7:8)=-eye(2)/(p.Rs*p.Cs);A(7:8,3:4)=-p.theta_s/p.Cs*eye(2);
% Optional reciprocal drive-sense capacitance: Cs*vsdot=...+Cds*vddot.
A(7:8,:)=A(7:8,:)+p.Cds/p.Cs*A(5:6,:);B(7:8,:)=p.Cds/p.Cs*B(5:6,:);
A(9:10,7:8)=eye(2)/(p.Rs*p.Cf);A(9:10,9:10)=-eye(2)/(p.Rf*p.Cf);
A(11:12,9:10)=eye(2)*2*pi*p.afe_bw;A(11:12,11:12)=-eye(2)*2*pi*p.afe_bw;
E=expm([A B;zeros(2,14)]*p.Ts);Ad=E(1:12,1:12);Bd=E(1:12,13:14);
x0=zeros(12,1);x0(1:2)=p.initial_amp*[cos(p.alpha0);sin(p.alpha0)];
s=1i*w;H=-p.theta_s*s/((1+s*p.Rs*p.Cs)*p.Cf*(s+1/(p.Rf*p.Cf))*(1+s/(2*pi*p.afe_bw)));
end
