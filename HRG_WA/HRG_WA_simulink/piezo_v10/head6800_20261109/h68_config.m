function c = h68_config(mode, omega, overrides)
% 6800 Hz 压电全角表头配置：continuous / tdm_shared / tdm_separate 三模式。
% 三模式共用同一物理表头（f0、频差、Q、端口电容不随控制方式变化）；
% 转换器位宽、采样率、ADC 延迟与驱检窗口随模式切换。
% 未实测的电路值（C/V、驱动极点、AAF、开关注入）保持显式假设，
% 不把闭环响应当成表头固有参数。
% Head values are user-supplied; unmeasured circuit values remain assumptions.
% No runtime MATLAB function is called from any generated Simulink model.
arguments
    mode (1,:) char = 'continuous'
    omega (1,1) double {mustBeFinite} = 0.5
    overrides (1,1) struct = struct()
end
assert(ismember(mode,{'continuous','tdm_shared','tdm_separate'}));
here=fileparts(mfilename('fullpath'));
addpath(fullfile(here,'..','revision_v10_2_cn'));
p=pcn_config;
p.f0=6800; p.carrier_hz=6800; p.split_hz=.050; p.Q=30000; p.Cs=600e-12;
p.gamma_intrinsic=pi*p.f0/p.Q; p.Omega=omega;
% One physical head in every mode, independent of converter/switch selection.
p.initial_fraction=1; p.duration=.3;
p.pre_gain=1; p.power_gain=20;
p.detect_matrix=eye(2)*p.pre_gain;
p.drive_matrix=eye(2)*p.pre_gain*p.power_gain;
p.driver_tau=[2e-6;2e-6]; p.afe_bw=[20000;20000]; p.aaf_order=4;
p.adc_bits=16; p.dac_bits=16; p.fs=1088000;
p.adc_span=2; p.dac_span=1; p.vmax=.5;
p.bleed_R=15000; p.reset_tau=2e-6;
p.agc_bw=10; p.quad_bw=4; p.adc_latency=1;
p.log_decimation=200; p.adc_noise_rms=0; p.noise_seed=52;
p.dac_divisor=1;
p.allow_adc_underclock=false; p.seed_enabled=false;
p.seed_seconds=.03; p.seed_voltage=.2;
p.cv_mode='thx2024';
p.thx_cv_gain=1e4; % Gain on the drive readout in the THX source model.
p.thx_charge_per_input=1e-6; % Assumed C per THX input unit for the piezo adapter.
if ~strcmp(mode,'continuous')
    p.adc_bits=10; p.dac_bits=14; p.fs=5440000; p.adc_latency=5;
end
fields=fieldnames(overrides);
for k=1:numel(fields)
    assert(isfield(p,fields{k}),'Unknown override: %s',fields{k});
    p.(fields{k})=overrides.(fields{k});
end
p.gamma_intrinsic=pi*p.f0/p.Q;
p.drive_matrix=p.pre_gain*p.power_gain*eye(2);
p.detect_matrix=p.pre_gain*eye(2);
assert(ismember(p.cv_mode,{'thx2024','legacy_rc'}));
useThx=strcmp(p.cv_mode,'thx2024');
assert(p.thx_cv_gain>0 && p.thx_charge_per_input>0);
p.cv_source=p.cv_mode;
p.Ts=1/p.fs;
n=round(p.fs/p.carrier_hz);
assert(abs(n*p.carrier_hz-p.fs)<1e-7 && mod(n,4)==0,'Choose an integer, multiple-of-four samples per carrier cycle.');
assert(p.fs>2*(p.f0+p.split_hz/2));
if ~strcmp(mode,'continuous') && ~p.allow_adc_underclock
    assert(p.fs>=5e6 && p.fs<=65e6,'AD9215-65 requires a 5..65 MSPS candidate clock.');
