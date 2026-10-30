function result=p101_verify_contracts()
p=p101_config;c=p101_calibration;check=struct;
bad=p;bad.Ts=p.Ts/2;check.changed_sample_time_requires_calibration=reject(bad,c,'p101:calibrationtime');
bad=p;bad.Tc=p.Tc+p.Ts/2;check.fractional_window_rejected=reject(bad,c,'p101:window');
bad=p;bad.B=[];check.unknown_B_motion_rejected=reject(bad,c,'p101:unknownB');
bad.Omega=0;p101_validate(bad,c);check.unknown_B_stationary_allowed=true;
bad=p;bad.damping_half_difference=2*p.gamma_intrinsic;check.active_damping_rejected=reject(bad,c,'p101:passivity');
bad=p;bad.Cs=-p.Cs;check.negative_capacitance_rejected=reject(bad,c,'p101:units');
result=struct('checks',check);root=fileparts(mfilename('fullpath'));
p101_json(fullfile(root,'evidence','contract_results.json'),result);
assert(all(structfun(@logical,check)),'Configuration contract failed');
end
function ok=reject(p,c,id)
try,p101_validate(p,c);ok=false;catch err,ok=strcmp(err.identifier,id);end
end
