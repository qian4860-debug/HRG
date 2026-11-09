function c = tdm_config(reuse, omega)
% Shared synthetic configuration. omega is body rate in rad/s.
arguments
    reuse (1,1) logical
    omega (1,1) double {mustBeFinite} = 0.5
end
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', 'revision_v10_2_cn'));
p = pcn_config;
p.Ts = 1/160000;
p.Omega = omega;
p.duration = 1.2;
w = 2*pi*p.f0;
n = round(1/(p.f0*p.Ts));
assert(abs(n*p.Ts*p.f0 - 1) < 1e-12, 'The coherent detector requires a whole carrier cycle.');

% Zero-based slot counts: drive, open/bleed, connect/settle, valid read, open.
c = struct('reuse', reuse, 'Ts', p.Ts, 'w', w, 'omega', omega, ...
    'duration', p.duration, 'B', p.B, 'driveEnd', n, 'senseStart', n+32, ...
    'validStart', n+112, 'validEnd', 2*n+112, 'frame', 3*n, 'n', n);
assert(c.driveEnd < c.senseStart && c.senseStart < c.validStart && c.validEnd < c.frame);
c.adcStep = p.adc_span/2^p.adc_bits;
c.adcMax = p.adc_span/2-c.adcStep;
c.adcMin = -p.adc_span/2;
c.dacStep = p.dac_span/2^p.dac_bits;
c.dacMax = p.vmax-c.dacStep;
c.dacMin = -p.vmax;
c.minEnergy = p.min_amplitude_fraction^2;
c.minLinearity = p.min_linearity;
c.agc = 2*pi*2;
c.gamma = p.gamma_intrinsic;
c.quad = 2*pi*p.quad_bw;
c.forceScale = 2*w*p.charge_target/(p.b*(c.driveEnd/c.frame));
c.startCommand = zeros(4,1);
c.pickoff = [zeros(2,10), eye(2)*p.charge_target/p.Cf];
c.electrode = [zeros(2,6), eye(2)*max(1e-6,w*p.charge_target*p.Rs), zeros(2,4)];
c.motion = [eye(2), zeros(2,10)];

% The dedicated pickoff remains loaded throughout the frame. The shared
% electrode follows the driver when driven, floats through a bleed resistor
% during both breaks, and connects to the same pickoff load in sense mode.
[~,~,x0,A,B] = pcn_plant(p);
S = diag([p.charge_target*[1 1 w w], 1 1, ...
    max(1e-6,w*p.charge_target*p.Rs)*[1 1], p.charge_target/p.Cf*[1 1 1 1]]);
P = eye(12);
Adrive = A;
Afloat = A;
Asense = A;
if reuse
    Adrive(3:4,7:8) = 0;
    Adrive(7:8,:) = 0;
    Adrive(9:10,7:8) = 0;
    P(7:8,:) = 0;
    P(7:8,5:6) = eye(2);
    Afloat(3:4,5:6) = 0;
    Afloat(7:8,7:8) = -(1/15000+p.G0)/p.Cs*eye(2);
    Afloat(9:10,7:8) = 0;
    % A reset switch across Cf clears the amplifier's accumulated baseline
    % while the electrode is disconnected. The sense phase restores Rf*Cf.
    Afloat(9:10,9:10) = -eye(2)/20e-6;
    Asense(3:4,5:6) = 0;
end
[c.Ad,c.Bd] = discretize(Adrive,B,S,P,p.Ts);
[c.Af,~] = discretize(Afloat,B,S,eye(12),p.Ts);
[c.As,~] = discretize(Asense,B,S,eye(12),p.Ts);
c.x0 = S\x0;

% Calculate an independent sinusoidal calibration from the declared analog
% parameters. Complex convention z=I-jQ, with a 2x2 channel matrix.
s = 1i*w;
sensor = -s/(s*p.Cs + 1/p.Rs + p.G0);
chargeAmp = 1/(p.Rs*p.Cf*(s + 1/(p.Rf*p.Cf)));
afe = 2*pi*p.afe_bw(:);
Hdet = p.charge_target*diag(afe./(s+afe))*p.detect_matrix*(chargeAmp*sensor);
% Frequency response from digital command through ZOH and driver poles.
zoh = (1-exp(-s*p.Ts))/(s*p.Ts);
Hdrive = p.drive_matrix*diag(zoh./(1+s*p.driver_tau(:)));
assert(cond(Hdet) < p.max_calibration_condition && cond(Hdrive) < p.max_calibration_condition);
c.detect = real_iq_inverse(Hdet);
c.drive = real_iq_inverse(Hdrive);
end

function [Ad,Bd] = discretize(A,B,S,P,Ts)
E = expm([S\(A*S), S\B; zeros(2,14)]*Ts);
T = S\(P*S);
Ad = T*E(1:12,1:12);
Bd = T*E(1:12,13:14);
end

function M = real_iq_inverse(H)
K = H\eye(2);
M = [real(K), imag(K); -imag(K), real(K)];
end
