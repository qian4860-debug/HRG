% Case B: frequency split only. Fit the quadrature-growth coefficient and the
% split-induced pattern drift, compare with code (2*splitRad*E*sin4 and 0.5*splitRad*Q/E*cos4).
clear; clc;
f0 = 100; Qf = 1.0e5; omega0 = 2*pi*f0; tau = Qf/(pi*f0); gamma = 1/tau;
dfHz = 2e-5; dHalf = pi*dfHz;          % half-split in rad/s (modes differ by 2*pi*df)
splitRad = 2*pi*dfHz;                   % code's splitRad
thO = 41*pi/180;
A3 = @(th)[cos(4*th), sin(4*th); sin(4*th), -cos(4*th)];
C = 2*gamma*eye(2);
K = omega0^2*eye(2) + 2*omega0*dHalf*A3(thO);
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
dQ = sm(gradient(Qo,Ts)); dth = sm(gradient(tho,Ts));
n = numel(t); j = round(0.2*n):round(0.8*n);
fprintf('--- CASE B: frequency split only ---\n');
fprintf('Q/E median %.3e\n', median(abs(Qm(j))./Em(j)));
base = mean(-2*gamma*Qm(j));
fprintf('dQ measured mean %.4e ; passive part %.4e ; residual %.4e\n', ...
    mean(dQ(j)), base, mean(dQ(j))-base);
resid = dQ(j) - (-2*gamma*Qm(j));
coef = mean(resid ./ (Em(j).*sin(4*(thm(j)-thO))));
fprintf('fitted coefficient on E*sin4 : %.4e 1/s\n', coef);
fprintf('code 2*splitRad = %.4e ; 2*dHalf = %.4e ; 4*dHalf = %.4e ; splitRad = %.4e\n', ...
    2*splitRad, 2*dHalf, 4*dHalf, splitRad);
coef2 = mean(dth(j) ./ ( (Qm(j)./Em(j)).*cos(4*(thm(j)-thO)) ));
fprintf('fitted coefficient on (Q/E)cos4 : %.4e\n', coef2);
fprintf('code 0.5*splitRad = %.4e ; 0.25*splitRad = %.4e ; dHalf = %.4e ; 0.5*dHalf=%.4e\n', ...
    0.5*splitRad, 0.25*splitRad, dHalf, 0.5*dHalf);
