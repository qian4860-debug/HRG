function y=wl_env_adc(u,c,gain)
y=wl_quantize(u*gain,c.adcBits,c.adcFsV,c.adcInlCubic)/gain;
end
