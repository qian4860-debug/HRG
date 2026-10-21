function p = wa_setup(p)
% Initialize only this project's workspace variables. No reference callbacks.
root=fileparts(mfilename('fullpath')); addpath(root);
if nargin<1, p=wa_parameters(); end
wa_validate_parameters(p);
assignin('base','wa_p',wa_pack(p));
z=wa_initial(p);
assignin('base','wa_z0',[real(z);imag(z)]);
assignin('base','wa_q0',[real(z);-2*pi*p.f0*imag(z)]);
assignin('base','wa_Ts',p.Ts);
assignin('base','wa_duration',p.duration);
assignin('base','wa_full_step',p.fullStep);
assignin('base','wa_input',[0 p.omega p.temperature p.virtualRate;p.duration p.omega p.temperature p.virtualRate]);
assignin('base','wa_full_input',[0 p.omega 0 p.temperature 0 0;p.duration p.omega 0 p.temperature 0 0]);
end
