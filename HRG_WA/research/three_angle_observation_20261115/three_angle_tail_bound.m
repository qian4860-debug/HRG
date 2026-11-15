function result = three_angle_tail_bound(outPath)
% 现有分时窗内 DAC 归零，求外源模态力跨接法拟合的理论下界。
% 源波形使用闭环生成的量化 DAC 码；随后在去除运动电流的电气
% 网络中回放。目标的每一帧可自由选择窗首电气状态，放松了实际
% DAC、轨限、因果性及跨帧记忆对窗首状态的约束。
arguments
    outPath (1,:) char = fullfile(fileparts(mfilename('fullpath')),'tail_reachability.json')
end
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here,'..','three_mode_split_20261113'),fullfile(here,'..','tdm_gain_20261113'));
modes = ["tdm_separate","tdm_shared"];
betaList = [22.5,67.5];
duration = .18;
scoreStart = .06;
split = .05;
cases = struct([]);
checks = struct([]);
sensitivity = struct([]);
for beta = betaList
    configs = arrayfun(@(mode) three_mode_split_config(mode,0,split,beta,duration,16), ...
        modes,'UniformOutput',false);
    configs = [configs{:}];
    networks = arrayfun(@electricalNetwork,configs,'UniformOutput',false);
    networks = [networks{:}];
    assert(configs(1).Ts==configs(2).Ts && isequal( ...
        slotLength(configs(1)),slotLength(configs(2))));
    for k = 1:numel(configs)
        c = configs(k);
        [~,info,debug] = tdm_gain_fast(c);
        assert(~info.tracking_lost && info.published_frames==info.expected_frames);
        voltage = replayTail(c,networks(k),debug.dac);
        center = ((0:size(voltage,3)-1)*c.frame+(c.validStart+c.validEnd-1)/2)*c.Ts;
        voltage = voltage(:,:,center>=scoreStart);
        % 两轴同源回投应为数值零，防止窗切片或列空间推导错误。
        own = measure(c,networks(k),voltage);
        assert(own.off_drive_relative_rms_lower_bound<1e-10,'本接法的回投残差未接近零。');
        checks = [checks;struct('source_mode',modes(k),'initial_beta_deg',beta, ...
            'own_relative_residual',own.off_drive_relative_rms_lower_bound, ...
            'max_target_basis_error',networks(k).basis_error)]; %#ok<AGROW>
        target = 3-k;
        row = measure(c,networks(target),voltage);
        row.initial_beta_deg = beta;
        row.source_mode = modes(k);
        row.target_mode = modes(target);
        cases = [cases;row]; %#ok<AGROW>
        if k==1
            % 保留源波形与现有时序，只改变目标复用接法的理想泄放电阻。
            % 驱动器自然衰减与初段端口极点相同的位置也列为参考点。
            shared = configs(2);
            poleMatch = 1/(shared.portCapacitance_F(1,1)/c.p.driver_tau(1)-shared.p.G0);
            for resistance = [1e3,2e3,3e3,poleMatch,5e3,1e4,1.5e4,3e4,5e4]
                shared.p.bleed_R = resistance;
                varied = measure(c,electricalNetwork(shared),voltage);
                sensitivity = [sensitivity;struct('initial_beta_deg',beta, ...
                    'shared_bleed_R_ohm',resistance, ...
                    'matches_source_driver_pole',resistance==poleMatch, ...
                    'off_drive_relative_rms_lower_bound',varied.off_drive_relative_rms_lower_bound, ...
                    'off_drive_rms_lower_bound_V',varied.off_drive_rms_lower_bound_V)]; %#ok<AGROW>
            end
        end
        fprintf('%s → %s, beta %.1f deg: %.5g relative / %.5g V RMS\n', ...
            modes(k),modes(target),beta,row.off_drive_relative_rms_lower_bound, ...
            row.off_drive_rms_lower_bound_V);
    end
end
result = struct('release',version('-release'), ...
    'scope','Nominal symmetric five-terminal electrical model, source-driven force only', ...
    'contract','Target DAC command is zero outside drive, but electrical state is arbitrary per frame', ...
    'source','Closed-loop quantized DAC replay with motion current suppressed only in the electrical force model', ...
    'sampling','All physical off-drive sample ticks, including just after the drive slot boundary', ...
    'duration_s',duration,'score_start_s',scoreStart,'split_Hz',split, ...
    'initial_beta_deg',betaList,'cases',cases,'validation',checks, ...
    'passive_sensitivity_scope','Same source and switched timing; vary only target ideal bleed resistance; no feasible DAC, protection, peak or hardware acceptance implied', ...
    'passive_sensitivity',sensitivity);
if ~isempty(outPath)
    fid = fopen(outPath,'w','n','UTF-8');
    assert(fid>=0,'无法写入窗外可达性回执：%s',outPath);
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid,'%s\n',jsonencode(result,'PrettyPrint',true));
end
end

function net = electricalNetwork(c)
% 物理状态为两路驱动器电压和四组相对 COM 的电压，单位 V。
% 按五端 KCL 构造准确零阶保持步进，禁止把外源与运动电流混合。
cap = c.portCapacitance_F;
h = c.portCoupling;
assert(isequal(h,[eye(2);-eye(2)]) && isequal(cap,cap(1,1)*eye(4)), ...
    '解析列空间仅涵盖名义对置且电容相同的五电极模型。');
