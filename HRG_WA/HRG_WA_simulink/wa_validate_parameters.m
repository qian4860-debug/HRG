function wa_validate_parameters(p)
assert(p.f0>0 && p.Q>.5 && p.bryan>0 && p.bryan<1, 'Invalid resonator parameters');
assert(p.gamma>=0 && abs(p.dgamma)<2*max(p.gamma,eps), 'Nonphysical damping');
assert(abs(p.splitHz)<.1*p.f0, 'Envelope model requires near-degenerate modes');
assert(all(size(p.detect)==[2 2]) && all(size(p.drive)==[2 2]), 'Matrices must be 2 by 2');
assert(all(isfinite(p.detect(:))) && all(isfinite(p.drive(:))), 'Nonfinite matrix');
assert(p.Ts>0 && p.duration>0 && p.fullStep>0, 'Invalid simulation timing');
assert(4*p.bryan*(abs(p.omega)+abs(p.virtualRate))*p.Ts < .8*pi, 'Angle unwrap sample-rate limit exceeded');
assert(p.iqBits==0 || (p.iqBits>=4 && p.iqBits<=32 && p.iqBits==fix(p.iqBits)), 'Invalid I/Q quantizer');
assert(p.initialEnergy>=0 && p.energyTarget>0 && abs(p.initialQuadRatio)<1, 'Invalid initial ellipse');
end
