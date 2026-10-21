function p = wa_parameters(profile)
% Public-equation abstraction. SI units; defaults are unmeasured assumptions.
root = fileparts(mfilename('fullpath'));
if nargin < 1
    profile = fullfile(root, '..', 'HRG_WA_Digital_ASIC_MATLAB_v4_6_5_FRP_validation_fix', ...
        'HRG_WA', 'config', 'head_default.json');
end
head = jsondecode(fileread(profile));
p.sourceProfile = profile;
p.measurementStatus = 'assumed, not a measured head';
p.f0 = head.mechanical.f0_hz;
p.Q = head.mechanical.quality_factor;
p.bryan = head.mechanical.bryan;
p.gamma = pi*p.f0/p.Q;
p.dgamma = head.mechanical.damping_anisotropy_per_s;
p.dampingAxis = head.mechanical.damping_axis_deg*pi/180;
p.splitHz = head.mechanical.frequency_split_hz;
p.stiffnessAxis = head.mechanical.stiffness_axis_deg*pi/180;
p.detuningHz = 0;
p.duffingHz = head.mechanical.duffing_hz_per_energy;
p.temperatureCoeff = -18e-6;
p.referenceTemperature = 25;
p.detect = head.detection.cross_matrix;
p.detectPhase = head.detection.phase_delay_deg(:)*pi/180;
p.drive = head.drive.cross_matrix;
p.detectCubic = 0;
p.iqBits = 0; % 0: no quantization; this is envelope I/Q, not an ADC.
p.iqFullScale = 2;
p.energyTarget = head.mechanical.energy_target;
p.initialEnergy = head.mechanical.initial_energy;
p.initialTheta = head.mechanical.initial_theta_deg*pi/180; % Physical rim angle; modal azimuth is twice this.
p.initialQuadRatio = .015;
p.energyKp = .8; p.energyKi = .4;
p.quadKp = 2; p.quadKi = 1;
p.pllKp = .8; p.pllKi = 1;
p.energyLimit = 1; p.quadLimit = 1; p.pllLimitHz = 2;
p.antiWindup = 5;
p.loopEnable = 1;
p.Ts = .001;
p.rateTau = .02;
p.energyThreshold = .02;
p.angleThreshold = .01;
p.duration = 12;
p.omega = 80*pi/180;
p.virtualRate = 0;
p.temperature = 25;
p.fullStep = 1/(100*p.f0);
wa_validate_parameters(p);
end
