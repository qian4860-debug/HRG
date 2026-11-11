function [t, trace, frames, adcMonitor] = five_reference(c)
% 五电极 MATLAB 逐拍参考：与原生 Simulink 使用同一列协议和同一评分入口。
% trace 的 1:22 列沿用 6800 Hz 基线，23:26 列为 A/B/C/D 相对 COM 的端电压。
% 第 4 个输出 adcMonitor 是量化前采样，便于在 five_inspect 中观察
% C/V、ADC 输入与流水线输出的波形；不给第 4 输出时保持旧调用兼容。
arguments
    c (1,1) struct = five_config()
end
assert(isfield(c,'groupVoltage'), 'Use a configuration from five_config.');
if nargout>=4
    [t,trace,frames,adcMonitor] = h68_reference(c);
else
    [t,trace,frames] = h68_reference(c);
end
end
