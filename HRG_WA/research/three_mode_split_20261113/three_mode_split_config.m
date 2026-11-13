function c = three_mode_split_config(mode,rate,split,beta,duration,adcBits)
% 三版归因仿真的统一参数。转速 rad/s，频差 Hz，物理驻波角 deg，时长 s。
% 16 位与 5.44 MSPS 是数值归因工况，供名义闭环及原生模型使用。
arguments
    mode (1,1) string
    rate (1,1) double
    split (1,1) double
    beta (1,1) double
    duration (1,1) double = .012
    adcBits (1,1) double = 16
end
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here,'..','..','HRG_WA_simulink','piezo_v10','five_electrode_20261110'));
opt = struct('f0',6800,'Q',30000,'Cs',600e-12,'split_hz',split, ...
    'theta0',deg2rad(2*beta),'duration',duration,'adc_bits',adcBits, ...
    'adc_span',2,'dac_bits',14,'dac_span',1,'adc_latency',5,'fs',5440000, ...
    'dac_divisor',1,'agc_bw',10,'quad_bw',4,'adc_noise_rms',0,'adc_dither_lsb_rms',0);
c = five_config(char(mode),rate,opt);

% 放大模拟 C/V 投影，数字 I/Q 使用逆增益，保留原机械闭环的增益单位。
gain = 8;
c.portSenseMap = gain*c.portSenseMap;
c.pickoff = c.portSenseMap*c.portCV;
c.detect = c.detect/gain;
c.gain_check.detector_V_per_normalized_charge = ...
    gain*c.gain_check.detector_V_per_normalized_charge;
end
