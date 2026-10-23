function report=w7_validate_scoreboards()
% Independent equations, exact augmented matrix transitions, and negative tests.
c=w7_config();checks=struct('name',{},'error',{},'limit',{},'pass',{});
theta=linspace(-2*pi,2*pi,2049)';alpha=2*theta;a=1.2;b=.13;ph=.47;
d=[a*cos(alpha)-1i*b*sin(alpha),a*sin(alpha)+1i*b*cos(alpha)]*exp(1i*ph);
R=abs(d(:,1)).^2-abs(d(:,2)).^2;S=2*real(conj(d(:,1)).*d(:,2));
check('ellipse_four_theta',max(abs(R+1i*S-(a*a-b*b)*exp(4i*theta))),1e-12);
% Exact common transimpedance law, displacement-normalized and signed by wiring.
for mode={'charge','tia'}
 q=w7_config([],struct('readoutMode',mode{1}));s=2i*pi*q.head.f0;
 physical=q.biasV*q.c0F/q.gapM*q.displacementM*s*q.rfOhm/(1+s*q.rfOhm*q.cfF)*q.pgaGain;
 equivalent=q.biasV*q.c0F/q.gapM*q.displacementM/q.cfF*q.pgaGain* ...
  s*q.rfOhm*q.cfF/(1+s*q.rfOhm*q.cfF);
 check([mode{1} '_exact_transfer'],abs(physical-equivalent),1e-12);
end
% Windowed IQ: test several nontrivial NCO origins and ADC latency alignment.
q=w7_config([],struct('tdmMode','switched'));N=round(q.fsAdc*q.head.Ts);t=(0:N-1)'/q.fsAdc;
z=[.7+.21i;-.4+.13i];gain=q.biasV*q.c0F/q.gapM*q.displacementM/q.cfF*q.pgaGain;
for phase=[0 .43 1.7]
 total=zeros(4,1);
 for k=1:N
  p=2*pi*q.head.f0*t(k)+phase;
  volts=gain*real(z*exp(1i*(p-2*pi*q.head.f0*q.adcDelay/q.fsAdc)));
  total=total+w7_mix([volts;p;t(k)],q)/N;
 end
 expected=z*exp(-2i*pi*q.head.f0*q.adcDelay/q.fsAdc);
 check(sprintf('masked_IQ_phase_%.2f',phase),max(abs(total-[real(expected);imag(expected)])),1e-12);
end
g=zeros(N,4);for k=1:N,g(k,:)=w7_switches(t(k),q)';end
check('drive_and_read_disjoint',max(g(:,1).*g(:,2)),0);
check('read_valid_is_subset',max(g(:,4).*(1-g(:,2))),0);
check('unload_present',abs(mean(g(:,3))-.4),1e-12);
% Differential electrostatic law at the origin has independently known slopes.
q=c;q.v7.actuationMode='electrostatic';dv=1e-4;dx=1e-3;
Fplus=w7_force([dv;0;0;0],q)*q.massKg*q.displacementM;
Fminus=w7_force([-dv;0;0;0],q)*q.massKg*q.displacementM;
kV=2*q.v7.electrostaticForceScale*q.c0F*q.v7.driveBiasV/q.gapM;
check('electrostatic_voltage_gradient',abs((Fplus(1)-Fminus(1))/(2*dv)/kV-1),1e-9);
Fplus=w7_force([0;0;dx;0],q)*q.massKg*q.displacementM;
Fminus=w7_force([0;0;-dx;0],q)*q.massKg*q.displacementM;
kx=2*q.v7.electrostaticForceScale*q.c0F*q.v7.driveBiasV^2/q.gapM^2;
check('electrostatic_negative_stiffness',abs((Fplus(1)-Fminus(1))/(2*dx*q.displacementM)/kx-1),1e-8);
% Independent matrix exponential oracle for the resonant controller state.
q=c;q.v7.controlMode='PIR';q.v7.startupEnable=false;
q.head.energyKp=0;q.head.energyKi=0;q.head.quadKp=0;q.head.quadKi=0;q.head.pllKp=0;q.head.pllKi=0;
q.controlFractionBits=0;q.v7.slewPerS=[1e6;1e6;1e6];q.v7.resonantGain=[0;1;0];
st=zeros(17,1);omega=1.6;st(14)=omega;st(15)=1;st(17)=1;
st(9:10)=[.03;-.02];err=-.1;
A=[-q.v7.resonantLeakRadS -omega;omega -q.v7.resonantLeakRadS];
aug=expm([A [1;0];0 0 0]*q.head.Ts);
expected=aug(1:2,1:2)*st(9:10)+aug(1:2,3)*err;
in=[1;0;0;0;1;.1;cos(omega*q.head.Ts);sin(omega*q.head.Ts);0;0];
y=w7_control_tick([in;st;0],q);
check('resonator_exact_matrix_oracle',max(abs(y(9:10)-expected)),1e-12);
check('PIR_uses_measured_four_theta_rate',abs(y(14)-omega),1e-12);
q.v7.controlMode='PI';y=w7_control_tick([in;st;0],q);
check('PI_disables_resonant_output',max(abs(y(29:31))),0);
% Zero input still produces bounded open-loop excitation until feedback exists.
q=c;st=zeros(17,1);y=w7_control_tick([zeros(10,1);st;0],q);
check('zero_energy_start_command',abs(norm(y(18:21))-q.v7.startupAmplitudePerS*abs(q.v7.driveCalibration)),1e-12);
st(16)=ceil(q.v7.startupTimeoutS/q.head.Ts);y=w7_control_tick([zeros(10,1);st;0],q);
check('startup_timeout_stops_force',norm(y(18:21)),0);
check('startup_timeout_status',abs(y(26)-2),0);
% Fail closed on malformed timing rather than silently accepting a wrong gain.
q=c;q.v7.tdmMode='switched';q.v7.slotCycles=[1;1;3;1];rejected=false;
try,w7_validate(q);catch,rejected=true;end
check('noncoherent_frame_rejected',double(~rejected),0);
rejected=false;
try,w7_envelope(c,false);catch e,rejected=contains(e.message,'excludes carrier noise');end
check('envelope_cannot_silently_ignore_noise_enable',double(~rejected),0);
report=struct('checks',checks,'pass',all([checks.pass]), ...
 'scope','algebra, causal timing, matrix oracle, and startup safety; not physical performance');
folder=fullfile(fileparts(mfilename('fullpath')),'evidence');if ~isfolder(folder),mkdir(folder);end
wl_write_json(fullfile(folder,'unit_scoreboards.json'),report);assert(report.pass,'V7 unit scoreboards failed');
 function check(n,e,l)
  checks(end+1)=struct('name',n,'error',e,'limit',l,'pass',isfinite(e)&&e<=l);
  fprintf('%s: %.9g <= %.9g : %d\n',n,e,l,checks(end).pass);
 end
end
