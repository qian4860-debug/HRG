function p=p101_envelope_config()
p=p101_config;p.envTs=.02;p.envDuration=300;p.Omega=.005;p.virtual_rate=0;
p.split_hz=.002;p.stiffness_axis=.41;p.damping_half_difference=.02;p.damping_axis=-.23;
p.env_quad_gain=25;p.env_phase_gain=20;p.env_amplitude_gain=5;
end
