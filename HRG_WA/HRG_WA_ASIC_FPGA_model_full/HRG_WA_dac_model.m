function [uAct, st, diag] = HRG_WA_dac_model(uCmd, p, st)
% HRG_WA_DAC_MODEL  DAC/driver behavioral model for fa/fq/virtual-rate commands.
%
% 功能说明：
%   数字控制器输出的 fa、fq、virtRate 在真实 ASIC/FPGA 样机中需要通过 DAC、
%   PWM 或 ΣΔ 调制接口转换为模拟驱动量。本函数模拟位宽、满量程、流水线延迟、
%   零阶保持、通道增益/偏置、输出噪声和饱和。

uCmd = uCmd(:);
fs = [p.dac.fullScaleFa; p.dac.fullScaleFq; p.dac.fullScaleVirt];
diag = struct('sat',false,'qstep',zeros(3,1),'cmdQ',zeros(3,1));

% 数字输出满量程饱和。
[uClip, sat0] = HRG_WA_clip(uCmd, -fs, fs);
diag.sat = diag.sat || sat0;

% DAC 量化。
uQ = zeros(3,1);
for i = 1:3
    qstep = 2*fs(i)/(2^p.dac.bits);
    diag.qstep(i) = qstep;
    tmp = uClip(i);
    if p.dac.enableDither
        tmp = tmp + qstep*(rand-0.5);
    end
    uQ(i) = qstep*round(tmp/qstep);
end

% 故障注入：DAC 饱和或通道钳位。
if isfinite(p.fault.injectTime) && st.t >= p.fault.injectTime && strcmpi(p.fault.type,'dac_saturate')
    uQ(1:2) = sign(uQ(1:2)+eps).*fs(1:2);
    diag.sat = true;
end

diag.cmdQ = uQ;

% 流水线延迟。
st.dac.delay = [uQ, st.dac.delay(:,1:end-1)];
uDelay = st.dac.delay(:,end);

% 驱动通道增益、偏置和噪声。
uAct = p.dac.gain(:).*uDelay + p.dac.offset(:) + p.dac.noiseSigma(:).*randn(3,1);

% 输出级再次限幅。
[uAct, sat1] = HRG_WA_clip(uAct, -fs, fs);
diag.sat = diag.sat || sat1;
end
