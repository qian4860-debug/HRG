function [v,code,clipped,bounds]=p101_quantize(x,span,bits,limit)
% Signed midtread code convention: -2^(N-1) ... 2^(N-1)-1.
% Physical limit is intersected in the integer domain BEFORE decoding.
if nargin<4,limit=span/2;end
assert(isscalar(span)&&span>0&&bits==fix(bits)&&bits>=2&&bits<=32);
assert(isscalar(limit)&&isfinite(limit)&&limit>0&&all(isfinite(x),'all'));
lsb=span/2^bits;lo=max(-2^(bits-1),ceil(-limit/lsb));hi=min(2^(bits-1)-1,floor(limit/lsb));
assert(lo<=hi);raw=round(x/lsb);code=max(lo,min(hi,raw));v=code*lsb;
clipped=raw<lo|raw>hi|abs(x)>limit;bounds=[lo hi];
end
