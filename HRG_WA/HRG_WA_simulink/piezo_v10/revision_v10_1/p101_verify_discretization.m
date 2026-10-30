function result=p101_verify_discretization()
p=p101_config;p.Omega=.005;[Ad,Bd,~,A,B]=p101_plant(p);w=2*pi*p.f0;
q=p.charge_target;v=max(1e-6,w*q*p.Rs);S=diag([q q w*q w*q 1 1 v v q/p.Cf q/p.Cf q/p.Cf q/p.Cf 1 1]);
M=[A B;zeros(2,14)];N=S\M*S;
% Independent ODE integration of every basis vector, not another expm call.
opt=odeset('RelTol',2e-13,'AbsTol',2e-15);[~,y]=ode45(@(~,x)reshape(N*reshape(x,14,14),[],1),[0 p.Ts],reshape(eye(14),[],1),opt);
Eode=reshape(y(end,:),14,14);actual=S\[Ad Bd;zeros(2,12) eye(2)]*S;
raw=S\expm(M*p.Ts)*S;
err=max(abs(actual-Eode),[],'all');rawerr=max(abs(raw-Eode),[],'all');
checks=struct('dimensionless_ZOH_vs_ODE',err<1e-10,'raw_SI_regression_detected',rawerr>10*max(err,1e-14));
result=struct('checks',checks,'scaled_state_max_error',err,'raw_SI_scaled_error',rawerr,...
 'boundary','Charge and voltage SI scale imbalance; matrix-relative errors in raw units do not protect low-speed angle fidelity');
root=fileparts(mfilename('fullpath'));p101_json(fullfile(root,'evidence','discretization_results.json'),result);
disp(result);assert(all(structfun(@logical,checks)),'Discretization checks failed');
end
