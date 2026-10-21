function y=wl_invariants(d)
d=d(1:2)+1i*d(3:4);
E=sum(abs(d).^2);Q=2*imag(conj(d(1))*d(2));R=abs(d(1))^2-abs(d(2))^2;
S=2*real(conj(d(1))*d(2));L=imag(sum(d.^2));
y=[real(d);imag(d);E;Q;R;S;L;.5*atan2(L,real(sum(d.^2)))];
end
