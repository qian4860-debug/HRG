function result = tdm_residual_verify_observer(outDir)
% 以 6800 Hz 五电极分时窗口生成原生观测器，逐帧核对 MATLAB 与模型。
% 验证数据使用人工残差，真实闭环采样的有效性另由残差试验评分。
arguments
    outDir (1,:) char = tempname
end
here = fileparts(mfilename('fullpath'));
project = fileparts(fileparts(here));
addpath(fullfile(project,'HRG_WA_simulink','piezo_v10','five_electrode_20261110'));
c = five_config('tdm_shared',.5,struct('duration',.006,'dac_divisor',25));
slot = (c.senseStart:c.validEnd-1)';
phase = c.w*c.Ts*slot;
age = c.Ts*(slot-slot(1));
carrier = [cos(phase),sin(phase)];
late = slot>=c.validStart;
template = exp(-age/15e-6);
limit = 0.5e-3;
design = tdm_residual_design(phase,template,late);
assert(design.jointDesignOK && design.lateDesignOK,'验证设计应同时支持两路估计。');

% 同一已知双轴载波依次测试无故障、早窗过载、晚窗过载和留出失配。
target = [0.067 0.025; 0.005 -0.003];
nominal = carrier*target+template*[0.035 -0.022];
n = numel(slot);
values = repmat(nominal,1,1,4);
values(design.holdoutMask,:,4) = values(design.holdoutMask,:,4)+[0.003 -0.003];
clipped = false(n,4);
clipped(find(~late,1),2) = true;
clipped(find(late,1),3) = true;
path = tdm_residual_build_observer(design,limit,tempname);
names = ["matched";"early_clip";"late_clip";"heldout_mismatch"];
cases = tdm_residual_verify_native_frames(path,design,limit,values,clipped,names,[2;1;0;1]);
assert(max(abs(cases(1).iq-target),[],'all')<1e-12,'联合估计的已知真值未恢复。');

% 瞬态列与载波完全共线时，验证原生门禁自动选晚窗。
confounded = tdm_residual_design(phase,carrier(:,1),late);
assert(~confounded.jointDesignOK && confounded.lateDesignOK);
fallbackPath = tdm_residual_build_observer(confounded,limit,tempname);
cases = [cases; tdm_residual_verify_native_frames(fallbackPath,confounded,limit,nominal,false(n,1), ...
    "rank_failure",1)];

% 回放五电极闭环仿真的模拟 ADC 电压。用同一 ADC 规则扩展量化到早窗，
% 已有晚窗码须与闭环采样逐点一致，观测器不向闭环回写 I/Q。
[captureValues,captureClips] = replayCapture(c,slot,late);
captureNames = "model_frame_"+string((4:7)');
% 预先登记噪声与量化预算。两种模板使用相同权重和门限。
captureVariance = [1.6e-3 .5e-3].^2+c.adcStep^2/12;
weights = ones(n,1)/captureVariance(1);
weights(late) = 1/captureVariance(2);
captureLimit = 1.3*sqrt(max(captureVariance));
replayDesign = tdm_residual_design(phase,template,late,Weights=weights);
simplePath = tdm_residual_build_observer(replayDesign,captureLimit,tempname);
modelCases = tdm_residual_verify_native_frames(simplePath,replayDesign,captureLimit,captureValues,captureClips,captureNames,[]);
z = 2*pi*c.p.afe_bw(1)*age;
physical = orth([exp(-age./([24 90]*1e-6)),exp(-z).*z.^(0:c.p.aaf_order-1)]);
physicalDesign = tdm_residual_design(phase,physical,late,Weights=weights);
assert(physicalDesign.jointDesignOK);
physicalPath = tdm_residual_build_observer(physicalDesign,captureLimit,outDir);
physicalCases = tdm_residual_verify_native_frames(physicalPath,physicalDesign,captureLimit,captureValues,captureClips, ...
    "aaf_"+captureNames,[]);
result = struct('release',version('-release'),'scope','native frame-vector observer with synthetic and modeled ADC replay', ...
    'sample_count',n,'late_sample_count',nnz(late),'synthetic_holdout_limit_V',limit,'cases',{cases}, ...
    'model_holdout_limit_V',captureLimit,'model_noise_budget_V',sqrt(captureVariance), ...
    'saved_model_condition',physicalDesign.condition, ...
    'saved_model_carrier_info',physicalDesign.carrier_info_fraction, ...
    'model_adc_replay',{modelCases},'model_adc_aaf_replay',{physicalCases});
end

function [samples,clipped] = replayCapture(c,slot,late)
% 按物理 ADC 时间戳提取 4 至 7 号完整检测窗，避开初始化。
[~,~,~,monitor] = five_reference(c);
samples = zeros(numel(slot),2,4);
clipped = false(numel(slot),4);
for k = 1:4
    sampleTicks = (k+3)*c.frame+slot;
    [found,rows] = ismember(sampleTicks,monitor(:,1));
    assert(all(found) && isequal(logical(monitor(rows,2)),late));
    voltage = monitor(rows,5:6);
    samples(:,:,k) = min(c.adcMax,max(c.adcMin,c.adcStep*round(voltage/c.adcStep)));
    clipped(:,k) = any(voltage<c.adcMin | voltage>c.adcMax,2);
    assert(isequal(samples(late,:,k),monitor(rows(late),7:8)));
    assert(isequal(clipped(late,k),logical(monitor(rows(late),9))));
end
end
