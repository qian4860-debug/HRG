function force=wl_temperature_force(u,c)
q=u(1:2);T=u(3);p=c.head;
w0=2*pi*(p.f0+p.detuningHz+p.f0*p.temperatureCoeff*(c.temperatureC-25));
w=2*pi*(p.f0+p.detuningHz+p.f0*p.temperatureCoeff*(T-25));
force=-(w*w-w0*w0)*q;
end
