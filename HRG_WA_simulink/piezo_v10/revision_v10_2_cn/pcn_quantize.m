function [v,code,clipped,bounds]=pcn_quantize(x,span,bits,limit)
% 有符号midtread ADC/DAC量化器。
% span为总电压跨度V；bits为位宽；limit为对称物理限幅V。
% 合法整数码[-2^(bits-1),2^(bits-1)-1]，正负满量程不对称。
% 先在整数域与物理上下界求交，再舍入饱和，最后乘LSB恢复电压。
% clipped同时覆盖整数溢出和物理输入越界；不能把截幅误差当白量化噪声。
% Signed midtread code convention: -2^(N-1) ... 2^(N-1)-1.
% Physical limit is intersected in the integer domain BEFORE decoding.
if nargin<4,limit=span/2;end
assert(isscalar(span)&&span>0&&bits==fix(bits)&&bits>=2&&bits<=32);
assert(isscalar(limit)&&isfinite(limit)&&limit>0&&all(isfinite(x),'all'));
lsb=span/2^bits;lo=max(-2^(bits-1),ceil(-limit/lsb));hi=min(2^(bits-1)-1,floor(limit/lsb));
assert(lo<=hi);raw=round(x/lsb);code=max(lo,min(hi,raw));v=code*lsb;
clipped=raw<lo|raw>hi|abs(x)>limit;bounds=[lo hi];
end
