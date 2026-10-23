function m=w7_metrics(out,c,b)
if nargin<3,b=wl_acceptance_budget(c);end
m=wl_acceptance_metrics(out,c,b);
% Historical scoreboard recognized only seeded-start prefixes. V7 must also
% recognize a REAL zero-state start; do not alter the sealed old scoreboard.
reached=ismember(m.build.status,{'reached_from_seed','zero_energy_start_reached_from_seed'});
if reached,m.checks.build=m.build.timeS<=b.buildTimeS;end
m.pass=m.finite&&m.steadySamples>=b.minSamples&&all(structfun(@logical,m.checks));
m.notAssessed={'ARW','long-term Allan bias instability','wide-range startup search', ...
 'all-temperature robustness','transistor/PVT feasibility','full physical-resonance signoff'};
end
