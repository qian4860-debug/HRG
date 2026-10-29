function p=p10_apply_identified(profile_path,p,allowSynthetic)
% Explicit import; no overwrite of defaults or automatic SPI generation.
if nargin<3,allowSynthetic=false;end
r=jsondecode(fileread(profile_path));assert(strcmp(r.schema,'hrg_piezo_identification_v1'));
assert(allowSynthetic||~startsWith(r.status,'synthetic'),'Synthetic profile requires explicit opt-in');
assert(~isempty(r.physical),'Electrical-only identification cannot supply physical mass/limits');
f=r.physical;e=r.electrical;
assert(contains(r.reference_boundary,'short-circuit'),'Mechanical pole reference boundary must be deembedded first');
assert(e.leakage_S>=0&&e.leakage_S*p.Rs<.01,'Leakage is not negligible: extend V10 sensor circuit before importing');
assert(all([f.mass_kg,f.theta_s_C_per_m,e.f0_Hz,e.Q,e.Cs_F]>0));
p.mass=f.mass_kg;p.theta_s=f.theta_s_C_per_m;p.theta_d=f.theta_d_N_per_V;
p.f0=e.f0_Hz;p.Q=e.Q;p.Cs=e.Cs_F;p.Cds=e.Cds_F;
% B, amplitude target, operating limits and AFE calibration are NOT inferred.
assert(~isempty(r.bryan_factor)&&~isempty(r.drive_voltage_limit_V)&&~isempty(r.displacement_limit_m),...
 'B and operating voltage/displacement limits must be supplied independently');
p.B=r.bryan_factor;p.vmax=r.drive_voltage_limit_V;
assert(isfinite(p.B)&&abs(p.B)>0&&isfinite(p.vmax)&&p.vmax>0&&r.displacement_limit_m>0);
assert(p.amp<=r.displacement_limit_m,'Amplitude exceeds independently supplied displacement limit');
p.synthetic=startsWith(r.status,'synthetic');
end
