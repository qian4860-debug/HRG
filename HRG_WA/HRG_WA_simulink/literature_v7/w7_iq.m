function y=w7_iq(u,c)
d=(u(1:2)+1i*u(3:4))*c.v7.senseCalibration;
y=[real(d);imag(d)];
if c.iqFractionBits>0
 y=max(-8,min(8-2^-c.iqFractionBits,round(y*2^c.iqFractionBits)/2^c.iqFractionBits));
end
end
