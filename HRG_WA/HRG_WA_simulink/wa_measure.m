function y = wa_measure(u)
% Complex synchronous fundamental detection; no carrier or ADC bitstream here.
% u=[state(4); reference phase; parameters(41)].
z = u(1:2)+1i*u(3:4); p = u(6:end);
M = reshape(p(12:15),2,2);
d = (M*z).*exp(-1i*(u(5)+p(16:17)));
d = d.*(1+.75*p(22)*abs(d).^2); % Cubic fundamental projection.
if p(23)>0
    scale = (2^(p(23)-1)-1)/p(24);
    d = complex(round(max(-p(24),min(p(24),real(d)))*scale)/scale, ...
        round(max(-p(24),min(p(24),imag(d)))*scale)/scale);
end
E = sum(abs(d).^2);
Q = 2*imag(conj(d(1))*d(2));
R = abs(d(1))^2-abs(d(2))^2;
S = 2*real(conj(d(1))*d(2));
L = imag(sum(d.^2));
phi = .5*atan2(L,real(sum(d.^2)));
y = [real(d);imag(d);E;Q;R;S;L;phi];
end
