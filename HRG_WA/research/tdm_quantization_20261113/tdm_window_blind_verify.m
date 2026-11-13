function result = tdm_window_blind_verify(outPath)
% 使用三组独立合成数据检验冻结的分时 I/Q 残差估计器。
% 窗口均从检测接通起算，后窗从原有效窗起点起算。
% 合成真值为驻波方位。评分不等同于真实表头闭环机体角度。
arguments
    outPath (1,:) char = fullfile(fileparts(mfilename('fullpath')),'window_blind_verification.json')
end
here = fileparts(mfilename('fullpath'));
residualDir = fullfile(here,'..','tdm_residual_20261112');
addpath(residualDir);
prior = jsondecode(fileread(fullfile(residualDir,'tdm_residual_benchmark.json')));

% 估计器、门限与噪声模型先冻结。三组新种子只用于生成检验数据。
fs = prior.fs_Hz;
f0 = prior.carrier_Hz;
n = round(fs/f0);
ticks = (0:2*n-1)';
t = ticks/fs;
phase = 2*pi*f0*(t+prior.physical_samples(1)/fs);
carrier = [cos(phase),sin(phase)];
late = ticks>=n;
z = 2*pi*prior.physical_aaf_pole_Hz*t;
physicalBasis = orth([exp(-t./prior.template_tau_s(:).'), ...
    exp(-z).*z.^(0:prior.physical_aaf_order-1)]);
nominalVariance = repmat(prior.weight_noise_std_V(1)^2,size(t));
nominalVariance(late) = prior.weight_noise_std_V(2)^2;
inputNoiseStd = sqrt(max(0,nominalVariance-prior.adc_step_V^2/12));
limit = prior.holdout_limit_V;
maxAngleError = 1e-3;
minCoverage = .95;
samplesPerGroup = 128;
poles = {[13.6 13.6 13.6 13.6]*1e3,[25.5 25.5 25.5]*1e3,[12 17 21 33 45]*1e3};
names = ["low_four_poles";"high_three_poles";"heterogeneous_five_poles"];
seeds = [80273 114467 160493];
groups = repmat(struct(),numel(names),1);
for k = 1:numel(names)
    groups(k).name = names(k);
    groups(k).seed = seeds(k);
    groups(k).poles_Hz = poles{k};
    groups(k).data = createData(carrier,phase,t,late,prior,poles{k},seeds(k),inputNoiseStd,samplesPerGroup);
end
shared = concatGroups(groups);
cycles = [1.30 1.50 1.75 2.00];
rows = [];
nativeCheck = struct();
for k = 1:numel(cycles)
    use = 1:round(cycles(k)*n);
    d = tdm_residual_design(phase(use),physicalBasis(use,:),late(use), ...
        Weights=1./nominalVariance(use));
    [overall,modes,angleError,estimates] = score(shared,use,d,limit,maxAngleError);
    byGroup = [];
    for j = 1:numel(groups)
        offset = (j-1)*samplesPerGroup;
        frameIdx = offset+(1:samplesPerGroup);
        counts = scoreSet(modes(frameIdx),angleError(frameIdx),maxAngleError);
        byGroup = [byGroup;struct('name',groups(j).name,'seed',groups(j).seed, ...
            'true_poles_Hz',groups(j).poles_Hz,'metrics',counts)]; %#ok<AGROW>
    end
    % 常规工况与故障压力工况分列，同时保留包含全部工况的最终输出评分。
    stressed = shared.kind~="nominal";
    regular = scoreSet(modes(~stressed),angleError(~stressed),maxAngleError);
    stressRows = [];
    stressLabels = unique(shared.kind(stressed),'stable');
    for j = 1:numel(stressLabels)
        idx = shared.kind==stressLabels(j);
        stressRows = [stressRows;struct('kind',stressLabels(j), ...
            'metrics',scoreSet(modes(idx),angleError(idx),maxAngleError))]; %#ok<AGROW>
    end
    g5 = overall.published_coverage>=minCoverage && ...
        overall.published_angle_rms_rad<=maxAngleError;
    row = struct('observed_cycles_from_sense_start',cycles(k),'observed_samples',numel(use), ...
        'fallback_late_samples',nnz(late(use)),'normalized_joint_condition',d.condition, ...
        'carrier_info_fraction',d.carrier_info_fraction,'joint_design_ok',d.jointDesignOK, ...
        'late_design_ok',d.lateDesignOK,'all',overall,'regular',regular, ...
        'stress',{stressRows},'groups',{byGroup},'G5_aggregate_pass',g5, ...
        'schedule',schedule(prior,n,numel(use)));
    rows = [rows;row]; %#ok<AGROW>
    fprintf('观察 %.2f 周期：发布角 RMS %.3f mrad，覆盖 %.2f%%，误通过 %d/%d\n', ...
        cycles(k),1e3*overall.published_angle_rms_rad,100*overall.published_coverage, ...
        overall.erroneous_joint_accepted_frames,overall.joint_frames);
    if cycles(k)==1.50
        nativeCheck = verifyNative(shared,use,d,limit,modes,estimates,maxAngleError);
    end
end
result = struct('release',version('-release'), ...
    'scope','Frozen nominal estimator, independent synthetic ADC replay, standing-wave angle', ...
    'frame_count',numel(shared.truth_rad),'seeds',seeds,'frames_per_group',samplesPerGroup, ...
    'published_rms_limit_rad',maxAngleError,'minimum_published_coverage',minCoverage, ...
    'joint_false_accept_abs_error_threshold_rad',maxAngleError, ...
    'holdout_limit_V',limit,'nominal_aaf_pole_Hz',prior.physical_aaf_pole_Hz, ...
    'nominal_aaf_order',prior.physical_aaf_order,'noise_variance_frozen',true, ...
    'rows',{rows},'native_1p5_cycle',{nativeCheck}, ...
    'G6_loop_margin_status','not evaluated: timing-only incremental phase lag', ...
    'G7_rtl_sync_status','not evaluated: schedule and implementation impacts only');
if ~isempty(outPath)
    [fid,msg] = fopen(outPath,'w','n','UTF-8');
    assert(fid>=0,'窗口盲评回执写入失败：%s',msg);
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid,'%s\n',jsonencode(result,'PrettyPrint',true));
end
end

