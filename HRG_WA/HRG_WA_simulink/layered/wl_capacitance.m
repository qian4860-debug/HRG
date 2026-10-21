function y=wl_capacitance(u,c)
% Differential parallel plates; displacement normalized to c.displacementM.
r=c.displacementM*u/c.gapM;
r=max(-.2,min(.2,r));
if c.circuitEnable,y=.5*c.c0F*(1./(1-r)-1./(1+r));else,y=c.c0F*r;end
end
