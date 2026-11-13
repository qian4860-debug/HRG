function c = five_config(mode, omega, overrides)
% 五电极配置：A/B/C/D 四组对称电极相对公共端 COM，另加一个模态表头。
% 输入：
%   mode     'continuous' 连续驱检，或 'tdm_shared' 检测电极分时复用，'tdm_separate' 分时但检测电极固定；
%   omega    机体角速度，单位 rad/s，仅用于闭环评分；
%   overrides 覆盖端口/电路/时序参数的结构体。
% 输出 c 含 26 状态离散矩阵、组端投影 H、电容矩阵 C、驱动/检测映射、
% 转换器位宽与四段时序。角度单位 deg，电容单位 F，组增益含极性；
% COM 在模型中暂定义为理想电位参考，实测回流阻抗需另行回填。
arguments
    mode (1,:) char = 'continuous'
    omega (1,1) double {mustBeFinite} = 0.5
    overrides (1,1) struct = struct()
end
assert(ismember(mode,{'continuous','tdm_shared','tdm_separate'}), '未知的五电极驱检模式。');
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here,'..','head6800_20261109'));

% 保留已验证的振荡器、控制器、时序和转换器默认值；只替换五端端口参数。
% 组角默认 0/45/90/135 deg；组增益含压电极性；组端电容默认沿用 600 pF，
% 但“每组 600 pF”与“四组合计 600 pF”是两种口径，实测前不得混用。
portOptions = struct('group_angles_deg',[0;45;90;135], ...
    'group_charge_gain',ones(4,1),'group_capacitance_F',[], ...
    'drive_on_resistance_ohm',10,'diagnostic_carrier_phase_rad',[]);
% ADC 前独立读出链可配置无量纲增益、单极点 (Hz) 和标定方式。
% 默认保留旧 26 状态；启用后增加两路物理读出记忆，数字校准默认冻结。
readout = struct('readout_channel_gain',[],'readout_channel_pole_Hz',[], ...
    'readout_calibrate',false);
baseOptions = overrides;
for name = string(fieldnames(readout))'
    if isfield(baseOptions,name)
        readout.(name) = baseOptions.(name);
        baseOptions = rmfield(baseOptions,name);
    end
end
hasReadout = ~isempty(readout.readout_channel_gain) || ~isempty(readout.readout_channel_pole_Hz);
assert(islogical(readout.readout_calibrate) && isscalar(readout.readout_calibrate), ...
    'readout_calibrate must be a logical scalar.');
assert(hasReadout || ~readout.readout_calibrate, 'Enable the analog channel model before calibrating.');
if hasReadout
    validateattributes(readout.readout_channel_gain,{'double'}, ...
        {'real','finite','positive','numel',2});
    validateattributes(readout.readout_channel_pole_Hz,{'double'}, ...
        {'real','finite','positive','numel',2});
    readoutGain = readout.readout_channel_gain(:);
    readoutPole = 2*pi*readout.readout_channel_pole_Hz(:);
end
for name = string(fieldnames(portOptions))'
    if isfield(overrides,name)
        portOptions.(name) = overrides.(name);
        baseOptions = rmfield(baseOptions,name);
    end
end
c = h68_config(mode,omega,baseOptions);
% 研究用载波相对分时窗的初始相位。测量中心按有效样本位置定义。
if ~isempty(portOptions.diagnostic_carrier_phase_rad)
    validateattributes(portOptions.diagnostic_carrier_phase_rad,{'double'}, ...
        {'real','finite','scalar'});
    c.carrierPhase_rad = portOptions.diagnostic_carrier_phase_rad;
    c.framePublishToCenter_s = (c.validEnd+c.adcLatency ...
        -(c.validStart+c.validEnd-1)/2)*c.Ts;
end
p = c.p;
assert(strcmp(p.cv_mode,'thx2024'),'This model uses the matched thx2024 C/V.');
if isempty(portOptions.group_capacitance_F)
    portOptions.group_capacitance_F = repmat(p.Cs,4,1);
end
angles = portOptions.group_angles_deg(:);
gain = portOptions.group_charge_gain(:);
cap = portOptions.group_capacitance_F(:);
ron = portOptions.drive_on_resistance_ohm;
assert(numel(angles)==4 && all(isfinite(angles)), 'Supply four group angles.');
assert(numel(gain)==4 && all(isfinite(gain)) && all(gain~=0), ...
    'Supply four nonzero group coupling gains, including polarity.');
