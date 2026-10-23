function a=w7_force(u,c)
% [actual voltage(2); generalized displacement / Aref(2)].
v=u(1:2);x=c.displacementM*u(3:4);B=c.v7.driveBiasV;
if strcmp(c.v7.actuationMode,'linear'),F=c.driveNPerV*v;
else
 % Symmetric opposing electrodes: F=1/2 V^2 dC/dx, no invented q^3 term.
 % Modal/electrode participation is an explicit measured/FEM scale.
 rho=x/c.gapM;assert(all(abs(rho)<.2),'Electrostatic gap model outside small-motion range');
 F=c.v7.electrostaticForceScale*c.c0F/(2*c.gapM)* ...
  ((B+v).^2./(1-rho).^2-(B-v).^2./(1+rho).^2);
end
a=F/(c.massKg*c.displacementM);
end
