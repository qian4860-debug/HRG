function result = tdm_input_noise_budget(gain,cvNoise_V_rms,pgaInputNoise_V_rms, ...
    adcNoise_LSB_rms,apertureJitter_s_rms,adcPeak_V,opts)
% 以 C/V 输出、PGA 输入为参考面，比较量程档位的输入等效随机噪声。
% 参数按实测带宽给 RMS。量化单独列出，避免与 ADC 实测码波动重复计入。
arguments
    gain (:,1) double {mustBeFinite,mustBePositive}
    cvNoise_V_rms (1,1) double {mustBeFinite,mustBeNonnegative}
    pgaInputNoise_V_rms (1,1) double {mustBeFinite,mustBeNonnegative}
    adcNoise_LSB_rms (1,1) double {mustBeFinite,mustBeNonnegative}
    apertureJitter_s_rms (1,1) double {mustBeFinite,mustBeNonnegative}
    adcPeak_V (:,1) double {mustBeFinite,mustBeNonnegative}
    opts.Span_Vpp (1,1) double {mustBeFinite,mustBePositive} = 2
    opts.AdcBits (1,1) double {mustBeInteger,mustBeInRange(opts.AdcBits,2,32)} = 10
    opts.Carrier_Hz (1,1) double {mustBeFinite,mustBePositive} = 6800
    opts.AdcNoiseExcludesQuantization (1,1) logical = false
end
assert(numel(adcPeak_V)==numel(gain),'每个增益对应一个实际 ADC 峰值。');
step = opts.Span_Vpp/2^opts.AdcBits;
adc = adcNoise_LSB_rms*step./gain;
% 正弦全相位平均的斜率 RMS；单个最大斜率时刻的上界另乘 sqrt(2)。
jitter = 2*pi*opts.Carrier_Hz*(adcPeak_V/sqrt(2))*apertureJitter_s_rms./gain;
cv = repmat(cvNoise_V_rms,size(gain));
pga = repmat(pgaInputNoise_V_rms,size(gain));
quantization = (step/sqrt(12))./gain;
total = sqrt(cv.^2+pga.^2+adc.^2+jitter.^2);
if opts.AdcNoiseExcludesQuantization
    % 仅限量化误差可视为白噪声的对照；相干误差由闭环试验单独计分。
    total = hypot(total,quantization);
end
result = table(gain,adcPeak_V/(opts.Span_Vpp/2),cv,pga,adc,jitter,quantization,total, ...
    'VariableNames',{'Gain','AdcPeakFraction','CvNoiseInput_Vrms','PgaNoiseInput_Vrms', ...
    'AdcNoiseInput_Vrms','ApertureNoiseInput_Vrms','WhiteQuantizationInput_Vrms','TotalInput_Vrms'});
end
