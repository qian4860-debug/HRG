function blocks = tdm_gain_blocks(c)
% 按驱动、泄放、检测、尾窗构建线性推进映射，矩阵只依赖同一增益配置。
n = c.stateCount;
driveMap = zeros(n,2*c.driveEnd);
r = eye(n);
for k = c.driveEnd:-1:1
    driveMap(:,2*k-1:2*k) = r*c.Bd;
    r = r*c.Ad;
end
senseCount = c.validEnd-c.senseStart;
adcSense = zeros(2*senseCount,n);
cvSense = zeros(4*senseCount,n);
a = eye(n);
for k = 1:senseCount
    adcSense(2*k-1:2*k,:) = c.pickoff*a;
    cvSense(4*k-3:4*k,:) = c.portCV*a;
    a = a*c.As;
end
blocks = struct('driveEnd',r,'driveConvolution',driveMap, ...
    'bleedEnd',c.Af^(c.senseStart-c.driveEnd),'senseEnd',a, ...
    'tailEnd',c.Af^(c.frame-c.validEnd),'adcSense',adcSense,'cvSense',cvSense);
end
