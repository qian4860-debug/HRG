function c = five_config(mode, omega, overrides)
% Four electrode groups referenced to COM. Angles and circuit values are
% configurable assumptions until the measured group-port map is available.
arguments
    mode (1,:) char = 'continuous'
    omega (1,1) double {mustBeFinite} = 0.5
    overrides (1,1) struct = struct()
end
assert(ismember(mode,{'continuous','tdm_shared'}), 'Choose continuous or tdm_shared.');
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here,'..','head6800_20261109'));

% Preserve the validated oscillator, controller, timing and converter defaults.
portOptions = struct('group_angles_deg',[0;45;90;135], ...
    'group_charge_gain',ones(4,1),'group_capacitance_F',[], ...
    'drive_on_resistance_ohm',10);
baseOptions = overrides;
for name = string(fieldnames(portOptions))'
    if isfield(overrides,name)
        portOptions.(name) = overrides.(name);
        baseOptions = rmfield(baseOptions,name);
    end
end
c = h68_config(mode,omega,baseOptions);
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

% H projects mechanical X/Y to charge on A/B/C/D. The two Cds branches
% are between A-C and B-D, with signed off-diagonal nodal terms.
H = gain.*[cosd(2*angles),sind(2*angles)];
opposing = [eye(2),-eye(2)];
C = diag(cap) + p.Cds*(opposing'*opposing);
if c.continuous
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

% SI state layout: motional charge and velocity, driver pole voltages,
% four group voltages relative to COM, four filter stages on all groups.
[~,~,initial,plant] = pcn_plant(p);
driveGain = p.pre_gain*p.power_gain;
afe = 2*pi*repmat(p.afe_bw(:),2,1);
qScale = p.charge_target;
vScale = max(1e-6,c.w*qScale*p.Rs);
scales = [qScale*[1 1 c.w c.w],1 1,repmat(vScale,1,4), ...
    repmat(qScale/p.thx_charge_per_input,1,16)];
S = diag(scales);

driveCond = double(driveMask)/ron;
readCond = double(senseMask)/p.Rs;
bleedCond = repmat(1/p.bleed_R,4,1);
[Ad,Bd] = electricalState(driveCond,readCond*double(c.continuous), ...
    zeros(4,1),senseMask & c.continuous);
[Af,Bf] = electricalState(zeros(4,1),zeros(4,1),bleedCond,false(4,1));
[As,Bs] = electricalState(zeros(4,1),readCond,zeros(4,1),senseMask);
[c.Ad,c.Bd] = discrete(Ad,Bd);
[c.Af,~] = discrete(Af,Bf);
[c.As,~] = discrete(As,Bs);
c.x0 = S\[initial(1:4);zeros(22,1)];

c.cvOutputGain = p.pre_gain*p.thx_cv_gain;
c.portCV = [zeros(4,22),eye(4)*qScale/p.thx_charge_per_input*c.cvOutputGain];
c.pickoff = senseMap*c.portCV;
c.motion = [eye(2),zeros(2,24)];
c.groupVoltage = [zeros(4,6),eye(4)*vScale,zeros(4,16)];
c.electrode = senseMap*c.groupVoltage;

% Calibrate the carrier phasors in the active electrical topology.
% Detection calibration uses motional charge with zero commanded drive;
% it does not subtract direct drive feedthrough.
s = 1i*c.w;
driveLoad = diag(driveCond + readCond*double(c.continuous) + p.G0);
if c.continuous
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
c.detect = iqInverse(Hdet);
c.drive = iqInverse(Hdrive);
c.gain_check.detector_V_per_normalized_charge = abs(Hdet(1,1));
c.gain_check.drive_modal_V_per_command = abs(Hdrive(1,1));
c.gain_check.drive_condition = cond(Hdrive);
c.gain_check.sense_condition = cond(Hdet);

    function [A,B] = electricalState(gDrive,gRead,gBleed,readConnected)
        % The four voltage states are continuous at switch transitions.
        % C*dv/dt = Gdrive*(target-v) -(Gread+Gbleed+Gleak)*v - H*dq/dt.
        A = zeros(26);
        B = zeros(26,2);
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
    end

    function [F,G] = discrete(A,B)
        E = expm([S\(A*S),S\B;zeros(2,28)]*c.Ts);
        F = E(1:26,1:26);
        G = E(1:26,27:28);
    end
end

function M = iqInverse(H)
assert(cond(H)<100,'Carrier calibration matrix is ill-conditioned.');
K = H\eye(2);
M = [real(K),imag(K);-imag(K),real(K)];
end
