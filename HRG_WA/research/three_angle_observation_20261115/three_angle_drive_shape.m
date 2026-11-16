function result = three_angle_drive_shape(outPath,opts)
% 冻结窗内整形器，比较共用检测电极与专用驱动拓扑的外加模态输入和机械角。
% 训练不读取闭环角误差。按窗改变电压目标权重，验证使用独立完整输入轨迹。
arguments
    outPath (1,:) char = fullfile(fileparts(mfilename('fullpath')),'drive_shape.json')
    opts.BleedOhm (1,1) double {mustBeFinite,mustBePositive} = 15000
    opts.FrozenCoefficients (:,:) double {mustBeFinite} = []
    opts.Methods (1,:) string = string.empty(1,0)
    opts.FitOnly (1,1) logical = false
    opts.ElectricalMonitor (1,1) logical = false
end
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here,'..','three_mode_split_20261113'),fullfile(here,'..','tdm_gain_20261113'));
duration = .18;
scoreStart = .06;
conditions = [22.5 0 .05;67.5 0 .05;22.5 .05 .05;67.5 -.05 .05;22.5 0 0];
labels = ["train_and_time_holdout","opposite_beta","positive_rate","negative_rate","zero_split"];
fitWeights = [1 0 0 0 0;1 1 1 1 0;1 10 10 10 0;1 100 100 100 0;0 0 0 0 1;1 1 1 1 10];
methodNames = ["half_dac","drive_only_weight","equal_window_weight", ...
    "off_window_x10","off_window_x100","carrier_moment_only","equal_plus_moment_x10"];
if ~isempty(opts.Methods)
    [known,indices] = ismember(opts.Methods,methodNames);
    assert(all(known) && indices(1)==1 && numel(unique(indices))==numel(indices), ...
        '必须以半幅基线开头，并指定不同的已知整形目标。');
    methodNames = methodNames(indices);
    fitWeights = fitWeights(indices(2:end)-1,:);
end
taus = [1 4 16]*1e-6;
splitFrames = 40;
s = three_mode_split_config("tdm_separate",0,.05,22.5,duration,16);
c = three_mode_split_config("tdm_shared",0,.05,22.5,duration,16,struct('bleed_R',opts.BleedOhm));
sourceLift = liftTopology(s,s,true);
sharedLift = liftTopology(c,s,true);
[~,info,debug] = tdm_gain_fast(s);
assert(info.published_frames==info.expected_frames && info.expected_frames>splitFrames);
trainDac = debug.dac(:,:,1:splitFrames);
coefs = zeros(2+2*numel(taus),numel(methodNames));
rawCoefs = coefs;
trainProjection = ones(1,numel(methodNames));
if isempty(opts.FrozenCoefficients)
    gram = windowFit(s,sourceLift,sharedLift,trainDac,taus);
else
    assert(isequal(size(opts.FrozenCoefficients),size(coefs)) && ...
        all(opts.FrozenCoefficients(:,1)==0),'冻结系数须与方法数一致。');
    coefs = opts.FrozenCoefficients;
    rawCoefs = nan(size(coefs));
    trainProjection = nan(size(trainProjection));
end
for j = 2:numel(methodNames)*isempty(opts.FrozenCoefficients)
    weights = fitWeights(j-1,:);
    g = sum(gram.normal.*reshape(weights,1,1,[]),3);
    h = gram.rhs*weights';
    ridge = 1e-8*trace(g)/size(g,1);
    assert(ridge>0);
    rawCoefs(:,j) = (g+ridge*eye(size(g)))\h;
    % 沿未限幅的半幅命令投影到训练码轨允许范围，评分时冻结系数。
    [~,corr] = shapeDac(trainDac,rawCoefs(:,j),s,taus);
    trainProjection(j) = railFraction(.5*trainDac,corr,c.dacMin,c.dacMax);
    coefs(:,j) = trainProjection(j)*rawCoefs(:,j);
