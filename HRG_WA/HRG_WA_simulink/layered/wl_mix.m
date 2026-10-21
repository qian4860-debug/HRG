function y=wl_mix(u,gain)
v=u(1:2);phase=u(3);
y=[2*v*cos(phase);-2*v*sin(phase)]/gain;
end
