function allan = HRG_WA_allan_dev(rate, fs)
% HRG_WA_ALLAN_DEV  Simple overlapping Allan deviation for rate data.
%
% 功能说明：
%   用于陀螺零速输出性能评估。输入为等间隔角速度序列，输出不同平均时间 tau
%   下的 Allan deviation。单位与输入 rate 相同。
%
% 注意：
%   为了避免依赖专用工具箱，此处采用简化重叠 Allan 方差实现。样本数太少时，
%   只返回可计算的 tau 点。

rate = rate(:);
N = length(rate);
if N < 10
    allan = struct('tau',[],'adev',[]);
    return;
end

% 速率积分为角度，用角度二阶差分计算 Allan 方差。
ts = 1/fs;
theta = cumsum(rate)*ts;
maxM = floor(N/10);
if maxM < 1
    allan = struct('tau',[],'adev',[]);
    return;
end

mList = unique(round(logspace(0, log10(maxM), min(30,maxM))));
tau = mList(:)*ts;
adev = nan(size(tau));

for i = 1:length(mList)
    m = mList(i);
    if N < 2*m + 1
        continue;
    end
    d2 = theta(1+2*m:end) - 2*theta(1+m:end-m) + theta(1:end-2*m);
    adev(i) = sqrt(0.5*mean(d2.^2)/(m*ts)^2);
end

valid = isfinite(adev);
allan = struct('tau',tau(valid),'adev',adev(valid));
end
