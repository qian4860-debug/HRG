function result = run_reproduction
% 第二版逐行复算。只读取本版参数，不调用旧模型，不读取Python结果。
root=fileparts(mfilename('fullpath'));p=jsondecode(fileread(fullfile(root,'parameters.json')));
ev=fullfile(root,'evidence');if ~exist(ev,'dir'),mkdir(ev);end
v=struct;checks=struct;

%% R01-R03 输入、特解系数、初始条件及独立ODE积分
w=2*pi*p.f0_hz;wforce=2*pi*p.forced_frequency_hz;
gamma=w/(2*p.quality_factor);mass=p.mass_kg;A=p.amplitude_m;B=p.bryan;
v.R01_omega0=w;v.R02_gamma=gamma;v.R02_stiffness=mass*w^2;
force=mass*w^2*A/p.quality_factor;f=force/mass;
D=w^2-wforce^2;b=2*gamma*wforce;wd=sqrt(w^2-gamma^2);
u=f*D/(D^2+b^2);vv=-f*b/(D^2+b^2);
C=-vv;S=(-u*wforce+gamma*C)/wd;
v.R02_u=u;v.R02_v=vv;v.R02_C=C;v.R02_S=S;
checks.initial_position=abs(vv+C)/A<1e-12;
checks.initial_velocity=abs(u*wforce-gamma*C+wd*S)/(A*w)<1e-12;
t=(0:p.oscillator_output_step_s:p.oscillator_duration_s)';
opts=odeset('RelTol',1e-10,'AbsTol',[1e-22,1e-17],'MaxStep',1/(200*p.f0_hz));
% 积分器只看到原二阶方程，未从解析轨迹生成结果。
[tout,state]=ode45(@(tt,xx)[xx(2);f*sin(wforce*tt)-2*gamma*xx(2)-w^2*xx(1)],t,[0;0],opts);
xp=u*sin(wforce*t)+vv*cos(wforce*t)+exp(-gamma*t).*(C*cos(wd*t)+S*sin(wd*t));
P=-gamma*C+wd*S;T=-gamma*S-wd*C;
vp=u*wforce*cos(wforce*t)-vv*wforce*sin(wforce*t)+exp(-gamma*t).*(P*cos(wd*t)+T*sin(wd*t));
checks.ode_position=max(abs(state(:,1)-xp))/A<2e-8;
checks.ode_velocity=max(abs(state(:,2)-vp))/(A*w)<2e-8;
writetable(table(tout,state(:,1),state(:,2),'VariableNames',{'t_s','x_m','velocity_m_s'}),fullfile(ev,'matlab_oscillator.csv'));

%% R06 手算圆环的积分结果
rho=2200;Ac=.001*.0001;Ic=.001*.0001^3/12;rad=.01;young=72e9;n=2;
mr=rho*Ac*pi*rad*(1+1/n^2);kr=pi*young*Ic*(n^2-1)^2/rad^3;
v.R06_ring_mass=mr;v.R06_ring_stiffness=kr;v.R06_ring_frequency=sqrt(kr/mr)/(2*pi);v.R06_ring_B=2/(n^2+1);

%% R08-R09 先构造IQ，再从公开IQ计算不变量
theta=.2;phi=.3;aa=1;bb=.1;J=[0,-1;1,0];nn=[cos(2*theta);sin(2*theta)];
z=exp(1i*phi)*(aa*nn+1i*bb*J*nn);
E=sum(abs(z).^2);Q=2*imag(conj(z(1))*z(2));R=abs(z(1))^2-abs(z(2))^2;SS=2*real(conj(z(1))*z(2));
checks.invariant_energy=abs(E^2-Q^2-R^2-SS^2)<1e-12;
checks.invariant_quadrature=abs(Q-2*aa*bb)<1e-12;
checks.invariant_direction=abs(atan2(SS,R)/4-theta)<1e-12;
v.R09_dead_zone_deg_h=p.damping_difference_s/(4*B)*180/pi*3600;

%% R10-R13 电容、电流、传递、噪声与ADC预算
cap=p.capacitance_f*A/p.gap_m;current=p.bias_v*w*cap;
v.R10_capacitance_peak=cap;v.R11_current_peak=current;
s=1i*w;Z=p.rf_ohm/(1+s*p.rf_ohm*p.cf_f);NG=1+s*p.cin_f*Z;
ha=prod(1./sqrt(1+(p.f0_hz./p.analog_poles_hz).^2));Vpk=current*abs(Z)*ha;
v.R11_Zf_magnitude=abs(Z);v.R11_analog_magnitude=ha;v.R11_ADC_peak=Vpk;
kT=1.380649e-23*p.temperature_k;iR=sqrt(4*kT/p.rf_ohm);
eV=abs(NG)*p.en_v_rtHz;eI=abs(Z)*p.in_a_rtHz;eR=abs(Z)*iR;
v.R12_Rf_current_ASD=iR;v.R12_voltage_noise=eV;v.R12_current_noise=eI;v.R12_resistor_noise=eR;
v.R12_AFE_ASD=sqrt(eV^2+eI^2+eR^2);
allow=2*B*Vpk*p.angle_budget_rad/sqrt(2*p.noise_bandwidth_hz);
delta=2*p.adc_half_range_v/2^p.adc_bits;
v.R13_allowed_ASD=allow;v.R13_ADC_step=delta;
v.R13_ADC_angle=delta/(2*B*Vpk)*sqrt(p.noise_bandwidth_hz/(3*p.adc_rate_hz));
v.R13_ideal_bits=ceil(log2(2*p.adc_half_range_v/(2*B*Vpk*p.angle_budget_rad)*sqrt(p.noise_bandwidth_hz/(3*p.adc_rate_hz))));
v.R13_gain_error_deg=p.gain_error/(4*B)*180/pi;