end
assert(p.pre_gain>0 && p.power_gain>0 && p.adc_span>0 && p.dac_span==2*p.vmax);
assert(p.Q>0 && p.Cs>0 && p.aaf_order==4);
assert(p.dac_divisor>=1 && p.dac_divisor==round(p.dac_divisor) && mod(n,p.dac_divisor)==0);
assert(p.fs/p.dac_divisor>2*(p.f0+p.split_hz/2));
assert(p.adc_latency>=0 && p.adc_latency==round(p.adc_latency));
c=struct('mode',mode,'reuse',strcmp(mode,'tdm_shared'),'continuous',strcmp(mode,'continuous'), ...
    'Ts',p.Ts,'w',2*pi*p.carrier_hz,'omega',omega,'duration',p.duration,'B',p.B,'n',n, ...
    'adcLatency',p.adc_latency,'logDecimation',p.log_decimation,'p',p);
c.head=struct('f0_Hz',p.f0,'split_Hz',p.split_hz,'Q',p.Q,'parasitic_F',p.Cs, ...
    'f_modes_Hz',p.f0+[-.5 .5]*p.split_hz,'ringdown_s',p.Q/(pi*p.f0), ...
    'linewidth_Hz',p.f0/p.Q,'temperature_model','No per-head temperature curve supplied');
c.driveEnd=n; c.senseStart=1.5*n; c.validStart=2.5*n; c.validEnd=3.5*n; c.frame=4*n;
if c.continuous
    c.driveEnd=n; c.senseStart=0; c.validStart=0; c.validEnd=n; c.frame=n;
end
c.adcStep=p.adc_span/2^p.adc_bits; c.adcMin=-p.adc_span/2; c.adcMax=p.adc_span/2-c.adcStep;
c.dacStep=p.dac_span/2^p.dac_bits; c.dacMin=-p.vmax; c.dacMax=p.vmax-c.dacStep;
c.minEnergy=p.min_amplitude_fraction^2; c.minLinearity=p.min_linearity;
c.agc=2*pi*p.agc_bw; c.gamma=p.gamma_intrinsic; c.quad=2*pi*p.quad_bw;
c.forceScale=2*c.w*p.charge_target/(p.b*(c.driveEnd/c.frame));
c.startCommand=zeros(4,1);
c.seedCommand=[0;0;-p.seed_voltage*cos(p.theta0);-p.seed_voltage*sin(p.theta0)];
c.stateCount=18;
c.pickoff=[zeros(2,16),eye(2)*p.charge_target/p.Cf];
c.motion=[eye(2),zeros(2,16)];
c.electrode=[zeros(2,6),eye(2)*max(1e-6,c.w*p.charge_target*p.Rs),zeros(2,10)];
[~,~,x0,A,B]=pcn_plant(p);
% Cds couples the amplified physical drive port, not the internal pole state.
A(7:8,:)=A(7:8,:)+(p.Cds/p.Cs)*(p.drive_matrix-eye(2))*A(5:6,:);
B(7:8,:)=B(7:8,:)+(p.Cds/p.Cs)*(p.drive_matrix-eye(2))*B(5:6,:);
A(18,18)=0; B(18,2)=0; x0(18,1)=0;
for stage=2:4
    rows=9+2*stage:10+2*stage;
    A(rows,rows-2)=diag(2*pi*p.afe_bw); A(rows,rows)=-diag(2*pi*p.afe_bw);
end
S=diag([p.charge_target*[1 1 c.w c.w],1 1, ...
    max(1e-6,c.w*p.charge_target*p.Rs)*[1 1],p.charge_target/p.Cf*ones(1,10)]);
P=eye(18); Adrive=A; Afloat=A; Asense=A;
if c.reuse
    Adrive(3:4,7:8)=0; Adrive(7:8,:)=0; Adrive(9:10,7:8)=0;
    % Driver pole states are before the output amplifier. The shared contact
    % must see the amplified electrode voltage, just as the mechanical force does.
    P(7:8,:)=0; P(7:8,5:6)=p.drive_matrix;
    Afloat(3:4,5:6)=0;
    Afloat(7:8,7:8)=-(1/p.bleed_R+p.G0)/p.Cs*eye(2);
    Afloat(9:10,7:8)=0; Afloat(9:10,9:10)=-eye(2)/p.reset_tau;
    Asense(3:4,5:6)=0;
