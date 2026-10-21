function dx = wa_full_rhs(u)
% Carrier plant: u=[q(2); v(2); Omega; Omega_dot; temperature; F/m(2); p].
q=u(1:2);v=u(3:4);rate=u(5);acc=u(6);temp=u(7);force=u(8:9);p=u(10:end);
w=2*pi*(p(1)+p(8)+p(1)*p(10)*(temp-p(11)));
Ad=[cos(4*p(4)) sin(4*p(4));sin(4*p(4)) -cos(4*p(4))];
Ak=[cos(4*p(6)) sin(4*p(6));sin(4*p(6)) -cos(4*p(6))];
D=2*p(2)*eye(2)+p(3)*Ad;
K=w*w*eye(2)-w*2*pi*p(5)*Ak;
J=[0 -1;1 0];
dv=force-(D+4*p(7)*rate*J)*v-(K+2*p(7)*acc*J)*q;
dx=[v;dv];
end
