function report=w8_validate_zero_startup()
% Explicit actual zero mechanical state after adding filter/excitation warmup.
r=fileparts(mfilename('fullpath'));addpath(r);w8_config();
load_system(fullfile(r,'models','hrg_wa_v8_carrier_2.slx'));
c=getVariable(get_param('hrg_wa_v8_carrier_2','ModelWorkspace'),'v8_saved_configuration');
close_system('hrg_wa_v8_carrier_2',0);c=w8_setup(c);
c.name='hrg_wa_v8_zero_startup';c.head.initialEnergy=0;c.head.initialQuadRatio=0;
c.inputRate=0;c.inputRateAmplitude=0;c.duration=2;
c.maxLogPoints=ceil(c.duration*c.fsPlant)+1;c.observers=false;c.spectra=false;
name=w8_build(c,'carrier',false);w8_setup(c);out=sim(name);
b=wl_acceptance_budget(c);b.buildTolerance=.05;b.holdS=.05;
m=w7_metrics(out,c,b);q=out.tap_head_displacement;v=out.tap_head_velocity;
energy=sum(q.Data.^2+(v.Data/(2*pi*c.head.f0)).^2,2);
ix=1:round(c.fsPlant*c.head.Ts):numel(q.Time);
writematrix([q.Time(ix) energy(ix)],fullfile(r,'evidence','zero_startup_energy.csv'));
nav=out.tap_navigation;writematrix([nav.Time nav.Data],fullfile(r,'evidence','zero_startup_navigation.csv'));
close_system(name,0);
report=struct('date','2026-10-24','metrics',m,'pass',m.finite&&m.checks.build, ...
 'scope','Known nominal frequency, noise off, actual zero q/v; no wide-range search or ARW acceptance');
wl_write_json(fullfile(r,'evidence','zero_startup.json'),report);
assert(report.pass,'Zero-state startup failed; retain evidence');
end
