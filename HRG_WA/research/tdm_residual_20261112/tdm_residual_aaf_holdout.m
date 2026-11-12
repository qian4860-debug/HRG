function [result,replay] = tdm_residual_aaf_holdout(outPath)
% 固定名义 20 kHz 四阶 AAF 的联合估计器，盲评实际极点和阶数变化。
% 独立 RC 级联提供已知稳态 I/Q。五电极回放用实际 AAF 极点和中间级
% ADC 观测抽头，参考为未注入残差与噪声的后窗；两类证据独立计分。
arguments
    outPath (1,:) char = fullfile(fileparts(mfilename('fullpath')),'aaf_holdout.json')
end
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here,'..','..','HRG_WA_simulink','piezo_v10','five_electrode_20261110'));
old = jsondecode(fileread(fullfile(here,'tdm_residual_benchmark.json')));
nominal = five_config('tdm_shared',.5,struct('duration',.04,'dac_divisor',25));
slot = (nominal.senseStart:nominal.validEnd-1)';
age = (slot-slot(1))*nominal.Ts;
phase = nominal.w*slot*nominal.Ts;
late = slot>=nominal.validStart;
n = numel(slot);
carrier = [cos(phase),sin(phase)];
[ql,rl] = qr(carrier(late,:),0);
lateMap = rl\ql';
[qf,rf] = qr(carrier,0);
fullMap = rf\qf';

% 从上一轮回执恢复冻结模板、权重和留出门限，并检查信息量和条件数相同。
tau = old.template_tau_s(:)';
residual = exp(-age./tau);
z = 2*pi*old.physical_aaf_pole_Hz*age;
basis = orth([residual,exp(-z).*z.^(0:old.physical_aaf_order-1)]);
sigma2 = old.weight_noise_std_V(:).^2;
weights = ones(n,1)/sigma2(1);
weights(late) = 1/sigma2(2);
threshold = old.holdout_limit_V;
d = tdm_residual_design(phase,basis,late,Weights=weights);
assert(d.jointDesignOK && d.lateDesignOK && ...
    abs(d.condition-old.physical_condition)<1e-10 && ...
    abs(d.carrier_info_fraction-old.physical_carrier_info_fraction)<1e-10, ...
    '冻结的估计器和上一轮 AAF 计分板不一致。');

% 真实生成端改变 AAF。混合极点覆盖同一链中各级带宽不相同的情况。
poles = {20000*ones(1,4),14000*ones(1,4),26000*ones(1,4), ...
    20000*ones(1,3),14000*ones(1,3),26000*ones(1,3), ...
    14000*ones(1,2),[14000 14000 14000 35000]};
names = {'nominal','poles_m30','poles_p30','order3','order3_m30','order3_p30', ...
    'order2_m30','mixed_poles'};
nFrames = 60;
scenarioCount = 2*numel(poles)-1;
keepReplay = nargout>1;
reportCases = cell(scenarioCount,1);
replay = struct('design',[],'holdoutLimit_V',threshold,'cases',[]);
if keepReplay
    replay.design = d;
    replayCases = cell(scenarioCount,1);
end
% 预先固定相同的噪声、残差和初始电压样本。所有极点/阶数用同一扰动。
stream = RandStream('mt19937ar','Seed',271126);
noiseStd = repmat(1.6e-3,n,1);
noiseStd(late) = .5e-3;
noise = randn(stream,n,2,nFrames).*noiseStd;
event = (2*rand(stream,2,2,nFrames)-1).*[.024;.016];
initial = (2*rand(stream,4,2,nFrames)-1)*.03;
index = 0;
for k = 1:numel(poles)
    actual = poles{k};
    [clean,truth] = switchedSamples(actual,nominal.Ts,nominal.w,phase,initial);
    % 检查真实 RC 级联的末尾已收敛到独立解析相量，防止符号或取样错拍。
    finalCarrier = carrier(end-9:end,:);
    assert(max(abs(clean(end-9:end,:,1)-finalCarrier*truth(:,:,1)),[],'all')<1e-6);
    record('switched_rc',names{k},actual,clean,truth,eye(4));
    if all(actual==actual(1))
        % 五电极模型当前为相同极点四级 AAF，观测抽头可实取前两级或前三
        % 级的输出。保留原闭环第四级检测抽头，仅改变离线观察的数据路径。
        clean = modelSamples(actual,nFrames,slot,nominal);
        truth = zeros(2,2,nFrames);
        for frame = 1:nFrames
            truth(:,:,frame) = lateMap*clean(late,:,frame);
        end
        record('five_model',names{k},actual,clean,truth,nominal.detect);
    end