drive = double(any(c.portDriveMap,2))/c.portOptions.drive_on_resistance_ohm;
read = double(any(c.portSenseMap,1))'/c.p.Rs;
driverPole = 1./c.p.driver_tau(:);
lengths = slotLength(c);
observation = [zeros(2),h'];
forward = zeros(6,6,4);
for slot = 1:4
    gd = drive;
    gr = read;
    gb = 0;
    if c.reuse
        gd = gd*double(slot==1);
        gr = gr*double(slot==3);
        gb = double(slot==2 || slot==4)/c.p.bleed_R;
    end
    gain = c.p.pre_gain*c.p.power_gain;
    a = [-diag(driverPole),zeros(2,4); ...
        cap\(diag(gd)*c.portDriveMap*gain),-cap\diag(gd+gr+gb+c.p.G0)];
    b = [diag(driverPole);zeros(4,2)];
    step = expm([a,b;zeros(2,8)]*c.Ts);
    forward(:,:,slot) = step(1:6,1:6);
    if slot==1
        driveStep = step(1:6,7:8);
    end
end
% 驱动窗末电气状态用每拍 DAC 码的线性卷积快速算出。
driveMap = zeros(6,2*lengths(1));
state = eye(6);
for k = lengths(1):-1:1
    driveMap(:,2*k-1:2*k) = state*driveStep;
    state = state*forward(:,:,1);
end
driveEnd = state;

% 目标可以从任意窗首状态开始，以下堆叠矩阵涵盖所有后续采样。
n = sum(lengths(2:end));
map = zeros(2*n,6);
state = eye(6);
k = 0;
for slot = 2:4
    for sample = 1:lengths(slot)
        k = k+1;
        map(2*k-1:2*k,:) = observation*state;
        state = forward(:,:,slot)*state;
    end
end

% 分时复用窗外驱动器与电极断开，每轴仅剩一个差模电压衰减曲线。
% 不复用时每轴的驱动器、驱动组和检测组电压给三个独立指数模态。
% 使用显式时间基，避免把可达空间的很小但非零奇异值误截断。
time = (0:n-1)'*c.Ts;
axisBasis = cell(1,2);
basisError = 0;
for axis = 1:2
    if c.reuse
        bleedTime = min(time,lengths(2)*c.Ts) + max(0,time-sum(lengths(2:3))*c.Ts);
        senseTime = time-bleedTime;
        raw = exp(-((1/c.p.bleed_R+c.p.G0)*bleedTime+(1/c.p.Rs+c.p.G0)*senseTime)/cap(1,1));
    else
        rates = [driverPole(axis),(drive(axis)+c.p.G0)/cap(axis,axis), ...
            (read(axis+2)+c.p.G0)/cap(axis+2,axis+2)];
        assert(numel(unique(rates))==3,'检测到重极点，需按重根重建可达空间。');
        raw = exp(-time*rates);
    end
    [q,r] = qr(raw,0);
    assert(rcond(r)>1e-9,'目标解析列空间数值条件不足。');
    axisBasis{axis} = q;
    physical = map(axis:2:end,:);
    remainder = physical-q*(q'*physical);
    basisError = max(basisError,norm(remainder,'fro')/norm(physical,'fro'));
end
assert(basisError<1e-10,'目标解析列空间未覆盖实际离散状态映射。');
net = struct('drive_end',driveEnd,'drive_map',driveMap,'idle_end',state, ...
    'tail_observation',map,'axis_basis',{axisBasis},'basis_error',basisError);
end

function lengths = slotLength(c)
% 按驱动、泄放、检测接通、尾段排序，单位采样拍。
lengths = diff([0,c.driveEnd,c.senseStart,c.validEnd,c.frame]);
end

function voltage = replayTail(c,net,dac)
% 每一帧先使用实际 DAC 码更新窗首状态，再用零命令推进至下一帧。
frameCount = size(dac,3);
nIdle = c.frame-c.driveEnd;
voltage = zeros(nIdle,2,frameCount);
state = zeros(6,1);
for frame = 1:frameCount
    codes = dac(:,:,frame)';
    state = net.drive_end*state + net.drive_map*codes(:);
    voltage(:,:,frame) = reshape(net.tail_observation*state,2,nIdle)';
    state = net.idle_end*state;
end
end

function row = measure(c,target,source)
% 对每帧每轴求最小二乘距离，再对统一的采样集合求双轴 RMS 下界。
% 以下切片只是全窗最优残差的构成，不是单独重新拟合后的最小值。
n = size(source,1);
frames = size(source,3);
residual = zeros(size(source));
for axis = 1:2
    q = target.axis_basis{axis};
    y = reshape(source(:,axis,:),n,frames);
    residual(:,axis,:) = reshape(y-q*(q'*y),n,1,frames);
end
rmsAll = @(x) sqrt(mean(x.^2,'all'));
reference = rmsAll(source);
assert(reference>0,'源窗外力为零，无相对误差分母。');
error = rmsAll(residual);
lengths = slotLength(c);
bleed = 1:lengths(2);
sense = lengths(2)+(1:lengths(3));
tail = sum(lengths(2:3))+(1:lengths(4));
row = struct('score_frames',frames,'off_drive_ticks_per_frame',n, ...
    'target_reachable_dimensions',sum(cellfun(@(q) size(q,2),target.axis_basis)), ...
    'reference_modal_voltage_rms_V',reference,'off_drive_rms_lower_bound_V',error, ...
    'off_drive_relative_rms_lower_bound',error/reference, ...
    'off_drive_modal_acceleration_rms_lower_bound_C_s2',c.p.b*error, ...
    'bleed_residual_at_joint_optimum_V',rmsAll(residual(bleed,:,:)), ...
    'sense_residual_at_joint_optimum_V',rmsAll(residual(sense,:,:)), ...
    'tail_residual_at_joint_optimum_V',rmsAll(residual(tail,:,:)));
end
