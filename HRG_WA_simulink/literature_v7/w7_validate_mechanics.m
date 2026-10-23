function report=w7_validate_mechanics()
% Independent full carrier 4x4 matrix exponential; verifies actual RK4 runs.
checks=struct('fsPlant',{},'qError',{},'vOverOmegaError',{},'numericalDampingFraction',{});
for fs=[400000 800000]
 c=w7_config([],struct('startupEnable',false));c.fsPlant=fs;c.duration=.04;
 c.head.loopEnable=0;c.head.splitHz=0;c.head.dgamma=0;c.head.duffingHz=0;
 c.head.detuningHz=0;c.head.initialEnergy=1;c.noiseEnable=false;c.observers=false;c.spectra=false;
 c.name=sprintf('hrg_wa_v7_free_%d',fs);[out,c]=w7_sim(c,false);
 w=2*pi*c.head.f0;J=[0 -1;1 0];D=2*c.head.gamma*eye(2)+4*c.head.bryan*c.inputRate*J;
 A=[zeros(2) eye(2);-w*w*eye(2) -D];z=wa_initial(c.head);initial=[real(z);-w*imag(z)];
 expected=expm(A*c.duration)*initial;
 q=out.tap_head_displacement;v=out.tap_head_velocity;
 checks(end+1)=struct('fsPlant',fs,'qError',max(abs(q.Data(end,:)'-expected(1:2))), ...
  'vOverOmegaError',max(abs(v.Data(end,:)'/w-expected(3:4)/w)), ...
  'numericalDampingFraction',w7_budget(c).numericalDampingFraction); %#ok<AGROW>
 close_system(c.name,0);
end
ratio=checks(2).qError/checks(1).qError;
report=struct('cases',checks,'halfStepErrorRatio',ratio, ...
 'pass',checks(2).qError<1e-4&&checks(2).vOverOmegaError<1e-4&&ratio<.1, ...
 'scope','free linear carrier convergence only, not all nonlinear cases');
wl_write_json(fullfile(fileparts(mfilename('fullpath')),'evidence','mechanics_scoreboard.json'),report);
assert(report.pass,'Actual carrier convergence check failed');
end
