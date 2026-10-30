function result=p101_verify_identification()
root=fileparts(mfilename('fullpath'));ev=fullfile(root,'evidence');
p=p101_apply_profile(p101_config,fullfile(ev,'identified_multiload_profile.json'));
check.unknown_B_not_invented=isempty(p.B)&&p.Omega==0;
p.drive_matrix=eye(2);p.detect_matrix=eye(2);p.split_hz=0;p.damping_half_difference=0;
errors=[];pole_errors=[];
for R=[3000 50000 200000]
 p.Rs=R;[~,~,~,A,B]=p101_plant(p);w0=2*pi*p.f0;
 % Charge and voltage have very different SI scales. Solve in dimensionless
 % state coordinates rather than hiding a near-singular raw-unit warning.
 scale=diag([p.charge_target*[1 1],w0*p.charge_target*[1 1],1 1,.001 .001,.1 .1,.1 .1]);
 As=scale\A*scale;Bs=scale\B;
 for f=linspace(999.63,1000.41,17)
  s=2i*pi*f;state=scale*((s*eye(12)-As)\Bs(:,1));
  D=s^2+2*p.gamma_intrinsic*s+w0^2;
  expected=(s*p.Cds*D-s*p.b)/((1/R+p.G0+s*p.Cs)*D+p.kappa*s);
  measured=state(7)/state(5);errors(end+1)=abs(measured-expected)/abs(expected);
 end
 eigFull=eig(A);em=eigFull(imag(eigFull)>w0*.9&imag(eigFull)<w0*1.1);
 local=[0 w0 0;-w0 -2*p.gamma_intrinsic p.kappa/(p.Cs*w0);0 -w0 -(1/R+p.G0)/p.Cs];
 e=eig(local);e=e(imag(e)>0);pole_errors(end+1)=min(abs(em-e));
end
check.multiload_state_transfer_replay=max(errors)<1e-6;
check.loaded_ringdown_poles_replay=max(pole_errors)<1e-6;
bad=jsondecode(fileread(fullfile(ev,'identified_multiload_profile.json')));bad.boundary='loaded ringdown damping';
temp=fullfile(ev,'rejected_profile_fixture.json');p101_json(temp,bad);
try,p101_apply_profile(p,temp);check.loaded_boundary_rejected=false;
catch err,check.loaded_boundary_rejected=strcmp(err.identifier,'p101:boundary');end
result=struct('checks',check,'max_transfer_relative_error',max(errors),'max_loaded_pole_error',max(pole_errors),...
 'scope','State-space replay of independent multi-load fit, not a measured hardware profile');
p101_json(fullfile(ev,'matlab_identification_results.json'),result);assert(all(structfun(@logical,check)));disp(result);
end
