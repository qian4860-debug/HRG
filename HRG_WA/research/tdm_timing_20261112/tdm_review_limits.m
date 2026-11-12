function result = tdm_review_limits()
% 复算三种边界：路径增益规范自由度、窗口条件与载波同向的不可检出误差。
here = fileparts(mfilename('fullpath'));
residual = fullfile(here,'..','tdm_residual_20261112');
addpath(residual);
b = jsondecode(fileread(fullfile(residual,'tdm_residual_benchmark.json')));
fs = b.fs_Hz;
n = round(fs/b.carrier_Hz);
time = (0:2*n-1)'/fs;
phase = 2*pi*b.carrier_Hz*(b.physical_samples(1)/fs+time);
late = (0:2*n-1)'>=n;
weights = 1./b.weight_noise_std_V(1)^2*ones(2*n,1);
weights(late) = 1./b.weight_noise_std_V(2)^2;
templates = exp(-time./b.template_tau_s(:).');
z = 2*pi*b.physical_aaf_pole_Hz*time;
aaf = [templates,exp(-z).*z.^(0:3)];
cycle = [.5 .7 1 1.15 2];
window = [];
for k = cycle
    use = 1:round(k*n);
    for physics = [false true]
        if physics
            % 在完整检测窗固定模板，再截取前缀，不以短窗数据重新拟合。
            template = orth(aaf);
        else
            template = templates;
        end
        d = tdm_residual_design(phase(use),template(use,:),late(use),Weights=weights(use));
        row = struct('cycles',k,'includes_aaf',physics, ...
            'carrier_info_fraction',d.carrier_info_fraction,'joint_design_ok',d.jointDesignOK, ...
            'late_design_ok',d.lateDesignOK);
        window = [window;row]; %#ok<AGROW>
    end
end
assert(window(3).joint_design_ok && ~window(6).joint_design_ok && window(8).joint_design_ok);

% 模型中与载波完全同向的干扰无法由留出误差检出。
d = tdm_residual_design(phase,orth(aaf),late,Weights=weights);
carrier = [cos(phase),sin(phase)];
disturbance = carrier*[0.005 0;0 0.001];
hiddenResidual = max(abs(d.holdoutErrorMap*disturbance),[],'all');
hiddenIQ = max(abs(d.jointCarrierMap*disturbance),[],'all');
assert(hiddenResidual<1e-12 && abs(hiddenIQ-.005)<1e-12);

% 两电极、两电子链，每对各有两条自由未知路径。重复路径只给路径之差。
a = zeros(8,12);
row = 0;
for electrode=1:2
    for channel=1:2
        for path=1:2
            row = row+1;
            a(row,[electrode,2+channel,4+row]) = 1;
        end
    end
end
assert(rank(a)==8 && size(null(a),2)==4);
result = struct('window',window,'carrier_aligned_holdout_max_V',hiddenResidual, ...
    'carrier_aligned_iq_bias_max_V',hiddenIQ, ...
    'route_free_rank',rank(a),'route_free_unknowns',size(a,2),'route_free_nullity',size(null(a),2));
end