function data = createData(carrier,phase,t,late,p,frequency,seed,noiseStd,count)
% 级联生成端由不同极点和初始状态构成，独立于名义估计模板。
stream = RandStream('mt19937ar','Seed',seed);
order = numel(frequency);
poles = 2*pi*frequency;
state = eye(order);
transition = expm((-diag(poles)+diag(poles(2:end),-1))*(t(2)-t(1)));
response = zeros(numel(t),order);
for sample = 1:numel(t)
    response(sample,:) = state(end,:);
    state = transition*state;
end
transient = exp(-t./([18 112]*1e-6));
data.voltage = zeros(numel(t),2,count);
data.clip = false(numel(t),count);
data.truth_rad = zeros(count,1);
data.kind = repmat("nominal",count,1);
for k = 1:count
    beta = (rand(stream)-.5)*pi/2;
    commonPhase = (rand(stream)-.5)*2*pi;
    direction = [cos(2*beta),sin(2*beta)];
    quadrature = [-direction(2),direction(1)];
    iq = (.045+.04*rand(stream))*[cos(commonPhase),sin(commonPhase); ...
        -sin(commonPhase),cos(commonPhase)]*[direction;.04*quadrature];
    truth = carrier*iq;
    input = truth+response*(.032*randn(stream,order,2)) ...
        +transient*(.009*randn(stream,2,2))+noiseStd.*randn(stream,numel(t),2);
    if k>count-16
        % 预先分配压力帧，每组各四帧。与载波同向的干扰检验留出盲区。
        switch mod(k-1,4)
            case 0
                input = input+sin(phase+commonPhase)*[.0035 -.004];
                data.kind(k) = "carrier_aligned_interference";
            case 1
                input = input+exp(-t/105e-6).*sin(2*pi*7100*t)*[.018 -.015];
                data.kind(k) = "unmodeled_ringing";
            case 2
                input(7,1) = p.adc_max_V+4*p.adc_step_V;
                data.kind(k) = "early_clip";
            otherwise
                input(find(late,1)+5,2) = p.adc_min_V-4*p.adc_step_V;
                data.kind(k) = "late_clip";
        end
    end
    data.clip(:,k) = any(input<p.adc_min_V | input>p.adc_max_V,2);
    data.voltage(:,:,k) = min(p.adc_max_V,max(p.adc_min_V, ...
        p.adc_step_V*round(input/p.adc_step_V)));
    data.truth_rad(k) = bearing(iq);
end
end

function data = concatGroups(groups)
groupData = [groups.data];
data = struct('voltage',cat(3,groupData.voltage),'clip',cat(2,groupData.clip), ...
    'truth_rad',vertcat(groupData.truth_rad),'kind',vertcat(groupData.kind));
end

function [metrics,mode,error,estimates] = score(data,use,d,limit,maxError)
% 只从实际发布的联合或后窗输出计算 RMS。无效帧进入覆盖率。
frames = numel(data.truth_rad);
mode = zeros(frames,1);
error = nan(frames,1);
estimates = nan(2,2,frames);
for k = 1:frames
    [iq,info] = tdm_residual_iq(data.voltage(use,:,k),d, ...
        Clipped=data.clip(use,k),HoldoutLimit_V=limit);
    mode(k) = 2*(info.status=="joint")+(info.status=="late_fallback");
    estimates(:,:,k) = iq;
    delta = bearing(iq)-data.truth_rad(k);
    error(k) = atan2(sin(4*delta),cos(4*delta))/4;
