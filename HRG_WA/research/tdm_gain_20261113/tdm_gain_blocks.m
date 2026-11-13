function blocks = tdm_gain_blocks(c)
% 按驱动、泄放、检测、尾窗构建线性推进映射，矩阵只依赖同一增益配置。
n = c.stateCount;
if c.continuous
    % ADC 流水结束前，下一帧的前几拍仍使用前一条 DAC 指令。
    lat = c.adcLatency;
    assert(lat<c.frame,'连续快速评估需要 ADC 流水延迟短于一个帧。');
    blocks = struct('early',segment(c,lat),'later',segment(c,c.frame-lat));
    return
end
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

function s = segment(c,count)
% 用零填充 FFT 计算因果卷积。首拍只依赖段初状态，因为 DAC 经过 ZOH。
n = c.stateCount;
output = [c.pickoff;c.portCV];
observed = size(output,1);
stateMap = zeros(observed*count,n);
driveEnd = zeros(n,2*count);
impulse = zeros(count,observed,2);
r = eye(n);
for k = 1:count
    stateMap((k-1)*observed+(1:observed),:) = output*r;
    driveEnd(:,2*(count-k)+(1:2)) = r*c.Bd;
    if k<count
        impulse(k+1,:,:) = reshape(output*r*c.Bd,1,observed,2);
    end
    r = r*c.Ad;
end
lengthFFT = 2^nextpow2(max(1,2*count-1));
s = struct('count',count,'observed',observed,'state',r,'drive',driveEnd, ...
    'stateMap',stateMap,'impulseFFT',fft(impulse,lengthFFT,1),'lengthFFT',lengthFFT);
end
