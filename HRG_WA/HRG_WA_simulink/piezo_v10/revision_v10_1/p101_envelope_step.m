function [next,voltage]=p101_envelope_step(C,p)
% Positive phasor q=Re{C exp(i*carrier_phase)}, Q=-imag(C).
% Normalized charge. First-order slow model, not a fast ADC/circuit replacement.
dt=p.envTs;[k1,voltage]=p101_envelope_rhs(C,p);k2=p101_envelope_rhs(C+dt*k1/2,p);k3=p101_envelope_rhs(C+dt*k2/2,p);k4=p101_envelope_rhs(C+dt*k3,p);
next=C+dt*(k1+2*k2+2*k3+k4)/6;
end
