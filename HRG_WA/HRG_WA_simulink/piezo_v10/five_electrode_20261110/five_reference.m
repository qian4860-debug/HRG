function [t, trace, frames, adcMonitor, angleCandidates, numericProbe] = five_reference(c,collectADCMonitor)
% 五电极 MATLAB 逐拍参考：与原生 Simulink 使用同一列协议和同一评分入口。
% trace 的 1:22 列沿用 6800 Hz 基线，23:26 列为 A/B/C/D 相对 COM 的端电压。
% 第 4 个输出 adcMonitor 是量化前采样，便于在 five_inspect 中观察
% C/V、ADC 输入与流水线输出的波形。第 5 输出记录三路观测及发布候选，
% 输出列与原生观察模型一致；只需逐帧角时可设 collectADCMonitor=false。
arguments
    c (1,1) struct = five_config()
    collectADCMonitor (1,1) logical = true
end
assert(isfield(c,'groupVoltage'), 'Use a configuration from five_config.');
% 第六输出只读记录 NCO、量化前电压和状态，用于首次分歧定位。
if nargout>=6
    [t,trace,frames,adcMonitor,angleCandidates,numericProbe] = h68_reference(c,collectADCMonitor);
elseif nargout>=5
    [t,trace,frames,adcMonitor,angleCandidates] = h68_reference(c,collectADCMonitor);
elseif nargout>=4
    [t,trace,frames,adcMonitor] = h68_reference(c,collectADCMonitor);
else
    [t,trace,frames] = h68_reference(c,collectADCMonitor);
end
end
