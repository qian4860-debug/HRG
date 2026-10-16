function y = HRG_WA_wrap_pi(x)
% HRG_WA_WRAP_PI  Wrap angle to [-pi, pi).
%
% 功能说明：
%   MATLAB Mapping Toolbox 中有 wrapToPi，但为避免依赖额外工具箱，这里给出独立实现。
%   该函数用于 CORDIC/atan2 输出相位的连续展开。

y = mod(x + pi, 2*pi) - pi;
end