end
assert(index==scenarioCount);
result = struct('release',version('-release'), ...
    'scope','Offline frozen estimator on independent switched RC and five-electrode behavioral replay', ...
    'reference_calibration','tdm_residual_benchmark.json', ...
    'nominal_pole_Hz',old.physical_aaf_pole_Hz,'nominal_order',old.physical_aaf_order, ...
    'frozen_condition',d.condition,'frozen_carrier_info_fraction',d.carrier_info_fraction, ...
    'frozen_holdout_limit_V',threshold,'random_seed',271126,'sample_rate_Hz',1/nominal.Ts, ...
    'samples_per_frame',n,'late_samples_per_frame',nnz(late), ...
    'angle_metric','standing-wave orientation beta, modulo pi/2', ...
    'overall_ratio_limit',2,'cases',vertcat(reportCases{:}));
if keepReplay
    replay.cases = vertcat(replayCases{:});
end
if ~isempty(outPath)
    fid = fopen(outPath,'w','n','UTF-8');
    assert(fid>=0,'无法写入 AAF 失配回执。');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid,'%s\n',jsonencode(result,'PrettyPrint',true));
end

    function record(family,label,actual,clean,truth,detector)
        % 每个工况的估计器共用同一量化样本和过载掩码。目标仅用于计分。
        name = string(family)+"_"+string(label);
        samples = zeros(n,2,nFrames);
        clips = false(n,nFrames);
        iq = nan(2,2,nFrames);
        mode = zeros(nFrames,1);
        heldout = nan(nFrames,2);
        err = nan(nFrames,4);
        cleanErr = nan(nFrames,2);
        cleanMode = zeros(nFrames,1);
        for frame = 1:nFrames
            base = clean(:,:,frame)+noise(:,:,frame);
            [y,clips(:,frame)] = quantized(base+residual*event(:,:,frame),nominal);
            samples(:,:,frame) = y;
            [value,info] = tdm_residual_iq(y,d,Clipped=clips(:,frame),HoldoutLimit_V=threshold);
            iq(:,:,frame) = value;
            mode(frame) = 2*double(info.status=="joint")+double(info.status=="late_fallback");
            heldout(frame,:) = info.holdout_rms_V;
            target = truth(:,:,frame);
            err(frame,3) = betaError(value,target,detector);
            if ~any(clips(:,frame))
                err(frame,1) = betaError(fullMap*y,target,detector);
                err(frame,4) = betaError(d.jointCarrierMap*y,target,detector);
            end
            if ~any(clips(late,frame))
                err(frame,2) = betaError(lateMap*y(late,:),target,detector);
            end
            % 去掉额外注入，保留真实 AAF 的重连瞬态和同一噪声样本。
            [cleanCodes,cleanClips] = quantized(base,nominal);
            [cleanIQ,cleanInfo] = tdm_residual_iq(cleanCodes,d, ...
                Clipped=cleanClips,HoldoutLimit_V=threshold);
            cleanMode(frame) = 2*double(cleanInfo.status=="joint")+ ...
                double(cleanInfo.status=="late_fallback");
            cleanErr(frame,2) = betaError(cleanIQ,target,detector);
            if ~any(cleanClips(late))
                cleanErr(frame,1) = betaError(lateMap*cleanCodes(late,:),target,detector);
            end
        end
        index = index+1;
        stats = scoreFrames(err(:,2:3),mode);
        stats.name = name;
        stats.family = family;
        stats.true_poles_Hz = actual;
        stats.true_order = numel(actual);
        stats.overall_full_ols_rms_rad = rmsError(err(isfinite(err(:,1)),1));
        stats.overall_unguarded_joint_rms_rad = rmsError(err(isfinite(err(:,4)),4));
        stats.zero_added_residual = scoreFrames(cleanErr,cleanMode);
        reportCases{index} = stats;
        if keepReplay
            replayCases{index} = struct('name',name,'samples',samples,'clips',clips, ...
                'iq',iq,'mode',mode,'heldout_rms_V',heldout);
        end
    end
end

