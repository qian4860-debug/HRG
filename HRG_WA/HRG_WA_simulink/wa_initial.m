function z = wa_initial(p)
% z is a two-element complex carrier amplitude; q=real(z*exp(i*w0*t)).
a=sqrt(p.initialEnergy/(1+p.initialQuadRatio^2));
b=p.initialQuadRatio*a;
alpha=2*p.initialTheta;
z=[cos(alpha) -sin(alpha);sin(alpha) cos(alpha)]*[a;1i*b];
end
