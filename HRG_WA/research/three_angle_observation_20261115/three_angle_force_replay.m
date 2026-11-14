function result = three_angle_force_replay(outPath)
% 固定 DAC 与固定模态力回放。统一五端表头、初态、采样和机械观测窗。
% 独立机械方程由 pcn_plant 的机械块建立。施力为 p.b*H'*V，后者
% 从真实组端电气状态恢复。精确回放使用原步内积分，采样近似另行计分。
arguments
    outPath (1,:) char = fullfile(fileparts(mfilename('fullpath')),'modal_force_replay.json')
end
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here,'..','three_mode_split_20261113'),fullfile(here,'..','tdm_gain_20261113'));
betaList = [22.5,67.5];
duration = .18;
scoreStart = .06;
split = .05;
result = struct('release',version('-release'), ...
    'scope','Open-loop modal forcing decomposition of identical or drive-map-scaled DAC waveforms', ...
    'duration_s',duration,'score_start_s',scoreStart,'split_Hz',split,'rate_rad_s',0, ...
    'initial_beta_deg',betaList,'cases',[],'exact_force_checks',[],'source_drive_only_checks',[]);
for beta = betaList
    dedicated = three_mode_split_config("tdm_separate",0,split,beta,duration,16);
    shared = three_mode_split_config("tdm_shared",0,split,beta,duration,16);
    continuous = three_mode_split_config("continuous",0,split,beta,duration,16);
    assert(isequal(continuous.Ad,dedicated.Ad,dedicated.As,dedicated.Af) && ...
        isequal(continuous.Bd,dedicated.Bd) && ...
        isequal(continuous.x0,dedicated.x0,shared.x0) && ...
        isequal(continuous.portCoupling,dedicated.portCoupling,shared.portCoupling));
    [phi,voltageStep] = mechanicalStep(dedicated);
    [phiShared,~] = mechanicalStep(shared);
    [phiContinuous,~] = mechanicalStep(continuous);
    assert(isequal(phi,phiShared,phiContinuous));
    sourceModes = {dedicated,shared};
    for src = 1:2
        source = sourceModes{src};
        [~,info,ddb] = tdm_gain_fast(source);
        assert(info.published_frames==info.expected_frames && ~info.tracking_lost);
        fixed = ddb.dac;
        separate = capture(dedicated,dedicated,fixed);
        sameCodes = capture(shared,dedicated,fixed);
        % 只由固定投影几何算半压命令，不从评分数据拟合；DAC 码重新量化。
        g = norm(dedicated.portCoupling'*dedicated.portDriveMap,'fro')/ ...
            norm(shared.portCoupling'*shared.portDriveMap,'fro');
        matchedCodes = min(shared.dacMax,max(shared.dacMin,shared.dacStep*round(g*fixed/shared.dacStep)));
        gainMatch = capture(shared,dedicated,matchedCodes);
        [row,referenceSlope] = compare(dedicated,separate,sameCodes,scoreStart);
        row.source_mode = string(source.mode);
        row.initial_beta_deg = beta;
        row.shared_dac_scale = 1;
        result.cases = [result.cases;row]; %#ok<AGROW>
        % 固定由同一源电气网络产生的外源驱动力。目标拓扑仍保留实时
        % 运动电荷电流及其端电压回作用，作为独立的负载对照。
        if src==1
            sourceCapture = separate;
        else
            sourceCapture = sameCodes;
        end
        row = checkSourceDrive(dedicated,shared,source,sourceCapture,split,beta,fixed,scoreStart);
        result.source_drive_only_checks = [result.source_drive_only_checks;row]; %#ok<AGROW>
        row = compare(dedicated,separate,gainMatch,scoreStart);
        row.source_mode = string(source.mode);
        row.initial_beta_deg = beta;
        row.shared_dac_scale = g;
        result.cases = [result.cases;row]; %#ok<AGROW>
        % 以两个不同拓扑各自产生的端口作用量，驱动同一个开环本征机械模型。
        % 同一个驱动增量在三种拓扑里对应同一个本征方程和初态。
        captures = {separate,gainMatch};
        labels = ["dedicated_fixed_codes","shared_geometric_drive_match"];
        for j = 1:2
            a = captures{j};
            exactStep = a.mechanical(:,2:end)-phi*a.mechanical(:,1:end-1);
            actualForce = filterRecurrence(phi,exactStep,continuous.x0(1:4));
            sharedReplay = filterRecurrence(phiShared,exactStep,shared.x0(1:4));
            assert(isequal(actualForce,sharedReplay));
            % 把真实的 H'*V 端电压样本保持一拍，避免从终点机械状态推导。
            sampledForce = filterRecurrence(phi,voltageStep*a.voltage(:,1:end-1),continuous.x0(1:4));
            body = bodyAngle(dedicated,actualForce,a.frame_count,scoreStart);
            approximateBody = bodyAngle(dedicated,sampledForce,a.frame_count,scoreStart);
            fullBody = bodyAngle(dedicated,a.mechanical,a.frame_count,scoreStart);
            stateError = max(abs(actualForce-a.mechanical),[],'all');
            angleError = max(abs(body-fullBody));
            assert(stateError<1e-9 && angleError<1e-9);
            result.exact_force_checks = [result.exact_force_checks;struct( ...
                'initial_beta_deg',beta,'source_mode',string(source.mode),'waveform',labels(j), ...
                'reference_dedicated_slope_rad_s',referenceSlope, ...
                'max_exact_replay_mechanical_state_abs_delta',stateError, ...
                'max_exact_replay_body_angle_delta_rad',angleError, ...
                'max_common_force_cross_topology_angle_delta_rad',0, ...
                'sampled_force_ZOH_body_angle_rms_delta_rad',sqrt(mean((approximateBody-fullBody).^2)), ...
                'force_step_RMS',sqrt(mean(exactStep.^2,2))')]; %#ok<AGROW>
        end
    end
end
% 零频差阴性对照使用同样的初角、两个闭环命令来源和观察窗口。
for beta = betaList
    dedicated = three_mode_split_config("tdm_separate",0,0,beta,duration,16);
    shared = three_mode_split_config("tdm_shared",0,0,beta,duration,16);
    sources = {dedicated,shared};
    for src = 1:2
        source = sources{src};
        [~,info,ddb] = tdm_gain_fast(source);
        assert(info.published_frames==info.expected_frames && ~info.tracking_lost);
        baseline = capture(source,dedicated,ddb.dac);
        row = checkSourceDrive(dedicated,shared,source,baseline,0,beta,ddb.dac,scoreStart);
        result.source_drive_only_checks = [result.source_drive_only_checks;row]; %#ok<AGROW>
    end
end
if ~isempty(outPath)
    fid = fopen(outPath,'w','n','UTF-8');
    assert(fid>=0,'无法写入模态力回放回执。');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid,'%s\n',jsonencode(result,'PrettyPrint',true));
end
end

function row = checkSourceDrive(dedicated,shared,source,reference,split,beta,dac,start)
% 同源外源压力下比较两种仍保留实时运动反作用的电气终接。
d = sourceDriveOnly(dedicated,source,dedicated,dac);
s = sourceDriveOnly(shared,source,dedicated,dac);
if source.reuse
    reconstructed = s.mechanical;
else
    reconstructed = d.mechanical;
end
reconstructionError = max(abs(reference.mechanical-reconstructed),[],'all');
assert(reconstructionError<1e-8,'运动分量与源驱动分量未能重构原轨迹。');
[bd,tc] = bodyAngle(dedicated,d.mechanical,d.frame_count,start);
bs = bodyAngle(dedicated,s.mechanical,s.frame_count,start);
difference = bs-bd;
slope = polyfit(tc-tc(1),difference,1);
row = struct('initial_beta_deg',beta,'source_mode',string(source.mode),'split_Hz',split, ...
    'score_frames',numel(tc),'max_source_self_reconstruction_state_delta',reconstructionError, ...
    'shared_minus_separate_angle_slope_rad_s',slope(1), ...
    'shared_minus_separate_angle_rms_rad',sqrt(mean(difference.^2)));
end

function [phi,voltageStep] = mechanicalStep(c)
% 按 five_config 的归一化机械状态，还原 H'*V 到机械速度方程的系数。
[~,~,~,a] = pcn_plant(c.p);
q = c.p.charge_target;
s = diag(q*[1,1,2*pi*c.p.f0,2*pi*c.p.f0]);
m = s\(a(1:4,1:4)*s);
force = s\[zeros(2);c.p.b*eye(2)];
e = expm([m,force;zeros(2,6)]*c.Ts);
phi = e(1:4,1:4);
voltageStep = e(1:4,5:6);
end

function a = capture(c,s,dac)
% 保留每拍归一化机械状态与 H'*V，不在回放时更新控制命令。
drive = s.driveEnd;
bleed = s.senseStart-drive;
sense = s.validEnd-s.senseStart;
tail = s.frame-s.validEnd;
output = [eye(4),zeros(4,c.stateCount-4); c.portCoupling'*c.groupVoltage];
seg = {segment(c.Ad,c.Bd,output,drive),segment(c.Af,zeros(size(c.Bd)),output,bleed), ...
    segment(c.As,zeros(size(c.Bd)),output,sense),segment(c.Af,zeros(size(c.Bd)),output,tail)};
[y,frames] = runSegments(seg,c.x0,output,s,dac);
a = struct('frame_count',frames,'mechanical',y(1:4,:),'voltage',y(5:6,:));
end

function a = sourceDriveOnly(target,source,s,dac)
% 14 状态解析反事实。目标 4 个本征机械状态、4 个运动电荷激励的
% 组端电压，加来源电气网络中 2 个驱动器极点和 4 个外源组端电压。
% 来源组端不接受机械电流，只响应冻结的 DAC 输入。目标组端保留实时
% 运动电荷电流和负载回作用，来源驱动端电压直接进入目标速度方程。
[~,~,~,aFull] = pcn_plant(target.p);
q = target.p.charge_target;
w = 2*pi*target.p.f0;
mScale = diag(q*[1,1,w,w]);
mechanical = mScale\(aFull(1:4,1:4)*mScale);
coupling = mScale\[zeros(2,4);target.p.b*target.portCoupling'];
motionCurrent = -(target.portCapacitance_F\target.portCoupling)*mScale(3:4,3:4);
sourcePole = diag(1./source.p.driver_tau);
targetV = max(1e-6,w*q*target.p.Rs);
sourceV = max(1e-6,w*q*source.p.Rs);
scale = diag([ones(1,4),targetV*ones(1,4),ones(1,2),sourceV*ones(1,4)]);
output = [eye(4),zeros(4,10)];
lengths = [s.driveEnd,s.senseStart-s.driveEnd,s.validEnd-s.senseStart,s.frame-s.validEnd];
seg = cell(1,4);
for slot = 1:4
    [targetLoad,~] = electricalSlot(target,slot);
    [sourceLoad,sourceDrive] = electricalSlot(source,slot);
    a = zeros(14);
    b = zeros(14,2);
    a(1:4,1:4) = mechanical;
    a(1:4,5:8) = coupling;
    a(1:4,11:14) = mScale\[zeros(2,4);source.p.b*source.portCoupling'];
    a(5:8,3:4) = motionCurrent;
    a(5:8,5:8) = targetLoad;
    a(9:10,9:10) = -sourcePole;
    a(11:14,9:10) = sourceDrive;
    a(11:14,11:14) = sourceLoad;
    if slot==1, b(9:10,:) = sourcePole; end
    discrete = expm([scale\(a*scale),scale\b;zeros(2,16)]*target.Ts);
    seg{slot} = segment(discrete(1:14,1:14),discrete(1:14,15:16),output,lengths(slot));
end
[mechanicalStates,frames] = runSegments(seg,[target.x0(1:4);zeros(10,1)],output,s,dac);
a = struct('mechanical',mechanicalStates,'frame_count',frames);
end

function [a,b] = electricalSlot(c,slot)
% 组端 KCL 沿用真实五端驱动/检测投影和驱动导通电阻。
drive = any(c.portDriveMap,2);
sense = any(c.portSenseMap,1)';
gd = double(drive)/c.portOptions.drive_on_resistance_ohm;
gr = double(sense)/c.p.Rs;
gb = 0;
if c.reuse
    gd = gd*double(slot==1);
    gr = gr*double(slot==3);
    if slot==2 || slot==4, gb = 1/c.p.bleed_R; end
end
a = -(c.portCapacitance_F\diag(gd+gr+gb+c.p.G0));
b = c.portCapacitance_F\(diag(gd)*c.portDriveMap*c.p.power_gain*c.p.pre_gain);
end

function [y,frames] = runSegments(seg,state,output,s,dac)
% 三版共享分时码流与观测时钟。驱动窗外的 DAC 输入统一为零。
drive = s.driveEnd;
bleed = s.senseStart-drive;
sense = s.validEnd-s.senseStart;
tail = s.frame-s.validEnd;
frames = size(dac,3);
y = zeros(size(output,1),s.frame*frames+1);
for f = 1:frames
    start = (f-1)*s.frame;
    [state,y(:,start+(1:drive))] = advance(seg{1},state,dac(:,:,f)');
    [state,y(:,start+drive+(1:bleed))] = advance(seg{2},state,[]);
    [state,y(:,start+s.senseStart+(1:sense))] = advance(seg{3},state,[]);
    [state,y(:,start+s.validEnd+(1:tail))] = advance(seg{4},state,[]);
end
y(:,end) = output*state;
end

function q = segment(a,b,c,n)
% 无切换的短段用脉冲响应矩阵记录，DAC 作用严格滞后一拍。
state = zeros(size(c,1)*n,size(a,1));
response = zeros(n,size(c,1),2);
endDrive = zeros(size(a,1),2*n);
r = eye(size(a));
for k = 1:n
    state((k-1)*size(c,1)+(1:size(c,1)),:) = c*r;
    endDrive(:,2*(n-k)+(1:2)) = r*b;
    if k<n, response(k+1,:,:) = reshape(c*r*b,1,size(c,1),2); end
    r = r*a;
end
f = 2^nextpow2(2*n-1);
q = struct('length',n,'obs_size',size(c,1),'state',state,'transition',r, ...
    'endDrive',endDrive,'nFFT',f,'impulseFFT',fft(response,f,1));
end

function [next,y] = advance(q,state,dac)
% 用线性卷积把驱动码加入模拟轨迹，检测/泄放段仅推进内部状态。
y = reshape(q.state*state,q.obs_size,q.length);
next = q.transition*state;
if ~isempty(dac)
    u = reshape(fft(dac',q.nFFT,1),q.nFFT,1,2);
    extra = ifft(sum(q.impulseFFT.*u,3),[],1,'symmetric');
    y = y+extra(1:q.length,:)';
    next = next+q.endDrive*dac(:);
end
end

function y = filterRecurrence(phi,u,x0)
% 按机械特征方向独立求 y[k+1]=phi*y[k]+u[k]，与原耦合推进独立。
[v,d] = eig(phi,'vector');
drive = v\[x0,u];
for k = 1:numel(d)
    drive(k,:) = filter(1,[1,-d(k)],drive(k,:));
end
y = real(v*drive);
end

function [r,refSlope] = compare(c,separate,shared,start)
% 驱动窗与非驱动窗分别对齐同一物理时刻，比较实际端口施力的差别。
drive = repmat((0:c.frame-1)<c.driveEnd,1,separate.frame_count);
senseAndIdle = ~drive;
vSep = separate.voltage(:,1:end-1);
vShared = shared.voltage(:,1:end-1);
a = bodyAngle(c,separate.mechanical,separate.frame_count,start);
[b,time] = bodyAngle(c,shared.mechanical,shared.frame_count,start);
slope = polyfit(time-time(1),b-a,1);
ref = polyfit(time-time(1),a,1);
refSlope = ref(1);
r = struct('drive_V_rms_relative_difference',rmsRatio(vShared-vSep,vSep,drive), ...
    'non_drive_V_rms_relative_difference',rmsRatio(vShared-vSep,vSep,senseAndIdle), ...
    'non_drive_V_rms_difference',sqrt(mean((vShared(:,senseAndIdle)-vSep(:,senseAndIdle)).^2,'all')), ...
    'shared_minus_separate_angle_slope_rad_s',slope(1), ...
    'shared_minus_separate_angle_rms_rad',sqrt(mean((b-a).^2)), ...
    'scored_frames',numel(b));
end

function r = rmsRatio(e,v,take)
% 误差与参考的双轴 RMS 各以同一时窗计算。
r = norm(e(:,take),'fro')/norm(v(:,take),'fro');
end

function [angle,t] = bodyAngle(c,mechanical,frames,start)
% 在同一窗内相干解调物理电荷，按四倍驻波角增量得到等效机体角。
valid = (c.validStart:c.validEnd-1)';
center = ((0:frames-1)'*c.frame+(c.validStart+c.validEnd-1)/2)*c.Ts;
t = center(center>=start);
ids = find(center>=start);
az = zeros(numel(ids),1);
for k = 1:numel(ids)
    tick = valid+(ids(k)-1)*c.frame;
    phase = c.w*(tick*c.Ts);
    iq = 2/c.n*[cos(phase),sin(phase)]'*mechanical(1:2,tick+1)';
    modal = sum(iq.^2,1);
    az(k) = atan2(2*dot(iq(:,1),iq(:,2)),modal(1)-modal(2));
end
delta = diff(az);
angle = -[0;cumsum(atan2(sin(delta),cos(delta)))]/(4*c.B);
end
