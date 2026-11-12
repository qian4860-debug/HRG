function [iq, info] = tdm_residual_iq(y, design, opts)
% 双轴分时 I/Q 与开关残差联合估计。y 为物理采样时刻的两列 ADC 电压。
% design 由 tdm_residual_design 生成。返回 iq = [Ix Iy; Qx Qy]（V）。
% 条件、留出残差或过载超限时回退后窗；后窗不可用时输出 NaN。
arguments
    y (:,2) double {mustBeFinite}
    design (1,1) struct
    opts.Clipped (:,1) logical = false(size(y,1),1)
    opts.HoldoutLimit_V (1,1) double {mustBePositive} = Inf
end
n = size(y,1);
assert(n==size(design.jointCarrierMap,2) && numel(opts.Clipped)==n, ...
    'ADC 数据、过载标记和估计映射的采样数必须一致。');
info = struct('status',"joint",'reason',"none",'condition',design.condition, ...
    'carrier_info_fraction',design.carrier_info_fraction, ...
    'holdout_rms_V',[NaN NaN],'samples_used',n);
if any(opts.Clipped)
    info.reason = "clip";
elseif ~design.jointDesignOK
    info.reason = "identifiability";
else
    heldoutError = design.holdoutErrorMap*y;
    info.holdout_rms_V = sqrt(mean(heldoutError.^2,1));
    if any(info.holdout_rms_V>opts.HoldoutLimit_V)
        info.reason = "template_mismatch";
    end
end
if info.reason=="none"
    iq = design.jointCarrierMap*y;
elseif design.lateDesignOK && ~any(opts.Clipped(design.lateMask))
    % 与联合估计使用同一采样相位和后窗定义；不发布过载的后窗。
    iq = design.lateCarrierMap*y;
    info.status = "late_fallback";
    info.samples_used = nnz(design.lateMask);
else
    iq = nan(2);
    info.status = "invalid";
    info.samples_used = 0;
end
end