end
result = struct('release',version('-release'),'scope','Synthetic constrained shared topology drive shaping', ...
    'conditions_columns',["physical_initial_beta_deg","body_rate_rad_s","split_Hz"], ...
    'conditions',conditions,'condition_labels',labels,'training_frames',splitFrames, ...
    'train_condition',conditions(1,:),'score_start_s',scoreStart,'duration_s',duration, ...
    'bleed_Ohm',opts.BleedOhm,'uses_frozen_coefficients',~isempty(opts.FrozenCoefficients), ...
    'dac_bits',c.p.dac_bits,'dac_rate_Hz',1/c.Ts,'dac_rails_V',[c.dacMin c.dacMax], ...
    'window_order',["drive","bleed","sense_including_settle","tail"], ...
    'window_weight_columns',["drive","bleed","sense_including_settle","tail","full_frame_carrier_moment"], ...
    'window_weights',fitWeights,'method_names',methodNames,'edge_tau_s',taus, ...
    'coefficient_order',["carrier_same_phase","carrier_quadrature", ...
        "edge1_same_phase","edge1_quadrature","edge2_same_phase","edge2_quadrature", ...
        "edge3_same_phase","edge3_quadrature"], ...
    'coefficients',coefs,'unprojected_coefficients',rawCoefs,'training_rail_projection',trainProjection, ...
    'fit_objective','Weighted per-window mean squared H''v and full-frame normalized carrier moment residual, plus trace-scaled ridge', ...
    'cases',[],'checks',[]);
