function [series,metrics] = three_angle_series(c,angleCandidates,scoreStart)
% 将机械、未量化 C/V 和已发布闭环角转换为同一检测中心、同一角锚点。
% angleCandidates 逐候选帧输出，三条 Az4 使用 atan2 包裹到 [-pi,pi]。
% 比较只穿过共同有效且连续的拍；失锁或缺帧后保留 NaN，避免静默重锚。
arguments
    c (1,1) struct
    angleCandidates (:,10) double
    scoreStart (1,1) double {mustBeFinite,mustBeNonnegative} = 0
end
t = angleCandidates(:,1);
assert(all(isfinite(angleCandidates),'all') && all(diff(t)>0), ...
    '候选帧必须有限且按发布时间严格递增。');
tick = round(t/c.Ts);
assert(all(abs(t/c.Ts-tick)<1e-5) && ...
    all(mod(tick-c.validEnd-c.adcLatency,c.frame)==0), ...
    '候选帧时间与当前模型时序不一致。');
delay = (c.validEnd+c.adcLatency-(c.validStart+c.validEnd-1)/2)*c.Ts;
center = t-delay;
valid = all(angleCandidates(:,5:8)==1,2) & angleCandidates(:,10)==1;
score = center>=scoreStart;
used = false(size(t));
eligible = find(score,1);
start = find(score & valid,1);
if ~isempty(start)
    stop = start;
    while stop<numel(t) && valid(stop+1) && tick(stop+1)-tick(stop)==c.frame
        stop = stop+1;
    end
    used(start:stop) = true;
end

% 原导航按 -Δ(4β)/(4B) 累加。逐窗先取主值增量再解包裹，最后统一置零。
physical = nan(numel(t),2);
angles = nan(numel(t),5);
errors = nan(numel(t),4);
if any(used)
    a = angleCandidates(used,2:4);
    step = diff(a,1,1);
    az4 = [zeros(1,3);cumsum(atan2(sin(step),cos(step)),1)];
    physical(used,:) = az4(:,1:2)/4;
    equivalent = -az4/(4*c.B);
    truth = c.omega*(center(used)-center(start));
    published = angleCandidates(used,9)-angleCandidates(start,9);
    angles(used,:) = [truth,equivalent,published];
    errors(used,:) = [equivalent(:,1)-truth,equivalent(:,2)-equivalent(:,1), ...
        published-equivalent(:,2),published-truth];
end
finiteDeltas = errors(used,:);
sumDelta = sum(finiteDeltas(:,1:3),2)-finiteDeltas(:,4);
endDelta = angles(used,4)-angles(used,5);
assert(all(abs(endDelta)<1e-9),'量化驻波解包裹与原发布角不一致。');
assert(all(abs(sumDelta)<1e-12),'角误差分解代数残差超限。');

series = table(t,center,angleCandidates(:,2),angleCandidates(:,3),angleCandidates(:,4), ...
    logical(angleCandidates(:,5)),logical(angleCandidates(:,6)),logical(angleCandidates(:,7)), ...
    logical(angleCandidates(:,8)),logical(angleCandidates(:,10)),score,used, ...
    angles(:,1),physical(:,1),physical(:,2),angles(:,2),angles(:,3),angles(:,4),angles(:,5), ...
    errors(:,1),errors(:,2),errors(:,3),errors(:,4), ...
    'VariableNames',{'t_publish_s','t_center_s','mechanical_az4_rad','clean_cv_az4_rad', ...
    'closed_az4_rad','mechanical_usable','clean_cv_usable','closed_usable','accepted', ...
    'closed_angle_valid','scoring_candidate','common_scored','truth_body_rel_rad', ...
    'mechanical_beta_rel_rad','clean_cv_beta_rel_rad','mechanical_body_rel_rad', ...
    'clean_cv_body_rel_rad','reconstructed_body_rel_rad','published_body_rel_rad', ...
    'mechanical_minus_truth_rad','clean_cv_minus_mechanical_rad', ...
    'published_minus_clean_cv_rad','published_minus_truth_rad'});
expected = max(0,floor((round(c.duration/c.Ts)-(c.validEnd+c.adcLatency))/c.frame)+1);
firstAnchor = NaN;
if ~isempty(start), firstAnchor = center(start); end
firstEligible = NaN;
if ~isempty(eligible), firstEligible = center(eligible); end
metrics = struct('mode',c.mode,'rate_rad_s',c.omega,'bryan_factor',c.B, ...
    'center_to_publish_s',delay,'score_start_s',scoreStart,'first_candidate_in_score_s',firstEligible, ...
    'common_anchor_s',firstAnchor,'expected_candidates',expected,'observed_candidates',numel(t), ...
    'accepted_candidates',nnz(angleCandidates(:,8)),'joint_usable_candidates',nnz(valid), ...
    'common_scored_candidates',nnz(used),'score_candidates',nnz(score), ...
    'mechanical_rms_rad',rmsValue(finiteDeltas(:,1)), ...
    'readout_rms_rad',rmsValue(finiteDeltas(:,2)), ...
    'publication_rms_rad',rmsValue(finiteDeltas(:,3)), ...
    'total_rms_rad',rmsValue(finiteDeltas(:,4)), ...
    'mechanical_slope_error_rad_s',fitSlope(center(used),finiteDeltas(:,1)), ...
    'readout_slope_error_rad_s',fitSlope(center(used),finiteDeltas(:,2)), ...
    'publication_slope_error_rad_s',fitSlope(center(used),finiteDeltas(:,3)), ...
    'total_slope_error_rad_s',fitSlope(center(used),finiteDeltas(:,4)), ...
    'max_decomposition_residual_rad',peak(sumDelta),'max_reconstructed_publication_delta_rad',peak(endDelta));
end

function y = rmsValue(x)
% 共同有效帧为空时返回 NaN，避免空数据误判为零误差。
y = sqrt(mean(x.^2));
end

function m = fitSlope(t,y)
% 使用完全相同的检测窗中心对各误差分量拟合斜率。
m = NaN;
if numel(t)>=2
    p = polyfit(t-t(1),y,1);
    m = p(1);
end
end

function y = peak(x)
% JSON 用空值表示未获得可比较的有效帧。
y = NaN;
if ~isempty(x), y = max(abs(x)); end
end