end
metrics = scoreSet(mode,error,maxError);
end

function metrics = scoreSet(mode,error,maxError)
joint = mode==2;
fallback = mode==1;
published = mode>0;
metrics = struct('frames',numel(mode),'joint_frames',nnz(joint), ...
    'joint_rejected_frames',nnz(~joint),'late_fallback_frames',nnz(fallback), ...
    'invalid_frames',nnz(~published),'published_coverage',mean(published), ...
    'joint_angle_rms_rad',sqrt(mean(error(joint).^2)), ...
    'fallback_angle_rms_rad',sqrt(mean(error(fallback).^2)), ...
    'published_angle_rms_rad',sqrt(mean(error(published).^2)), ...
    'erroneous_joint_accepted_frames',nnz(joint & abs(error)>maxError), ...
    'published_frames_over_abs_threshold',nnz(published & abs(error)>maxError));
end

function beta = bearing(iq)
% 驻波角模 π/2。双通道载波共同相位不影响空间方位。
energy = sum(iq.^2,1);
beta = atan2(2*dot(iq(:,1),iq(:,2)),energy(1)-energy(2))/4;
end

function timing = schedule(p,n,windowSamples)
% 时间方案 A 早窗参与估计，保持原驱动周期。B 保持原建立期并延长 ADC 有效窗。
fs = p.fs_Hz;
physical = p.physical_samples;
sense = physical(1);
validStart = physical(2);
validEnd = physical(3);
originalFrame = 4*n;
pipeline = p.adc_pipeline_ticks;
earlyEnd = sense+windowSamples;
extendedEnd = validStart+windowSamples;
extendedFrame = originalFrame+extendedEnd-validEnd;
baselinePublish = validEnd+pipeline;
baselineCenter = (validStart+validEnd-1)/2;
timing = struct('baseline',timingRow(fs,n,originalFrame,validStart,validEnd,pipeline), ...
    'early_same_frame',timingRow(fs,n,originalFrame,sense,earlyEnd,pipeline), ...
    'extended_valid_window',timingRow(fs,n,extendedFrame,validStart,extendedEnd,pipeline));
timing.early_same_frame.publish_advance_s = (baselinePublish-earlyEnd-pipeline)/fs;
timing.extended_valid_window.frame_rate_change_percent = 100*(originalFrame/extendedFrame-1);
timing.extended_valid_window.publish_delay_increase_s = (extendedEnd-validEnd)/fs;
timing.extended_valid_window.estimated_extra_delay_s = ...
    ((extendedFrame-originalFrame)/2+(validStart+extendedEnd-1)/2-baselineCenter)/fs;
% 额外时延仅用于估算环路相位变化。真实交越频率和相位裕度需辨识。
timing.extended_valid_window.illustrative_frequency_Hz = [4 10];
timing.extended_valid_window.illustrative_extra_lag_deg = ...
    360*[4 10]*timing.extended_valid_window.estimated_extra_delay_s;
end

function row = timingRow(fs,n,frame,startTick,endTick,pipeline)
publish = endTick+pipeline;
center = (startTick+endTick-1)/2;
row = struct('frame_ticks',frame,'frame_rate_Hz',fs/frame,'window_first_tick',startTick, ...
    'window_last_tick',endTick-1,'publish_tick',publish, ...
    'window_center_to_publish_s',(publish-center)/fs, ...
    'publish_to_next_drive_s',(frame-publish)/fs, ...
    'frame_phase_advance_deg',360*mod(frame,n)/n, ...
    'carrier_phase_repeat_frames',n/gcd(frame,n), ...
    'aligned_to_DAC_divisor_25',mod(frame,25)==0);
end

function result = verifyNative(data,use,design,limit,mode,iq,maxError)
% 每类压力帧和三组正常帧均被代表，检查原生输出和门禁。
choose = [1:4 129:132 257:260 find(data.kind~="nominal").'];
path = tdm_residual_build_observer(design,limit,tempname,'hrg_tdm_window_blind_native');
names = data.kind(choose)+"_"+string(choose(:));
native = tdm_residual_verify_native_frames(path,design,limit, ...
    data.voltage(use,:,choose),data.clip(use,choose),names,mode(choose));
actual = cat(3,native.iq);
expected = iq(:,:,choose);
assert(isequaln(actual,expected));
actualMode = [native.mode].';
errors = nan(numel(choose),1);
for k = 1:numel(choose)
    delta = bearing(actual(:,:,k))-data.truth_rad(choose(k));
    errors(k) = atan2(sin(4*delta),cos(4*delta))/4;
end
result = struct('frames',numel(choose),'matches_matlab',true, ...
    'max_iq_difference_V',max([native.max_iq_difference_V]), ...
    'max_holdout_difference_V',max([native.max_holdout_difference_V]), ...
    'metrics',scoreSet(actualMode,errors,maxError));
end