if opts.FitOnly, return; end
for row = 1:size(conditions,1)
    args = num2cell(conditions(row,:));
    [beta,rate,split] = deal(args{:});
    source = three_mode_split_config("tdm_separate",rate,split,beta,duration,16);
    shared = three_mode_split_config("tdm_shared",rate,split,beta,duration,16,struct('bleed_R',opts.BleedOhm));
    if row>1, [~,info,debug] = tdm_gain_fast(source); end
    fixed = debug.dac;
    assert(info.expected_frames==size(fixed,3) && info.published_frames==info.expected_frames);
    n = size(fixed,3);
    sourceForce = response(sourceLift,zeros(6,1),source,s,fixed,true);
    sourcePlant = liftTopology(source,s,false);
    [reference,time] = mechanicalAngle(response(sourcePlant,source.x0,source,s,fixed,false),source,s);
    sharedPlant = liftTopology(shared,s,false,opts.ElectricalMonitor);
    steady = time>=scoreStart;
    assert(nnz(steady)>100);
    for j = 1:numel(methodNames)
        [command,~] = shapeDac(fixed,coefs(:,j),s,taus);
        over = command<c.dacMin | command>c.dacMax;
        dac = min(c.dacMax,max(c.dacMin,c.dacStep*round(command/c.dacStep)));
        assert(all(dac>=c.dacMin & dac<=c.dacMax,'all'));
        h = response(sharedLift,zeros(6,1),shared,s,dac,true);
        if opts.ElectricalMonitor
            [mech,monitor] = response(sharedPlant,shared.x0,shared,s,dac,false);
        else
            mech = response(sharedPlant,shared.x0,shared,s,dac,false);
        end
        estimated = mechanicalAngle(mech,shared,s);
        [slopes,errors,angleRms] = angleScore(estimated(steady),reference(steady),time(steady),rate,c.B);
        if row==1
            fit = frameMask(s,n,1:splitFrames);
            validation = frameMask(s,n,splitFrames+1:n);
            trainRms = windowRms(h-sourceForce,sourceForce,s,fit);
        else
            validation = true(s.frame*n,1);
            trainRms = nan(1,4);
        end
        [eV,rV,relativeV] = windowRms(h-sourceForce,sourceForce,s,validation);
        momentError = carrierMoment(h(:,validation)-sourceForce(:,validation),s);
        momentSource = carrierMoment(sourceForce(:,validation),s);
        edge = repmat((0:s.frame-1)'>=s.driveEnd-16 & (0:s.frame-1)'<s.driveEnd,n,1);
        boundaryError = h(:,edge & validation)-sourceForce(:,edge & validation);
        [forcePeak,forceEnergy] = peakAndEnergy(h-sourceForce,s,validation);
        entry = struct('condition',labels(row),'method',methodNames(j), ...
            'beta_deg',beta,'rate_rad_s',rate,'split_Hz',split, ...
            'force_evaluation_frames',nnz(validation)/s.frame,'angle_scoring_frames',nnz(steady), ...
            'train_force_rms_V_by_window',trainRms,'force_error_rms_V',eV,'force_reference_rms_V',rV, ...
            'force_error_peak_V_by_window',forcePeak,'force_error_energy_V2_s_per_frame_by_window',forceEnergy, ...
            'last_16_drive_samples_force_rms_V',sqrt(mean(boundaryError.^2,'all')), ...
            'carrier_moment_error_rms_V',sqrt(mean(momentError.^2,'all')), ...
            'carrier_moment_reference_rms_V',sqrt(mean(momentSource.^2,'all')), ...
            'force_relative_error_by_window',relativeV,'peak_abs_dac_V',max(abs(dac),[],'all'), ...
            'prequantizer_gain_rail_samples',nnz(any(over,2)),'prequantizer_gain_rail_axis_codes',nnz(over), ...
            'possible_drive_ticks',s.driveEnd*n,'possible_drive_axis_codes',2*s.driveEnd*n, ...
            'dedicated_body_vs_truth_slope_rad_s',slopes(1),'shared_body_vs_truth_slope_rad_s',slopes(2), ...
            'shared_minus_dedicated_body_slope_rad_s',slopes(3), ...
            'dedicated_body_vs_truth_rms_rad',errors(1),'shared_body_vs_truth_rms_rad',errors(2), ...
            'shared_minus_dedicated_body_rms_rad',errors(3), ...
            'dedicated_physical_beta_vs_truth_rms_rad',angleRms(1), ...
            'shared_physical_beta_vs_truth_rms_rad',angleRms(2), ...
            'shared_minus_dedicated_physical_beta_rms_rad',angleRms(3));
        if opts.ElectricalMonitor
            entry.electrical = monitor;
        end
        result.cases = [result.cases;entry]; %#ok<AGROW>
    end
    if row==1 && opts.BleedOhm==15000
        % 半幅窗际波形须复现第 42 号回放，确认 DAC 次序、机械缩放和锚点。
        old = jsondecode(fileread(fullfile(here,'modal_force_replay.json')));
        oldCases = old.cases;
        expected = oldCases([oldCases.initial_beta_deg]==22.5 & ...
            [oldCases.shared_dac_scale]==.5 & strcmp({oldCases.source_mode},'tdm_separate'));
        measured = result.cases(1).shared_minus_dedicated_body_slope_rad_s;
        delta = abs(measured-expected.shared_minus_separate_angle_slope_rad_s);
        assert(delta<1e-9);
        result.checks = struct('half_dac_vs_report42_body_slope_delta_rad_s',delta, ...
            'fixed_window_same_clocks_and_code_rails',true);
    end
    fprintf('Drive shape %s: %d frames, %d scored\n',labels(row),n,nnz(steady));
end
if ~isempty(outPath)
    fid = fopen(outPath,'w','n','UTF-8');
    assert(fid>=0,'无法写入整形验证回执。');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid,'%s\n',jsonencode(result,'PrettyPrint',true));
end
end

function fit = windowFit(s,sourceLift,sharedLift,dac,taus)
% 对每窗建立独立平方误差，避免评分时长隐式改变各窗的拟合权重。
forceRef = response(sourceLift,zeros(6,1),s,s,dac,true);
baseline = response(sharedLift,zeros(6,1),s,s,.5*dac,true);
delta = forceRef-baseline;
k = 2+2*numel(taus);
design = zeros(numel(delta),k);
for j = 1:k
    unit = zeros(k,1);
    unit(j) = 1;
    [~,part] = shapeDac(dac,unit,s,taus);
    r = response(sharedLift,zeros(6,1),s,s,part,true);
    design(:,j) = r(:);
