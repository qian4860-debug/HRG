function [y, sat] = HRG_WA_clip(x, xmin, xmax)
% HRG_WA_CLIP  Saturate a scalar/vector and report whether clipping occurred.
%
% 功能说明：
%   FPGA/ASIC 中几乎所有 ADC 输入、PI 输出、DAC 输出、寄存器数据和内部定点运算
%   都存在有限动态范围。该函数用于统一模拟饱和限幅。
%
% 输入：
%   x     原始输入。
%   xmin  最小允许值。
%   xmax  最大允许值。
%
% 输出：
%   y     限幅后的输出。
%   sat   饱和标志。只要任一元素被限幅，sat=true。

y = min(max(x, xmin), xmax);
sat = any(y(:) ~= x(:));
end
