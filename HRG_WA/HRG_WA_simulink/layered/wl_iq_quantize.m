function y=wl_iq_quantize(u,c)
y=u;if c.iqFractionBits>0,y=max(-8,min(8-2^-c.iqFractionBits,round(u*2^c.iqFractionBits)/2^c.iqFractionBits));end
d=(y(1:2)+1i*y(3:4))*exp(-1i*c.knownPhaseCalibrationRad);y=[real(d);imag(d)];
end