assert(numel(cap)==4 && all(isfinite(cap) & cap>0), 'Supply four positive group capacitances.');
assert(isscalar(ron) && isfinite(ron) && ron>0, 'Drive on-resistance must be positive.');
assert(isscalar(p.Cds) && isfinite(p.Cds) && p.Cds>=0, 'Mutual capacitance must be nonnegative.');

% H 把机械 X/Y 模态投影到 A/B/C/D 四组电荷：
%   H = gain .* [cos(2*angle), sin(2*angle)]，每行一组。
% C 为组端对 COM 的 4x4 电容矩阵；当前只含对角组电容与 A-C、B-D
% 两支互耦 Cds，真实 A-B/B-C/C-D 与 COM 对壳电容需实测后替换。
H = gain.*[cosd(2*angles),sind(2*angles)];
opposing = [eye(2),-eye(2)];
C = diag(cap) + p.Cds*(opposing'*opposing);
% 连续和分时不复用：A/B 驱动，C/D 永久接检测输入。分时复用：
% A/C、B/D 反相驱动，检测窗以模拟半差 (A-C)/2、(B-D)/2 得到 X/Y。
if ~c.reuse
    driveMap = [eye(2);zeros(2)];
    driveMask = [true;true;false;false];
    senseMap = [zeros(2),-eye(2)];
    senseMask = ~driveMask;
else
    driveMap = opposing';
    driveMask = true(4,1);
    senseMap = opposing/2;
    senseMask = true(4,1);
end
assert(rank(H'*driveMap)==2 && rank(senseMap*H)==2, ...
    'The electrode layout must support two independent drive and readout modes.');

c.stateCount = 26;
c.stateRows = {'1:4','5:6','7:10','11:26'};
if hasReadout
    c.stateCount = 28;
    c.stateRows{end+1} = '27:28';
end
c.portDriveMap = driveMap;
c.portSenseMap = senseMap;
c.portCoupling = H;
c.portCapacitance_F = C;
c.portShuntCapacitance_F = cap;
c.groupAngles_deg = angles;
c.groupNames = {'A','B','C','D'};
c.commonTerminal = 'COM';
c.portOptions = portOptions;
c.head.group_shunt_F = cap;

% SI 状态排列（26 维）：
%   1:4   机械模态电荷与速度；
%   5:6   驱动极点电压；
%   7:10  A/B/C/D 四组相对 COM 的端电压；
%   11:26 四组各四级抗混叠/THX2024 静态 C/V 输入状态。
[~,~,initial,plant] = pcn_plant(p);
driveGain = p.pre_gain*p.power_gain;
afe = 2*pi*repmat(p.afe_bw(:),2,1);
qScale = p.charge_target;
vScale = max(1e-6,c.w*qScale*p.Rs);
scales = [qScale*[1 1 c.w c.w],1 1,repmat(vScale,1,4), ...
    repmat(qScale/p.thx_charge_per_input,1,16)];
if hasReadout
    scales = [scales,repmat(qScale/p.thx_charge_per_input,1,2)];
end
S = diag(scales);

driveCond = double(driveMask)/ron;
readCond = double(senseMask)/p.Rs;
bleedCond = repmat(1/p.bleed_R,4,1);
% 分时不复用仅门控 DAC 与 ADC。驱动端电气负载和检测端接法在各窗保持一致。
permanentRead = ~c.reuse;
[Ad,Bd] = electricalState(driveCond,readCond*double(permanentRead), ...
    zeros(4,1),senseMask & permanentRead);
[Af,Bf] = electricalState(zeros(4,1),zeros(4,1),bleedCond,false(4,1));
[As,Bs] = electricalState(zeros(4,1),readCond,zeros(4,1),senseMask);
[c.Ad,c.Bd] = discrete(Ad,Bd);
[c.Af,~] = discrete(Af,Bf);
[c.As,~] = discrete(As,Bs);
if strcmp(mode,'tdm_separate')
    c.Af = c.Ad;
    c.As = c.Ad;
end
c.x0 = S\[initial(1:4);zeros(c.stateCount-4,1)];

c.cvOutputGain = p.pre_gain*p.thx_cv_gain;
c.portCV = zeros(4,c.stateCount);
c.portCV(:,23:26) = eye(4)*qScale/p.thx_charge_per_input*c.cvOutputGain;
c.pickoff = senseMap*c.portCV;
if hasReadout
    c.pickoff = [zeros(2,26),eye(2)*qScale/p.thx_charge_per_input*c.cvOutputGain];
    c.readoutAnalogMismatch = readout;
end
c.motion = [eye(2),zeros(2,c.stateCount-2)];
c.groupVoltage = [zeros(4,6),eye(4)*vScale,zeros(4,c.stateCount-10)];
c.electrode = senseMap*c.groupVoltage;

% 在当前电气拓扑下标定载波相量：
%   Hdet  由“静态 C/V + 四级 AAF + 组端电容/导纳”得到，检测校准只用
%         机械运动电荷，不扣除驱动直通；Hdrive 由驱动窗的 DAC->组端
%         电压传递得到。iqInverse 把复数 2x2 响应转成实数 I/Q 校准矩阵。
% 注意：这里没有包含 Cds 之外的组间互耦，也没有 COM 回流阻抗。
s = 1i*c.w;
driveLoad = diag(driveCond + readCond*double(permanentRead) + p.G0);
if permanentRead
    senseLoad = driveLoad;
else
    senseLoad = diag(readCond + p.G0);
end
VperQ = (s*C+senseLoad)\(-s*H);
chargePerQ = -H-C*VperQ;
filterGain = diag((afe./(s+afe)).^4);
Hdet = senseMap*filterGain*chargePerQ*(qScale/p.thx_charge_per_input*c.cvOutputGain);
zoh = (1-exp(-s*c.Ts*p.dac_divisor))/(s*c.Ts*p.dac_divisor);
VperCommand = (s*C+driveLoad)\(diag(driveCond)*driveGain*driveMap) ...
    * diag(zoh./(1+s*p.driver_tau(:)));
Hdrive = H'*VperCommand;
if hasReadout
    % 只用独立标定得到的参数可进行理想补偿对照。冻结工况保持原检测矩阵。
    c.readoutCarrierResponse = readoutGain.*readoutPole./(s+readoutPole);
    if readout.readout_calibrate
        Hdet = diag(c.readoutCarrierResponse)*Hdet;
    end
end
c.detect = iqInverse(Hdet);
c.drive = iqInverse(Hdrive);
c.gain_check.detector_V_per_normalized_charge = abs(Hdet(1,1));
c.gain_check.drive_modal_V_per_command = abs(Hdrive(1,1));
c.gain_check.drive_condition = cond(Hdrive);
c.gain_check.sense_condition = cond(Hdet);

    function [A,B] = electricalState(gDrive,gRead,gBleed,readConnected)
        % The four voltage states are continuous at switch transitions.
        % C*dv/dt = Gdrive*(target-v) -(Gread+Gbleed+Gleak)*v - H*dq/dt.
        A = zeros(c.stateCount);
        B = zeros(c.stateCount,2);
        A(1:4,1:4) = plant(1:4,1:4);
        % The same piezoelectric group retains its coupling in all slots.
        % Switches alter terminal voltage through KCL, not the force coefficient.
        A(3:4,7:10) = p.b*H';
        pole = diag(1./p.driver_tau(:));
        A(5:6,5:6) = -pole;
        B(5:6,:) = pole;
        A(7:10,3:4) = C\(-H);
        A(7:10,5:6) = C\(diag(gDrive)*driveGain*driveMap);
        A(7:10,7:10) = C\(-diag(gDrive+gRead+gBleed+p.G0));
        % Equivalent charge entering each connected input, then analog AAF.
        % Static THX gain commutes with the linear, per-port AAF.
        readScale = diag(afe.*double(readConnected))/p.thx_charge_per_input;
        A(11:14,1:2) = -readScale*H;
        A(11:14,7:10) = -readScale*C;
        for stage = 1:4
            rows = (7+4*stage):(10+4*stage);
            A(rows,rows) = -diag(afe);
            if stage>1, A(rows,rows-4) = diag(afe); end
        end
        if hasReadout
            % 组端 C/V 半差之后、量化之前的连续时间读出极点。
            % 泄放与建立窗同样更新该状态，跨窗保留物理记忆。
            A(27:28,23:26) = diag(readoutPole.*readoutGain)*senseMap;
            A(27:28,27:28) = -diag(readoutPole);
        end
    end

    function [F,G] = discrete(A,B)
        n = c.stateCount;
        E = expm([S\(A*S),S\B;zeros(2,n+2)]*c.Ts);
        F = E(1:n,1:n);
        G = E(1:n,n+(1:2));
    end
end

function M = iqInverse(H)
assert(cond(H)<100,'Carrier calibration matrix is ill-conditioned.');
K = H\eye(2);
M = [real(K),imag(K);-imag(K),real(K)];
end
