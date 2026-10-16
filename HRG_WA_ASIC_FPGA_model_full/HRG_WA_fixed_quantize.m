function [y, sat] = HRG_WA_fixed_quantize(x, wl, fl, signedFlag, roundMode)
% HRG_WA_FIXED_QUANTIZE  Fixed-point quantization with saturation.
%
% 功能说明：
%   该函数模拟 FPGA/ASIC 内部定点数据通路：有限字长、有限小数位、四舍五入/截断
%   和溢出饱和。它不是 MATLAB Fixed-Point Designer 对象，因此不需要额外工具箱。
%
% 输入：
%   x           浮点输入。
%   wl          word length，总字长。
%   fl          fraction length，小数位数。
%   signedFlag  true 表示有符号二进制定点，false 表示无符号。
%   roundMode   'nearest' 或 'floor'。
%
% 输出：
%   y           量化后的浮点等效值。
%   sat         是否发生饱和。

if nargin < 4 || isempty(signedFlag)
    signedFlag = true;
end
if nargin < 5 || isempty(roundMode)
    roundMode = 'nearest';
end

scale = 2^fl;
if signedFlag
    qmin = -2^(wl-1);
    qmax =  2^(wl-1)-1;
else
    qmin = 0;
    qmax = 2^wl-1;
end

switch lower(roundMode)
    case 'floor'
        q = floor(x*scale);
    otherwise
        q = round(x*scale);
end

qClip = min(max(q, qmin), qmax);
y = qClip/scale;
sat = any(qClip(:) ~= q(:));
end
