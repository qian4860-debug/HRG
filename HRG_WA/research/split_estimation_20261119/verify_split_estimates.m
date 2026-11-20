function verify_split_estimates(file)
% 独立检查估计接口的单位、共模/互换不变性、拒绝条件和 JSON 逐次运行计数。
if nargin == 0
    file = fullfile(fileparts(mfilename('fullpath')),'estimates.json');
end
t = (0:0.005:1)';
common = exp(1i*(0.2*t+0.03*t.^2));
v = exp(-t/1.4).*common.*[ones(size(t)),exp(1i*2*pi*0.025*t)];
nominal = estimate_ringdown_split(t,v);
swapped = estimate_ringdown_split(t,v(:,[2,1]));
zero = estimate_ringdown_split(t,[ones(size(t)),1i*ones(size(t))]);
assert(nominal.valid && abs(nominal.split_est_mHz-25) < 1e-7);
assert(swapped.valid && abs(nominal.split_est_mHz-swapped.split_est_mHz) < 1e-7);
assert(zero.valid && abs(zero.split_est_mHz) < 1e-9);
v(:,1) = 0;
assert(~estimate_ringdown_split(t,v).valid);
t(100) = t(99);
assert(~estimate_ringdown_split(t,v).valid);

% 汇总字段从原始行重算。时间戳、支持区间与实际标签分别核验。
data = jsondecode(fileread(file));
rows = data.rows;
assert(numel(rows) == 1280 && numel(data.summary) == 6);
ids = string({rows.run_id});
assert(numel(unique(ids)) == 32);
for id = reshape(unique(ids),1,[])
    r = rows(ids == id);
    assert(isequal([r.t_s],0.5:0.5:20));
end
for k = 1:numel(data.summary)
    s = data.summary(k);
    r = rows(string({rows.case_name}) == s.case_name);
    v = r([r.valid]);
    assert(s.ticks == numel(r) && s.valid_ticks == numel(v));
    assert(s.run_count == numel(unique(string({r.run_id}))));
    assert(all([r.observed_from_s] <= [r.support_end_s]) && all([r.support_end_s] <= [r.t_s]+1e-12));
    assert(all([v.uncertainty_mHz] <= data.budget_mHz) && all([v.valid_until_s] > [v.t_s]));
    assert(s.valid_over_budget == nnz(abs([v.split_est_mHz]-[v.split_true_mHz]) > data.budget_mHz));
    assert(s.valid_over_50mHz == nnz([v.split_est_mHz] > 50));
end
fprintf('32 runs and 1280 ticks checked; estimator unit, channel swap, clock and weak-mode checks passed.\n');
end