end
fit = struct('normal',zeros(k,k,5),'rhs',zeros(k,5));
windows = repmat(slotId(s),size(dac,3),1);
for j = 1:4
    select = repelem(windows==j,2,1);
    x = design(select,:);
    fit.normal(:,:,j) = (x'*x)/nnz(select);
    fit.rhs(:,j) = (x'*delta(select))/nnz(select);
end
% 模态受迫响应对同相/正交力积分敏感。用整帧的相干投影作替代目标。
target = carrierMoment(delta,s);
x = zeros(numel(target),k);
for j = 1:k
    projection = carrierMoment(reshape(design(:,j),size(delta)),s);
    x(:,j) = projection(:);
end
fit.normal(:,:,5) = (x'*x)/size(x,1);
fit.rhs(:,5) = (x'*target(:))/size(x,1);
end

function moment = carrierMoment(y,s)
% 四个载波周期内分别积分两轴同相与正交分量并归一化为 V。
f = size(y,2)/s.frame;
t = s.w*((0:s.frame-1)'*s.Ts);
basis = 2/s.frame*[cos(t),sin(t)];
blocks = reshape(y,2,s.frame,f);
moment = pagemtimes(blocks,basis);
end

function [raw,correction] = shapeDac(ref,a,s,taus)
% 用来源现帧的载频幅相生成两轴相同系数的整形。指数只在驱动窗内生效。
t = (0:s.driveEnd-1)'*s.Ts;
tri = [cos(s.w*t),sin(s.w*t)];
u = reshape(ref,s.driveEnd,[]);
q = (2/s.n*tri')*u;
main = tri*q;
quadrature = [-tri(:,2),tri(:,1)]*q;
gain = ones(size(t))*a(1);
phase = ones(size(t))*a(2);
for j = 1:numel(taus)
    edge = exp((t-t(end))/taus(j));
    gain = gain+edge*a(2*j+1);
    phase = phase+edge*a(2*j+2);
end
correction = reshape(gain.*main+phase.*quadrature,size(ref));
raw = .5*ref+correction;
end

function scale = railFraction(base,correction,lower,upper)
% 在训练观测内将系数投影到码轨的可行线段，保留冻结强度。
up = correction>0;
down = correction<0;
ratios = [(upper-base(up))./correction(up);(lower-base(down))./correction(down)];
scale = min([1;ratios(:)]);
end

function id = slotId(s)
% 四窗使用与原闭环一致的硬件时序计数，检测窗含建立段。
id = repelem((1:4)',[s.driveEnd,s.senseStart-s.driveEnd,s.validEnd-s.senseStart,s.frame-s.validEnd]);
end

function mask = frameMask(s,n,keep)
% 训练与时间留出使用完整帧，不跨越窗口边界或重复样本。
select = false(n,1);
select(keep) = true;
mask = repelem(select,s.frame);
end

function [errorRms,sourceRms,relative] = windowRms(e,ref,s,select)
% 分母使用同一窗、同一批次的专用电极外加模态输入。
ids = repmat(slotId(s),size(e,2)/s.frame,1);
errorRms = zeros(1,4);
sourceRms = zeros(1,4);
for j = 1:4
    take = ids==j & select;
    errorRms(j) = sqrt(mean(e(:,take).^2,'all'));
    sourceRms(j) = sqrt(mean(ref(:,take).^2,'all'));
end
relative = errorRms./sourceRms;
end

function [pk,en] = peakAndEnergy(e,s,include)
% 每窗记录峰值及两轴残差平方积分，按完整帧归一化，单位 V²·s/帧。
ids = repmat(slotId(s),size(e,2)/s.frame,1);
frames = nnz(include)/s.frame;
pk = zeros(1,4);
en = zeros(1,4);
for j = 1:4
    r = e(:,ids==j & include);
    pk(j) = max(abs(r),[],'all');
    en(j) = s.Ts*sum(r.^2,'all')/frames;
end
end

function lifted = liftTopology(c,s,electricalOnly,monitor)
if nargin<4, monitor=false; end
% 拟合采用独立六状态外加电气模型，机械评分采用完整五端状态。
ids = slotId(s);
lengths = accumarray(ids,1);
a = {c.Ad,c.Af,c.As,c.Af};
b = {c.Bd,zeros(size(c.Bd)),zeros(size(c.Bd)),zeros(size(c.Bd))};
if electricalOnly
    output = [zeros(2),c.portCoupling'];
    for k = 1:4
        [a{k},b{k}] = electricalStep(c,k);
    end
else
    output = c.motion;
    if monitor
        output = [output;c.pickoff;c.portCV;c.groupVoltage];
    end
end
lifted = cell(1,4);
for k = 1:4
    lifted{k} = segment(a{k},b{k},output,lengths(k));
end
end

function [a,b] = electricalStep(c,slot)
% 在外源轨迹中令运动电荷电流为零，保留驱动极点和跨帧组端记忆。
pole = diag(1./c.p.driver_tau);
gd = double(any(c.portDriveMap,2))/c.portOptions.drive_on_resistance_ohm;
gr = double(any(c.portSenseMap,1)')/c.p.Rs;
gb = 0;
if c.reuse
    gd = gd*double(slot==1);
    gr = gr*double(slot==3);
    if slot==2 || slot==4, gb = 1/c.p.bleed_R; end
end
load = -(c.portCapacitance_F\diag(gd+gr+gb+c.p.G0));
driver = c.portCapacitance_F\(diag(gd)*c.portDriveMap*c.p.power_gain*c.p.pre_gain);
e = expm([-pole,zeros(2,4),pole*double(slot==1);driver,load,zeros(4,2);zeros(2,8)]*c.Ts);
a = e(1:6,1:6);
b = e(1:6,7:8);
end

function q = segment(a,b,c,n)
% 分窗线性递推。条件矩阵预计算后再逐帧作 DAC 波形卷积。
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
q = struct('length',n,'obs',size(c,1),'state',state,'transition',r, ...
    'endDrive',endDrive,'nFFT',f,'impulseFFT',fft(response,f,1));
end

function [y,monitor] = response(q,x,c,s,dac,wide)
% DAC 输入只存在于首窗；所有时窗继续推进电气或机电状态。
lengths = cellfun(@(a) a.length,q);
edges = [0,cumsum(lengths)];
fCount = size(dac,3);
instrument = nargout>=2;
if instrument
    vCap = zeros(fCount,1);
    bleedJ = zeros(fCount,1);
    monitor = struct('detect_connect_adc_peak_V',0,'detect_sense_adc_peak_V',0, ...
        'detect_valid_adc_peak_V',0,'detect_connect_cv_group_peak_V',0, ...
        'detect_sense_cv_group_peak_V',0,'detect_connect_group_voltage_peak_V',0, ...
        'detect_group_voltage_peak_V',0,'max_bleed_peak_current_A_per_group',0, ...
        'valid_adc_clip_ticks',0,'valid_adc_total_ticks',fCount*c.n);
end
if wide
    y = zeros(2,s.frame*fCount);
else
    y = zeros(2,c.n*fCount);
end
for f = 1:fCount
    for k = 1:4
        step = q{k};
        if wide || k==3 || (instrument && (k==2 || k==4))
            obs = reshape(step.state*x,step.obs,step.length);
        end
        x = step.transition*x;
        if k==1
            u = dac(:,:,f)';
            x = x+step.endDrive*u(:);
            if wide
                z = reshape(fft(u',step.nFFT,1),step.nFFT,1,2);
                extra = ifft(sum(step.impulseFFT.*z,3),[],1,'symmetric');
                obs = obs+extra(1:step.length,:)';
            end
        end
        if wide
            y(:,(f-1)*s.frame+edges(k)+(1:step.length)) = obs;
        elseif k==3
            val = c.validStart-c.senseStart+1:step.length;
            y(:,(f-1)*c.n+(1:c.n)) = obs(1:2,val);
        end
        if instrument && k==3
            % 从实际检测接通边沿算前 16 拍，另报整窗和有效 ADC 窗。
            early = 1:min(16,size(obs,2));
            adc = obs(3:4,:);
            cv = obs(5:8,:);
            v = obs(9:12,:);
            monitor.detect_connect_adc_peak_V = max(monitor.detect_connect_adc_peak_V,max(abs(adc(:,early)),[],'all'));
            monitor.detect_sense_adc_peak_V = max(monitor.detect_sense_adc_peak_V,max(abs(adc),[],'all'));
            monitor.detect_valid_adc_peak_V = max(monitor.detect_valid_adc_peak_V,max(abs(adc(:,val)),[],'all'));
            monitor.detect_connect_cv_group_peak_V = max(monitor.detect_connect_cv_group_peak_V,max(abs(cv(:,early)),[],'all'));
            monitor.detect_sense_cv_group_peak_V = max(monitor.detect_sense_cv_group_peak_V,max(abs(cv),[],'all'));
            monitor.detect_connect_group_voltage_peak_V = max(monitor.detect_connect_group_voltage_peak_V,max(abs(v(:,early)),[],'all'));
            monitor.detect_group_voltage_peak_V = max(monitor.detect_group_voltage_peak_V,max(abs(v),[],'all'));
            monitor.valid_adc_clip_ticks = monitor.valid_adc_clip_ticks + nnz(any(adc(:,val)<c.adcMin | adc(:,val)>c.adcMax,1));
            vCap(f) = .5*(v(:,1)'*c.portCapacitance_F*v(:,1));
        elseif instrument && (k==2 || k==4)
            v = obs(9:12,:);
            % 离散采样近似积分四个泄放电阻的耗能和单组峰值电流。
            for axis = 1:4
                vEnd = c.groupVoltage(axis,:)*x;
                bleedJ(f) = bleedJ(f)+c.Ts/c.p.bleed_R*trapz([v(axis,:),vEnd].^2);
            end
            monitor.max_bleed_peak_current_A_per_group = max(monitor.max_bleed_peak_current_A_per_group,max(abs(v),[],'all')/c.p.bleed_R);
        end
    end
end
if instrument
    monitor.max_capacitive_energy_at_detect_connect_J = max(vCap);
    monitor.max_bleed_energy_J_per_frame = max(bleedJ);
    monitor.mean_bleed_energy_J_per_frame = mean(bleedJ);
    monitor.detect_connect_adc_fraction_FS = monitor.detect_connect_adc_peak_V/(c.p.adc_span/2);
    monitor.detect_sense_adc_fraction_FS = monitor.detect_sense_adc_peak_V/(c.p.adc_span/2);
    monitor.score_connect_samples = 16;
end
end

function [body,t] = mechanicalAngle(y,c,s)
% 在每个有效检测窗相干积分归一化机械电荷，展开 |4β| 后换算角增量。
fCount = size(y,2)/s.n;
t = ((0:fCount-1)'*s.frame+(s.validStart+s.validEnd-1)/2)*s.Ts;
az = zeros(fCount,1);
for f = 1:fCount
    ticks = (f-1)*s.frame+(s.validStart:s.validEnd-1)';
    phase = s.w*(ticks*s.Ts);
    iq = 2/s.n*[cos(phase),sin(phase)]'*y(:,(f-1)*s.n+(1:s.n))';
    p = sum(iq.^2,1);
    assert(sum(p)>=c.minEnergy,'机械观测幅值低于有效门限。');
    az(f) = atan2(2*dot(iq(:,1),iq(:,2)),p(1)-p(2));
end
delta = diff(az);
body = -[0;cumsum(atan2(sin(delta),cos(delta)))]/(4*c.B);
end

function [slopes,rms,physicalRms] = angleScore(shared,ref,t,rate,b)
% 对同一评分首帧设共同锚点，独立汇报相对机体真值和专用拓扑的误差。
t = t-t(1);
errorRef = ref-ref(1)-rate*t;
errorShared = shared-shared(1)-rate*t;
err = [errorRef,errorShared,errorShared-errorRef];
slopes = zeros(1,3);
for c = 1:3
    p = polyfit(t,err(:,c),1);
    slopes(c) = p(1);
end
rms = sqrt(mean(err.^2,1));
physicalRms = abs(b)*rms;
end
