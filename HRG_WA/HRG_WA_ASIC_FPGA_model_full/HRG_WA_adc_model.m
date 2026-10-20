function [adc, st, diag] = HRG_WA_adc_model(uIdeal, p, st)
% HRG_WA_ADC_MODEL  AFE + ADC behavioral model for E/Q/S/R variables.
%
% 功能说明：
%   在当前慢变量模型中，机械谐振子直接给出等效解调变量 E/Q/S/R。为了面向
%   FPGA/ASIC 验证，需要进一步模拟检测前端和 ADC 接口：增益、偏置、串扰、
%   带宽限制、采样延迟、噪声、量化和饱和。
%
% 输入：
%   uIdeal  4x1 理想变量 [E; Q; S; R]。
%   p       参数结构体。
%   st      数字状态结构体。
%
% 输出：
%   adc     4x1 ADC 数字输出的浮点等效值。
%   st      更新后的状态。
%   diag    诊断结构体，含 saturate 标志。

Ts = p.iface.Ts;
diag = struct('sat',false,'raw',uIdeal(:),'afe',[],'qstep',0);

z = uIdeal(:);

% 故障注入：AFE 偏置突变。
if isfinite(p.fault.injectTime) && st.t >= p.fault.injectTime && strcmpi(p.fault.type,'afe_offset')
    z = z + p.fault.magnitude*[1;1;1;1];
end

if p.afe.enable
    % 串扰矩阵、增益和偏置。
    z = p.afe.cross*z;
    z = p.afe.gain(:).*z + p.afe.offset(:);

    % 一阶低通，模拟前端带宽和相位延迟。
    if p.afe.bandwidthHz > 0
        alpha = exp(-2*pi*p.afe.bandwidthHz*Ts);
        st.afe.lpf = alpha*st.afe.lpf + (1-alpha)*z;
        z = st.afe.lpf;
    end

    % 采样延迟线。
    st.afe.delay = [z, st.afe.delay(:,1:end-1)];
    z = st.afe.delay(:,end);

    % 前端热噪声/放大器噪声。
    z = z + p.afe.noiseSigma(:).*randn(4,1);

    % 电源噪声和振动扰动折算。
    if p.env.enable
        z = z + p.env.supplyNoiseSigma*randn(4,1);
        z = z + p.env.vibrationSigma*[0.2; 1.0; 0.5; 0.5].*randn(4,1);
    end

    % 模拟前端满量程饱和。
    [z, satAfe] = HRG_WA_clip(z, -p.afe.fullScale, p.afe.fullScale);
    diag.sat = diag.sat || satAfe;
end

diag.afe = z;

% ADC 采样抖动在慢变量模型中用一个与信号幅度相关的小噪声近似。
if p.adc.jitterRms > 0
    z = z + (p.adc.jitterRms/Ts)*1e-3*abs(z).*randn(size(z));
end

% 故障注入：ADC stuck-at。
if isfinite(p.fault.injectTime) && st.t >= p.fault.injectTime && strcmpi(p.fault.type,'adc_stuck')
    adc = p.fault.magnitude*ones(4,1);
    diag.sat = true;
    return;
end

% ADC 满量程饱和。
[z, satAdc] = HRG_WA_clip(z, -p.adc.fullScale, p.adc.fullScale);
diag.sat = diag.sat || satAdc;

% 量化。
qstep = 2*p.adc.fullScale/(2^p.adc.bits);
diag.qstep = qstep;
if p.adc.enableDither
    z = z + qstep*(rand(size(z))-0.5);
end
adc = qstep*round(z/qstep);
end
