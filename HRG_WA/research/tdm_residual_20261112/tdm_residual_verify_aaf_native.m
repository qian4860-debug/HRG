function result = tdm_residual_verify_aaf_native(outPath)
% 使用 AAF 失配试验的同一量化样本，对拍原生观测器与 MATLAB。
% 复用冻结的名义模板、噪声权重与门限，不从失配数据重新标定。
arguments
    outPath (1,:) char = fullfile(fileparts(mfilename('fullpath')),'native_aaf_holdout.json')
end
[matlabResult,replay] = tdm_residual_aaf_holdout('');
modelPath = tdm_residual_build_observer(replay.design,replay.holdoutLimit_V,tempname, ...
    'hrg_tdm_residual_aaf_holdout_check');

% 所有工况在一次 Simulink 运行中回放，避免重复编译观测器。
scenarios = replay.cases;
samples = cat(3,scenarios.samples);
clipped = cat(2,scenarios.clips);
matlabMode = vertcat(scenarios.mode);
frameCount = numel(matlabMode);
names = strings(frameCount,1);
first = 1;
for k = 1:numel(scenarios)
    count = numel(scenarios(k).mode);
    rows = first:first+count-1;
    names(rows) = string(scenarios(k).name)+"_frame_"+string((1:count)');
    first = first+count;
end
% 单列失配扫描可能全通过。另加三个门禁对照，验证回退与无效的差异。
controlSamples = zeros(size(samples,1),2,3);
controlClips = false(size(samples,1),3);
controlClips(find(~replay.design.lateMask,1),1) = true;
controlClips(find(replay.design.lateMask,1),2) = true;
controlSamples(replay.design.holdoutMask,:,3) = 10*replay.holdoutLimit_V;
controlNames = ["control_early_clip";"control_late_clip";"control_holdout_failure"];
native = tdm_residual_verify_native_frames(modelPath,replay.design,replay.holdoutLimit_V, ...
    cat(3,samples,controlSamples),cat(2,clipped,controlClips),[names;controlNames], ...
    [matlabMode;1;0;1]);
result = struct('release',version('-release'), ...
    'scope','native observer parity on identical frozen-estimator mismatch replay', ...
    'matlab_metrics_receipt','aaf_holdout.json', ...
    'holdout_limit_V',replay.holdoutLimit_V, ...
    'total_frames',frameCount,'cases',[],'gate_controls',{native(frameCount+1:end)});

% 联合通过、后窗回退与无效分别计数。回退包含已发布的后窗估计。
first = 1;
for k = 1:numel(scenarios)
    scenario = scenarios(k);
    count = numel(scenario.mode);
    rows = first:first+count-1;
    frames = native(rows);
    mode = [frames.mode].';
    actualIQ = cat(3,frames.iq);
    actualHoldout = vertcat(frames.holdout_rms_V);
    iqGap = compareFinite(actualIQ,scenario.iq);
    rmsGap = compareFinite(actualHoldout,scenario.heldout_rms_V);
    score = matlabResult.cases(k);
    assert(score.name==string(scenario.name) && score.joint_accepted_frames==nnz(mode==2) && ...
        score.late_fallback_frames==nnz(mode==1) && score.final_invalid_frames==nnz(mode==0));
    % 逐帧 I/Q 与门禁相同，因此沿用同一角度转换与共同帧评分。
    row = struct('name',string(scenario.name),'frames',count, ...
        'joint',nnz(mode==2),'late_fallback',nnz(mode==1),'invalid',nnz(mode==0), ...
        'max_iq_difference_V',iqGap,'max_holdout_difference_V',rmsGap, ...
        'overall_guarded_rms_rad',score.overall_guarded_rms_rad, ...
        'overall_same_frame_late_rms_rad',score.overall_same_frame_late_rms_rad, ...
        'paired_guarded_to_late_rms_ratio',score.paired_guarded_to_late_rms_ratio);
    result.cases = [result.cases; row]; %#ok<AGROW>
    fprintf('%s：联合 %d，后窗 %d，无效 %d，最大 IQ 差 %.3g V\n', ...
        row.name,row.joint,row.late_fallback,row.invalid,iqGap);
    first = first+count;
end
result.max_iq_difference_V = max([result.cases.max_iq_difference_V]);
result.max_holdout_difference_V = max([result.cases.max_holdout_difference_V]);
if ~isempty(outPath)
    [fid,msg] = fopen(outPath,'w','n','UTF-8');
    assert(fid>=0,'原生 AAF 回执写入失败：%s',msg);
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid,'%s\n',jsonencode(result,'PrettyPrint',true));
end
end

function difference = compareFinite(actual,expected)
% MATLAB 与原生输出同时核对 NaN 位置和所有有限数据的最大差值。
assert(isequal(size(actual),size(expected)) && isequal(isnan(actual),isnan(expected)), ...
    '原生 AAF 回放与 MATLAB 的有效数据形状不同。');
valid = isfinite(expected);
delta = abs(actual(valid)-expected(valid));
difference = max([0;delta(:)]);
assert(difference<1e-12,'原生 AAF 回放与 MATLAB 的数值不同。');
end
