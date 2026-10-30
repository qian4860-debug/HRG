function p=p101_apply_profile(p,path,independent)
% Intrinsic electrical fit is not an independent B or safe-operating rating.
if nargin<3,independent=struct;end;r=jsondecode(fileread(path));
assert(contains(r.boundary,'intrinsic')&&contains(r.boundary,'short-circuit'),...
 'p101:boundary','Profile must specify intrinsic short-circuit mechanical boundary');
e=r.parameters;assert(all([e.f0_Hz e.gamma_intrinsic_per_s e.Cs_F e.kappa e.b]>0));
p.f0=e.f0_Hz;p.gamma_intrinsic=e.gamma_intrinsic_per_s;p.Cs=e.Cs_F;p.G0=e.G0_S;
p.kappa=e.kappa;p.b=e.b;p.Cds=e.Cds_F;
p.B=[];p.Omega=0;
if isfield(independent,'B'),assert(isfinite(independent.B)&&independent.B>0);p.B=independent.B;end
if isfield(independent,'vmax'),assert(independent.vmax>0);p.vmax=independent.vmax;
elseif ~p.synthetic,error('p101:rating','An independently established voltage rating is required');end
end