end
% THX implements C/V as a static gain. The piezo adapter supplies equivalent
% input from terminal charge. AAF is separate from the THX C/V stage.
c.cvOutputGain=1;
if useThx
    % KCL gives the transferred charge: -q + Cds*Vdrive - Cs*Ve.
    chargeMap=[-eye(2),zeros(2),p.Cds*p.drive_matrix,-p.Cs*eye(2),zeros(2,10)]/p.thx_charge_per_input;
    cutoff=diag(2*pi*p.afe_bw);
    [Adrive,Afloat,Asense]=useThxReadout(Adrive,Afloat,Asense,cutoff,chargeMap,c.reuse);
    % AAF states store the input coordinate of the THX gain. The gain
    % commutes with the identical linear AAF channels.
    S(11:18,11:18)=eye(8)*p.charge_target/p.thx_charge_per_input;
    c.cvOutputGain=p.pre_gain*p.thx_cv_gain;
    c.pickoff=[zeros(2,16),eye(2)*p.charge_target/p.thx_charge_per_input*c.cvOutputGain];
end
[c.Ad,c.Bd]=discretize(Adrive,B,S,P,p.Ts);
[c.Af,~]=discretize(Afloat,B,S,eye(18),p.Ts);
[c.As,~]=discretize(Asense,B,S,eye(18),p.Ts);
c.x0=S\x0;
s=1i*c.w;
sensor=-s/(s*p.Cs+1/p.Rs+p.G0);
chargeAmp=1/(p.Rs*p.Cf*(s+1/(p.Rf*p.Cf)));
afe=2*pi*p.afe_bw(:);
Hdet=p.charge_target*diag((afe./(s+afe)).^p.aaf_order)*p.detect_matrix*(chargeAmp*sensor);
if useThx
    Hdet=p.charge_target*diag((afe./(s+afe)).^p.aaf_order)*c.cvOutputGain ...
        /p.thx_charge_per_input*(-1-p.Cs*sensor);
end
zoh=(1-exp(-s*p.Ts*p.dac_divisor))/(s*p.Ts*p.dac_divisor);
Hdrive=p.drive_matrix*diag(zoh./(1+s*p.driver_tau(:)));
c.detect=real_iq_inverse(Hdet); c.drive=real_iq_inverse(Hdrive);
c.gain_check=struct('drive_pre_V_per_V',p.pre_gain,'sense_pre_V_per_V',p.pre_gain, ...
    'driver_post_gain',p.power_gain,'detector_V_per_normalized_charge',abs(Hdet(1,1)), ...
    'electrode_limit_V',p.vmax*p.pre_gain*p.power_gain);
c.thx_comparison=struct('saved_Kcvd',1e4,'saved_Kcvs',1e5,'saved_Kcsd',1e4,'saved_Kcss',1e5, ...
    'matched_cv_gain',p.thx_cv_gain,'piezo_charge_per_input_unit_C',p.thx_charge_per_input, ...
    'reuse_scope','THX static readout Gain, matched to drive channel source value. Piezo adapter and AAF are external.');
end

function [drive,float,sense]=useThxReadout(drive,float,sense,cutoff,chargeMap,reuse)
sense=setThxInput(sense,cutoff,chargeMap);
if reuse
    drive=setThxInput(drive,cutoff,zeros(size(chargeMap)));
    float=setThxInput(float,cutoff,zeros(size(chargeMap)));
else
    drive=setThxInput(drive,cutoff,chargeMap);
    float=setThxInput(float,cutoff,chargeMap);
end
end

function A=setThxInput(A,cutoff,chargeMap)
A(9:10,:)=0; % No charge-amplifier feedback integrator in the THX gain.
A(11:12,:)=cutoff*chargeMap;
A(11:12,11:12)=-cutoff;
end

function [Ad,Bd]=discretize(A,B,S,P,Ts)
ns=size(A,1); E=expm([S\(A*S),S\B;zeros(2,ns+2)]*Ts); T=S\(P*S);
Ad=T*E(1:ns,1:ns); Bd=T*E(1:ns,ns+1:ns+2);
end
function M=real_iq_inverse(H)
assert(cond(H)<100); K=H\eye(2); M=[real(K),imag(K);-imag(K),real(K)];
end
