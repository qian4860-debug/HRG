function phi = HRG_WA_v46_frp_basis(theta, temperature, scanRate, p)
% 构造V4.6.5统一九参数FRP基函数，供在线RLS、oracle、批量LS和冻结补偿共同使用。
% scanRate为Kalman估计的驻波角速度；参数依次为零偏、四八次谐波、温度、归一化扫描速率及其四次调制项。
theta = theta(:);
temperature = temperature(:);
scanRate = scanRate(:);
n = numel(theta);
assert(numel(temperature) == n && numel(scanRate) == n, 'FRP基函数的角度、温度和扫描速率样本数必须一致。');
deltaTNormalized = (temperature - p.env.referenceTemperature) / 20;
if ~p.frp.identifyTemperature
    deltaTNormalized(:) = 0;
end
scanScale = max(p.frp.scanRateNormalizationDps, eps) * pi / 180;
scanNormalized = scanRate / scanScale;
phi = [ones(n,1), sin(4*theta), cos(4*theta), sin(8*theta), cos(8*theta), ...
    deltaTNormalized, scanNormalized, scanNormalized.*sin(4*theta), scanNormalized.*cos(4*theta)];
end