%% R15-R17 时钟、冲激响应、ENBW
v.R15_NCO_FCW=round(5000/40000*2^32);v.R15_NCO_step_hz=40000/2^32;v.R15_skew_limit=1e-4/w;
box=ones(1,40)/40;hc=conv(conv(box,box),box);hf=zeros(1,161);hf(1:40:end)=[1,2,3,2,1]/9;
h=conv(hc,hf);v.R17_ENBW=40000/2*sum(h.^2);v.R17_delay=.0014625+.002+.004+.0000625;
checks.filter_dc_gain=abs(sum(h)-1)<1e-12;

%% R18-R20 功率、启动积分、PI系数及交越频率
hold=mass*w^2*A/p.quality_factor;den=-expm1(-gamma*.1);start=2*mass*w*gamma*A/den;
v.R18_hold_voltage=hold/p.drive_n_per_v;v.R18_start_voltage=start/p.drive_n_per_v;
v.R18_start_denominator=den;v.R18_DAC_hold_codes=v.R18_hold_voltage/(4/2^16);
kp=.8*2*pi*.8;ki=(2*pi*.8)^2/2;la=2*kp;lb=2*ki;
wc=sqrt((la^2+sqrt(la^4+4*lb^2))/2);
v.R19_Kp=kp;v.R19_Ki=ki;v.R20_crossover_hz=wc/(2*pi);
v.R20_phase_margin_deg=90-atan(ki/(kp*wc))*180/pi-wc*v.R17_delay*180/pi;
checks.crossover_equation=abs((la^2*wc^2+lb^2)/wc^4-1)<1e-12;

%% R21-R25 模拟环形极点、Kalman、外部参考与RLS
rp=roots([1,3,3,28]);
checks.ring_one_negative_real=nnz(real(rp)<0)==1 && nnz(real(rp)>0)==2;
Fk=[1,.001;0,1];Pm=Fk*diag([1,4])*Fk';kg=Pm(:,1)/(Pm(1,1)+.01);
v.R23_gain_angle=kg(1);v.R23_gain_rate=kg(2);
X=[1,0,1;0,1,1];DD=[1,.02;-.01,1.01];Y=DD*X;fit=(X'\Y')';
checks.external_reference_fit=max(abs(fit-DD),[],'all')<1e-12;
beta=zeros(2,1);PP=100*eye(2);info=inv(PP);rhs=info*beta;lambda=.997;
for k=1:100
    ph=[1;sin(k*.31)];yy=ph'*[.3;-.7];gain=PP*ph/(lambda+ph'*PP*ph);
    beta=beta+gain*(yy-ph'*beta);PP=(PP-gain*ph'*PP)/lambda;
    info=lambda*info+ph*ph';rhs=lambda*rhs+ph*yy;
end
checks.RLS_batch=max(abs(beta-info\rhs))<1e-12;

%% R26-R33 检测伪阻尼、参考偏置、采样矩阵、整数配置
v.R26_false_damping=2*p.gain_error*B*80*pi/180;
v.R26_true_ds=p.damping_difference_s/2*sin(4*p.damping_axis_rad);
v.R29_false_split_mHz=(sqrt(w^2-1200)-sqrt(w^2-2000))/(2*pi)*1000;
gram=[1.5,-.5;-.5,.5];v.R31_Gram_condition=cond(gram);
v.R31_pump_threshold_v=mass*w^2*p.gap_m^2/(4*p.quality_factor*p.capacitance_f*10);
v.R32_IQ_bound=sqrt(2)*2^-22/(4*B);
v.R33_FCW_6200=round(6200/40000*2^32);v.R33_Bryan_03_code=round(.3*2^30);v.R33_Eref_12_code=round(1.2*2^24);

%% R35 高Q数值耗散用log1p避免在1附近相减
for fs=[400000,800000]
    r=w/fs;mag2_delta=-r^6/72+r^8/576;
    v.(sprintf('R35_num_damping_ratio_%d',fs))=-fs*.5*log1p(mag2_delta)/gamma;
end

%% 保存新实跑结果及科学图，不关闭用户已有图窗
result=struct('date','2026-10-27','MATLAB',version,'scope','Derivation worksheet and scalar ODE only; no full RF or RTL rerun','values',v,'checks',checks);
flags=struct2cell(checks);result.pass=all(cellfun(@(x)logical(x),flags));
fid=fopen(fullfile(ev,'matlab_results.json'),'w','n','UTF-8');fprintf(fid,'%s\n',jsonencode(result,'PrettyPrint',true));fclose(fid);
fig=figure('Visible','off','Color','w','Position',[100,100,1100,650]);
tiledlayout(2,1);nexttile;plot(t*1e3,state(:,1)*1e12,'b-',t*1e3,xp*1e12,'r--');
xlabel('Time (ms)');ylabel('Displacement (pm)');legend('ODE45 on original equation','Closed form','Location','best');grid on;
nexttile;plot(t*1e3,(state(:,1)-xp)/A);xlabel('Time (ms)');ylabel('Position error / Aref');grid on;
exportgraphics(fig,fullfile(ev,'forced_response.png'),'Resolution',160);close(fig);
fprintf('V2 scalar ODE and derivation worksheet: %d checks, pass=%d\n',numel(flags),result.pass);
assert(result.pass,'A derivation worksheet check failed; results were saved for review.');
end
