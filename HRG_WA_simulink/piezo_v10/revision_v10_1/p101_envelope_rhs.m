function [d,voltage]=p101_envelope_rhs(C,p)
R=@(t)[cos(t) -sin(t);sin(t) cos(t)];J=[0 -1;1 0];
G=R(p.damping_axis)*diag(p.gamma_intrinsic+[1 -1]*p.damping_half_difference)*R(p.damping_axis)';
H=R(p.stiffness_axis)*diag([-1 1]*pi*p.split_hz)*R(p.stiffness_axis)';
I=real(C);Q=-imag(C);amp=norm(C);e=I/max(norm(I),1e-8);w=J*e;
qperp=Q-e*(e'*Q);af=p.gamma_intrinsic*amp+p.env_amplitude_gain*(1-amp);
phase=p.env_phase_gain*(real(C)'*imag(C))/max(amp^2,1e-12);
force=af*e+amp*p.virtual_rate*w+1i*p.env_quad_gain*qperp;
d=-G*C-2*p.B*p.Omega*J*C+1i*H*C+force-1i*phase*C;
voltage=2*(2*pi*p.f0)*p.charge_target*norm(force)/p.b;
end
