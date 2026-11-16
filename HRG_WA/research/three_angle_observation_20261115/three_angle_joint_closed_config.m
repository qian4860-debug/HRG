function c = three_angle_joint_closed_config(profile,rate,split,beta,duration,adcBits,extra,withShape)
% 回填冻结的泄放电阻，并选择是否启用冻结 DAC 整形系数。
arguments
    profile (1,1) struct
    rate (1,1) double
    split (1,1) double
    beta (1,1) double
    duration (1,1) double
    adcBits (1,1) double
    extra (1,1) struct = struct()
    withShape (1,1) logical = true
end
if ~isfield(extra,'bleed_R'), extra.bleed_R = profile.bleed_R_ohm; end
c = three_mode_split_config('tdm_shared',rate,split,beta,duration,adcBits,extra);
if withShape
    assert(iscolumn(profile.coeffs) && numel(profile.coeffs)==2+2*numel(profile.taus_s));
    assert(all(isfinite(profile.coeffs)) && all(isfinite(profile.taus_s) & profile.taus_s>0));
    c.dacShape = struct('coeffs',profile.coeffs,'taus_s',profile.taus_s);
end
end
