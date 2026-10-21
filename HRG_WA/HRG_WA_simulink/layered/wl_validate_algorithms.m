function result=wl_validate_algorithms()
root=fileparts(mfilename('fullpath'));addpath(root);c=wl_setup(wl_config(5));p=c.legacyP;rng(c.seed);
checks=struct('name',{},'value',{},'limit',{},'pass',{});
% ADC quantization bound and signed endpoints, independent arithmetic oracle.
N=12;fs=2;lsb=2*fs/2^N;x=linspace(-1.9,1.9,10001).';
y=wl_quantize(x,N,fs,0);check('ADC_half_LSB_bound',max(abs(y-x)),lsb/2+eps);
y=wl_quantize([-100;100],N,fs,0);check('ADC_signed_rails',max(abs(y-[-fs;fs-lsb])),eps);
% Original row-wise RLS versus independent regularized batch least squares.
H=randn(400,4);truth=[.9;.03;-.02;1.02];obs=H*truth+1e-6*randn(400,1);
[theta,P]=wl_legacy('rls',zeros(4,1),1e6*eye(4),H,obs,1);
batch=(H.'*H+1e-6*eye(4))\(H.'*obs);
check('legacy_RLS_vs_batch_LS',norm(theta-batch),1e-9);
check('legacy_RLS_covariance_symmetry',norm(P-P.'),1e-10);
% Original Joseph parameter-KF observes four independent harmonic coefficients.
theta=zeros(4,1);P=eye(4);truth=[.001;-.002;.006;-.003];
for k=1:600
 a=2*pi*k/137;H=[cos(a) sin(a) 0 0;0 0 sin(a) -cos(a)];
 [theta,P]=wl_legacy('parameter_kf',theta,P,H,H*truth,0,1e-8);
end
check('parameter_KF_known_coefficients',norm(theta-truth),1e-6);
check('parameter_KF_PSD_violation',max(0,-min(eig(P))),1e-12);
% Legacy angle/rate Kalman: noisy measured angle only, no truth input.
st=wl_algorithm_init(c);st.kalmanState=[0;0];count=4000;t=(0:count-1)'*c.head.Ts;
rate=-c.head.bryan*80*pi/180;angle=rate*t;
measured=angle+p.kalman.measurementNoiseDeg*pi/180*randn(count,1);
estimated=zeros(count,1);
for k=1:count,[st,~]=wl_legacy('kalman',st,measured(k),true,p,c.head.Ts);estimated(k)=st.kalmanState(2);end
raw=diff(measured)/c.head.Ts;sel=t>.5;
ratio=std(estimated(sel)-rate)/std(raw(501:end)-rate);
check('Kalman_rate_noise_ratio',ratio,.3);
% FRP: independent synthetic fixture, full rank; freeze on held-out trajectories.
p.frp.enable=true;p.frp.identificationEnable=true;p.frp.applyFrozenCompensation=false;
p.frp.rlsLambda=1;p.frp.maxConditionNumber=1e10;
st=wl_algorithm_init(c);truth=[.02;.01;-.015;.005;.007;.002;.003;-.004;.005]*pi/180;
Phi=zeros(6000,9);observations=zeros(6000,1);
for k=1:6000
 a=2*pi*mod(k,997)/997;T=25+8*sin(.013*k);scan=40*pi/180*(1+.3*sin(.017*k))*sign(sin(.031*k));
 phi=HRG_WA_v46_frp_basis(a,T,scan,p);obs=phi*truth+1e-6*randn;
 Phi(k,:)=phi;observations(k)=obs;
 [st,~]=wl_legacy('frp',st,p,a,T,scan,obs,true,true,true,true,sign(scan));
end
used=1:max(round(p.frp.updateDecimation),1):size(Phi,1);
batch=(Phi(used,:).'*Phi(used,:)+eye(9)/p.frp.rlsDelta)\(Phi(used,:).'*observations(used));
check('FRP_RLS_vs_independent_batch',norm(st.frpThetaHat-batch),1e-8);
before=st.frpThetaHat;p.frp.identificationEnable=false;p.frp.applyFrozenCompensation=true;
err0=[];err1=[];
for k=1:1500
 a=2*pi*k/391;T=28+3*cos(.021*k);scan=.3*sin(.043*k);
 phi=HRG_WA_v46_frp_basis(a,T,scan,p);bias=phi*truth;
 [st,corr]=wl_legacy('frp',st,p,a,T,scan,45*pi/180+bias,false,true,false,true,0);
 err0(end+1)=bias;err1(end+1)=bias+corr; %#ok<AGROW>
end
check('FRP_frozen_weights_changed',norm(st.frpThetaHat-before),0);
check('FRP_heldout_residual_ratio',rms(err1)/rms(err0),.35);
% The adapter must refuse zero-rate training without an external fixture permit.
c.frp=true;c.frpSequence=true;c=wl_setup(c);st=wl_algorithm_init(c);
for k=1:500
 a=.02*k;iq=[cos(2*a);sin(2*a);0;0];
 [st,~]=wl_algorithm_tick(k*c.head.Ts,iq,25,0,false,zeros(3,1),st,c,false);
end
check('FRP_updates_without_fixture_permission',st.frpUpdateCount,0);
% Invalid ADC status must freeze both navigation and controller measurements.
[st,y]=wl_algorithm_tick(1,[1;0;0;0],25,0,false,zeros(3,1),st,c,true);
check('overrange_control_validity_not_zero',abs(y(5))+abs(y(7))+abs(y(8))+abs(y(13)),0);
result=struct('pass',all([checks.pass]),'checks',checks,'scope', ...
 'Independent synthetic/primitive validation. Does not certify physical online identifiability from ordinary WA data.');
wl_write_json(fullfile(root,'evidence','algorithm_scoreboards.json'),result);
assert(result.pass,'Algorithm adapter scoreboard failed');
fprintf('PASS %d algorithm and safety scoreboards.\n',numel(checks));
    function check(name,value,limit)
        ok=isfinite(value)&&value<=limit;checks(end+1)=struct('name',name,'value',value,'limit',limit,'pass',ok);
        fprintf('%s %.9g <= %.9g : %d\n',name,value,limit,ok);
    end
end
