function y=w7_mix(u,c)
% Only voltage, NCO phase and clock are inputs; mask tracks ADC data latency.
v=u(1:2);phase=u(3);t=u(4)-c.adcDelay/c.fsAdc;
g=w7_switches(t,c);
if strcmp(c.v7.tdmMode,'switched')
 % General finite-window least squares, NOT merely division by read duty.
 % Nominal mask Gram inverse also corrects non-whole-cycle blank windows.
 % NCO phase offset relative to the frame shifts the Gram matrix.
 phi=phase-2*pi*c.head.f0*u(4);rot=[cos(phi) -sin(phi);sin(phi) cos(phi)];
 G=rot'*c.v7.nominalGram*rot;
 coeff=G\[cos(phase);-sin(phase)];
else,coeff=2*[cos(phase);-sin(phase)];end
y=[v*coeff(1);v*coeff(2)]*g(4)/(c.biasV*c.c0F/c.gapM*c.displacementM/c.cfF*c.pgaGain);
end
