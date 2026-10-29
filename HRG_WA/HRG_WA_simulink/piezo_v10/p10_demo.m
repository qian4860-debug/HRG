function out=p10_demo
% Persistent observers: no close_system after simulation.
p=p10_config;mdl=p10_build(p);open_system(mdl);out=sim(mdl);
open_system([mdl '/Scope_Displacement_m']);open_system([mdl '/Scope_iq']);
open_system([mdl '/Scope_Driver_V']);open_system([mdl '/Spectrum_ADC']);
end
