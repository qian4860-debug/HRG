function iq=w8_feedback_gate(u,c)
% Only measured IQ and simulation clock; no physical state or true rate input.
iq=u(1:4);if u(5)<c.v8.filterWarmupS,iq(:)=0;end
end
