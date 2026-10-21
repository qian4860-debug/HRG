function dx = wa_plant_rhs(u)
% u = [Re(z)(2); Im(z)(2); h(4); Omega; temperature; parameters(41)]
z = u(1:2)+1i*u(3:4); h = u(5:6)+1i*u(7:8);
omega = u(9); temperature = u(10); p = u(11:end);
J = [0 -1;1 0];
Ad = [cos(4*p(4)) sin(4*p(4));sin(4*p(4)) -cos(4*p(4))];
Ak = [cos(4*p(6)) sin(4*p(6));sin(4*p(6)) -cos(4*p(6))];
Gamma = p(2)*eye(2)+.5*p(3)*Ad;
df = p(8)+p(1)*p(10)*(temperature-p(11))+p(9)*sum(abs(z).^2);
H = 2*pi*df*eye(2)-pi*p(5)*Ak;
dz = -Gamma*z+1i*H*z-2*p(7)*omega*J*z+h;
dx = [real(dz);imag(dz)];
end
