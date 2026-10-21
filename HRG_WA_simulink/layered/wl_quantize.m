function y=wl_quantize(u,bits,fullscale,cubic)
% Symmetric input, signed ADC/DAC codes; same physical unit at both ports.
x=u+cubic*fullscale*(u/fullscale).^3;
if bits==0,y=x;return;end
lsb=2*fullscale/2^bits;
y=round(min(fullscale-lsb,max(-fullscale,x))/lsb)*lsb;
end
