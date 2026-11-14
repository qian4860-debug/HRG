function result = three_angle_fixed_replay(outPath)
% 用同一组逐拍 DAC 电压回放三种五端拓扑，观察机械角。
% 连续物理拓扑也使用该分时码流（驱动窗外 0 V）和同一观测窗。
% 由于各拓扑的电极映射不同，固定电压回放仍会改变施加到表头的力。
arguments
    outPath (1,:) char = fullfile(fileparts(mfilename('fullpath')),'fixed_command_replay.json')
end
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here,'..','three_mode_split_20261113'),fullfile(here,'..','tdm_gain_20261113'));
modes = ["continuous","tdm_separate","tdm_shared"];
betaList = [22.5 67.5];
duration = .18;
scoreStart = .06;
split = .05;
rate = 0;
result = struct('release',version('-release'), ...
    'scope','Open-loop replay of identical DAC voltages from two closed-loop TDM sources onto three five-terminal plants', ...
    'duration_s',duration,'score_start_s',scoreStart,'split_Hz',split,'rate_rad_s',rate, ...
    'adc_DAC_clock_Hz',5.44e6,'physical_initial_beta_deg',betaList, ...
    'source_modes',modes(2:3),'target_modes',modes, ...
    'drive_waveform_contract','Same quantized DAC drive samples, zero volts outside the source drive window', ...
    'force_contract','Equal DAC voltage, topology-specific electrode loading and modal force', ...
    'cases',[],'independent_reference',[]);

for beta = betaList
    configs = cell(1,numel(modes));
    for j = 1:numel(modes)
        configs{j} = three_mode_split_config(modes(j),rate,split,beta,duration,16);
    end
    schedule = configs{2};
    assert(isequal(configs{1}.Ad,configs{2}.Ad,configs{2}.Af,configs{2}.As) && ...
        isequal(configs{1}.Bd,configs{2}.Bd));
    assert(isequal(configs{1}.x0,configs{2}.x0,configs{3}.x0) && ...
        isequal(configs{1}.portCoupling,configs{2}.portCoupling,configs{3}.portCoupling));
    for sourceIndex = 2:3
        source = configs{sourceIndex};
        [~,sc,debug] = tdm_gain_fast(source);
        assert(sc.published_frames==sc.expected_frames && ~sc.tracking_lost);
        commonDrive = debug.dac;
        angles = cell(1,numel(modes));
        for j = 1:numel(modes)
            [t,betaRaw,energy] = replay(configs{j},schedule,commonDrive);
            assert(all(energy>=source.minEnergy),'机械观测幅值低于可用门限。');
            take = t>=scoreStart;
            relBody = -unwrapCenter(betaRaw(take))/source.B;
            if j==2
                assert(isequal(angles{1},relBody),'连续与不复用的专用电极负对照不一致。');
            end
            angles{j} = relBody;
            signedSlope = polyfit(t(take)-t(find(take,1)),relBody,1);
            srcDriveV = source.portCoupling'*source.portDriveMap;
            dstDriveV = configs{j}.portCoupling'*configs{j}.portDriveMap;
            result.cases = [result.cases;struct('initial_beta_deg',beta,'source',modes(sourceIndex), ...
                'target',modes(j),'source_frame_count',size(commonDrive,3),'score_frames',nnz(take), ...
                'source_dac_peak_V',max(abs(commonDrive),[],'all'),'drive_duty', ...
                schedule.driveEnd/schedule.frame,'modal_drive_map_norm_ratio_to_source', ...
                norm(dstDriveV,'fro')/norm(srcDriveV,'fro'), ...
                'mechanical_body_slope_rad_s',signedSlope(1), ...
                'mechanical_body_rms_rad',sqrt(mean(relBody.^2)), ...
                'mechanical_body_last_rad',relBody(end), ...
                'shared_minus_separate_slope_rad_s',NaN)]; %#ok<AGROW>
        end
        ref = polyfit(t(take)-t(find(take,1)),angles{3}-angles{2},1);
        result.cases(end).shared_minus_separate_slope_rad_s = ref(1);
    end
end
% 各拓扑回放自己的码流，应与原逐拍闭环机械观测一致，独立检查窗口和进位。
for mode = modes(2:3)
    c = three_mode_split_config(mode,0,split,betaList(1),.012,16);
    [~,~,debug] = tdm_gain_fast(c);
    [t,raw] = replay(c,c,debug.dac);
    [~,~,~,~,observed] = five_reference(c,false);
    delay = (c.validEnd+c.adcLatency-(c.validStart+c.validEnd-1)/2)*c.Ts;
    phaseDelta = 4*raw-observed(:,2);
    delta = max(abs(atan2(sin(phaseDelta),cos(phaseDelta)))/4);
    tDelta = max(abs(t-(observed(:,1)-delay)));
    assert(delta<1e-10 && tDelta<1e-14,'回放与原逐拍机械结果不一致。');
    result.independent_reference = [result.independent_reference; ...
        struct('mode',mode,'frames',numel(t),'max_beta_delta_rad',delta,'max_time_delta_s',tDelta)];
end
if ~isempty(outPath)
    fid = fopen(outPath,'w','n','UTF-8');
    assert(fid>=0,'无法写入固定命令回放回执。');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid,'%s\n',jsonencode(result,'PrettyPrint',true));
end
end

function [t,beta,energy] = replay(c,s,dac)
% 先按每拍 DAC 卷积推进驱动状态，再在真实检测样本时刻相干解调模态状态。
n = c.stateCount;
frameCount = size(dac,3);
valid = (s.validStart:s.validEnd-1)';
nValid = numel(valid);
[ad,af,as] = deal(c.Ad,c.Af,c.As);
if ~c.reuse
    af = ad;
    as = ad;
end
r = eye(n);
command = zeros(n,2*s.driveEnd);
for k = s.driveEnd:-1:1
    command(:,2*k-1:2*k) = r*c.Bd;
    r = r*ad;
end
driveEnd = r;
senseStart = af^(s.senseStart-s.driveEnd);
beforeValid = as^(s.validStart-s.senseStart);
motion = zeros(2*nValid,n);
r = eye(n);
for k = 1:nValid
    motion(2*k-1:2*k,:) = c.motion*r;
    r = r*as;
end
validEnd = r;
tailEnd = af^(s.frame-s.validEnd);
x = c.x0;
t = ((0:frameCount-1)'*s.frame+(s.validStart+s.validEnd-1)/2)*s.Ts;
beta = zeros(size(t));
energy = zeros(size(t));
for f = 1:frameCount
    u = dac(:,:,f)';
    x = beforeValid*senseStart*(driveEnd*x+command*u(:));
    state = reshape(motion*x,2,nValid)';
    phase = c.w*((valid+(f-1)*s.frame)*s.Ts);
    iq = 2/s.n*[cos(phase),sin(phase)]'*state;
    modal = sum(iq.^2,1);
    beta(f) = atan2(2*dot(iq(:,1),iq(:,2)),modal(1)-modal(2))/4;
    energy(f) = sum(modal);
    x = tailEnd*(validEnd*x);
end
end

function a = unwrapCenter(beta)
% 四倍角解包裹，首帧作为公共机械角锚点。
delta = diff(4*beta);
a = [0;cumsum(atan2(sin(delta),cos(delta)))]/4;
end
