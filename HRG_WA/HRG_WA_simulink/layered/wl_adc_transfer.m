function y=wl_adc_transfer(u,c)
y=wl_quantize(c.adcGain.*u+c.adcOffsetV,c.adcBits,c.adcFsV,c.adcInlCubic);
end