function stats = scoreFrames(error,mode)
% 条件指标在同一联合通过集上比较，整体指标计入实际发布的后窗回退帧。
paired = isfinite(error(:,1)) & isfinite(error(:,2));
joint = (mode==2) & paired;
n = numel(mode);
ratio = rmsError(error(paired,2))/rmsError(error(paired,1));
stats = struct('frames',n,'joint_accepted_frames',nnz(mode==2), ...
    'joint_rejected_frames',nnz(mode~=2),'late_fallback_frames',nnz(mode==1), ...
    'final_invalid_frames',nnz(mode==0),'joint_coverage',nnz(mode==2)/n, ...
    'final_coverage',nnz(mode>0)/n,'paired_frames',nnz(paired), ...
    'conditional_joint_rms_rad',rmsError(error(joint,2)), ...
    'conditional_same_frame_late_rms_rad',rmsError(error(joint,1)), ...
    'overall_guarded_rms_rad',rmsError(error(mode>0,2)), ...
    'overall_same_frame_late_rms_rad',rmsError(error(paired,1)), ...
    'paired_guarded_to_late_rms_ratio',ratio,'meets_ratio_limit',isfinite(ratio) && ratio<=2);
end

function [y,clipped] = quantized(v,c)
% 采用现有 ADC 的电压码格与两侧过载定义。
clipped = any(v<c.adcMin | v>c.adcMax,2);
y = min(c.adcMax,max(c.adcMin,c.adcStep*round(v/c.adcStep)));
end

function [clean,truth] = switchedSamples(poles_Hz,Ts,w,phase,initial)
% 用连续时间 RC 级联与载波振荡器的矩阵指数生成真实数据。
% I/Q 真值取该级联的稳态频响，初始状态只产生独立的自然响应。
poles = 2*pi*poles_Hz;
order = numel(poles);
n = numel(phase);
frames = size(initial,3);
a = -diag(poles);
for k = 2:order
    a(k,k-1) = poles(k);
end
b = [poles(1);zeros(order-1,1)];
transition = expm([a,b,zeros(order,1);zeros(2,order),[0 -w;w 0]]*Ts);
state = [eye(order),zeros(order,2);zeros(2,order), ...
    [cos(phase(1)) sin(phase(1));sin(phase(1)) -cos(phase(1))]];
response = zeros(n,order+2);
for k = 1:n
    response(k,:) = state(order,:);
    state = transition*state;
end
h = prod(poles./(poles+1i*w));
clean = zeros(n,2,frames);
truth = zeros(2,2,frames);
for frame = 1:frames
    beta = .71*sin(frame/17)+.27;
    u = [cos(2*beta),sin(2*beta)];
    phi = .6*cos(frame/13);
    input = .08*[cos(phi),sin(phi);-sin(phi),cos(phi)]*[u;.04*[-u(2),u(1)]];
    clean(:,:,frame) = response*[initial(1:order,:,frame);input];
    iq = h*(input(1,:)-1i*input(2,:));
    truth(:,:,frame) = [real(iq);-imag(iq)];
end
end

function clean = modelSamples(poles,nFrames,slot,nominal)
% 提取同一物理 ADC 时刻的 A/B/C/D 组电压，按原接法合成 X/Y。
c = five_config('tdm_shared',nominal.omega, ...
    struct('duration',nominal.duration,'dac_divisor',nominal.p.dac_divisor, ...
    'afe_bw',repmat(poles(1),2,1)));
scale = c.portCV(:,23:26);
c.portCV(:) = 0;
c.portCV(:,10+4*(numel(poles)-1)+(1:4)) = scale;
[~,~,~,monitor] = five_reference(c);
ticks = slot+(8:7+nFrames)*c.frame;
[found,idx] = ismember(ticks(:),monitor(:,1));
assert(all(found),'模型回放没有覆盖完整 ADC 检测窗。');
volts = monitor(idx,10:13)*c.portSenseMap';
if numel(poles)==4
    assert(max(abs(volts-monitor(idx,3:4)),[],'all')<1e-12,'四级抽头与原 ADC 电压不一致。');
end
clean = permute(reshape(volts,numel(slot),nFrames,2),[1 3 2]);
end

function delta = betaError(estimate,truth,detector)
% 两路 I/Q 排列为 Ix/Iy/Qx/Qy，角度按物理驻波的 π/2 周期环绕。
phaseDelta = azimuth(estimate,detector)-azimuth(truth,detector);
delta = atan2(sin(phaseDelta),cos(phaseDelta))/4;
end

function phase = azimuth(iq,detector)
% 使用校准后的同相与正交向量构造四倍角。
v = detector*reshape(iq.',4,1);
p = v(1:2).^2+v(3:4).^2;
phase = atan2(2*(v(1)*v(2)+v(3)*v(4)),p(1)-p(2));
end

function value = rmsError(error)
% 空的通过集没有 RMS，保留 NaN 并在 JSON 中写作 null。
value = sqrt(mean(error.^2));
end
