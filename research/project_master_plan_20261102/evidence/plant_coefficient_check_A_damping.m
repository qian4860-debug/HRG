% Case A: damping anisotropy only (no frequency split). Determine the true
% coefficient of the pattern-drift term and compare with the code's 0.5*dGamma.
clear; clc;
f0 = 100; Qf = 1.0e5; omega0 = 2*pi*f0; tau = Qf/(pi*f0); gamma = 1/tau;
dGamma = 2.5e-4; thTau = 17*pi/180;
A3 = @(th)[cos(4*th), sin(4*th); sin(4*th), -cos(4*th)];
C = 2*gamma*eye(2) + dGamma*A3(thTau);
K = omega0^2*eye(2);
A = [0 1 0 0; -K(1,1) -C(1,1) -K(1,2) -C(1,2);
     0 0 0 1; -K(2,1) -C(2,1) -K(2,2) -C(2,2)];
fs = 40*f0; Ts = 1/fs; T = 400; N = round(T/Ts); nPer = round(fs/f0);
th0 = 30*pi/180;
x = [cos(2*th0); 0; sin(2*th0); 0];
tt = (0:N-1)'*Ts; X = zeros(N,2); h = Ts;
for k = 1:N
    X(k,:) = x([1 3]);
    k1 = A*x; k2 = A*(x+h/2*k1); k3 = A*(x+h/2*k2); k4 = A*(x+h*k3);
    x = x + h/6*(k1 + 2*k2 + 2*k3 + k4);
end
c = cos(omega0*tt); s = sin(omega0*tt);
bx = @(v) filter(ones(nPer,1)/nPer, 1, v);
nrm = bx(ones(N,1));
Cx = 2*bx(X(:,1).*c)./nrm;  Sx = 2*bx(X(:,1).*s)./nrm;
Cy = 2*bx(X(:,2).*c)./nrm;  Sy = 2*bx(X(:,2).*s)./nrm;
E = Cx.^2+Sx.^2+Cy.^2+Sy.^2;
Qv = 2*(Cx.*Sy - Cy.*Sx);
R = Cx.^2+Sx.^2-Cy.^2-Sy.^2;
S = 2*(Cx.*Cy + Sx.*Sy);
th = unwrap(4*0.25*atan2(S,R))/4;
i1 = round(20/Ts); i2 = round(380/Ts); idx = i1:i2;
t = tt(idx); Eo = E(idx); Qo = Qv(idx); tho = th(idx);
nSm = round(2/Ts);
sm = @(v) filter(ones(nSm,1)/nSm,1,v)./filter(ones(nSm,1)/nSm,1,ones(size(v)));
Em = sm(Eo); Qm = sm(Qo); thm = sm(tho);
dth = sm(gradient(tho,Ts)); dE = sm(gradient(Eo,Ts));
n = numel(t); j = round(0.2*n):round(0.8*n);
fprintf('--- CASE A: damping anisotropy only ---\n');
fprintf('Q/E  median %.3e  (must be << 1)\n', median(abs(Qm(j))./Em(j)));
fprintf('dtheta measured mean %.4e rad/s\n', mean(dth(j)));
fprintf('  k=0.25 : %.4e   k=0.5 : %.4e   k=-0.25 : %.4e   k=-0.5 : %.4e\n', ...
  mean(0.25*dGamma*sin(4*(thm(j)-thTau))), mean(0.5*dGamma*sin(4*(thm(j)-thTau))), ...
  mean(-0.25*dGamma*sin(4*(thm(j)-thTau))), mean(-0.5*dGamma*sin(4*(thm(j)-thTau))));
fprintf('best-fit k = %.4f\n', mean(dth(j))/mean(dGamma*sin(4*(thm(j)-thTau))));
fprintf('dE measured %.4e ; predicted -2gE-dGamma*cos*E %.4e ; ratio %.4f\n', ...
  mean(dE(j)), mean((-2*gamma - dGamma*cos(4*(thm(j)-thTau))).*Em(j)), ...
  mean((-2*gamma - dGamma*cos(4*(thm(j)-thTau))).*Em(j))/mean(dE(j)));
fprintf('theta total drift %.4e rad over %.0f s\n', tho(end)-tho(1), t(end)-t(1));
