function v=wl_modulate(u,c,hToV)
h=u(1:2)+1i*u(3:4);phase=u(5);
v=-hToV*(imag(h)*cos(phase)+real(h)*sin(phase));
if c.tdmEnable,v=v*2*double(mod(phase,4*pi)<2*pi);end
end
