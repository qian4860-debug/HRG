function m=wl_acceptance_metrics(out,c,b)
% One external scoreboard for the eight metric families. Never feeds plant truth back.
if nargin<3,b=wl_acceptance_budget(c);end
nav=out.tap_navigation;t=nav.Time(:);n=nav.Data;
assert(size(n,2)>=4 && all(diff(t)>0),'Navigation must have ordered samples');
m.schemaVersion=1;m.budget=b;m.windowStartS=b.steadyStartS;
m.recordDurationS=t(end)-t(1);m.angleConvention='physical rim theta; modal azimuth=2theta; atan2 phase=4theta';
steady=t>=b.steadyStartS;valid=n(:,3)>.5;sel=steady&valid;
m.validFraction=mean(valid(steady));m.steadySamples=sum(sel);
m.finite=all(isfinite(n(:)));
% Analytic commanded angle, independent of navigation, with no fitted drift.
w=2*pi*c.inputFrequencyHz;
truth=c.inputRate*t;
if w~=0,truth=truth+c.inputRateAmplitude/w*(1-cos(w*t));end
truthRate=c.inputRate+c.inputRateAmplitude*sin(w*t);
anchor=find(valid,1);if isempty(anchor),anchor=1;end
errAngle=(n(:,1)-n(anchor,1))-(truth-truth(anchor));
m.angle=struct('referenceEpochS',t(anchor),'reference','first valid sample; initial absolute azimuth unobservable', ...
 'rmsDeg',rms0(errAngle(sel))*180/pi,'peakDeg',peak0(errAngle(sel))*180/pi, ...
 'endpointDeg',NaN);
% Also expose steady-anchored drift, separately from total accumulated error.
first=find(sel,1);last=find(sel,1,'last');m.angle.steadyIncrementPeakDeg=NaN;
if ~isempty(first),m.angle.steadyIncrementPeakDeg=peak0(errAngle(sel)-errAngle(first))*180/pi;m.angle.endpointDeg=errAngle(last)*180/pi;end
er=n(sel,2)-truthRate(sel);m.rate=struct('meanErrorDegS',mean(er)*180/pi, ...
 'residualStdDegS',std(er,1)*180/pi,'rmsErrorDegS',rms0(er)*180/pi, ...
 'noiseStatus','Tracking residual includes deterministic drift; use paired_noise for stochastic increment');
m.zeroBias=struct('status','not_a_zero_input_run','shortRunMeanDegS',NaN, ...
 'biasInstabilityStatus','not_assessed; requires long zero-rate records and Allan analysis');
if c.inputRate==0 && c.inputRateAmplitude==0
 m.zeroBias.status='short_run_zero_input_mean_only';m.zeroBias.shortRunMeanDegS=mean(n(sel,2))*180/pi;
end
iq=out.tap_iq;ti=iq.Time(:);d=iq.Data(:,1:2)+1i*iq.Data(:,3:4);
E=sum(abs(d).^2,2);Qq=2*imag(conj(d(:,1)).*d(:,2));
R=abs(d(:,1)).^2-abs(d(:,2)).^2;S=2*real(conj(d(:,1)).*d(:,2));
ok=E>c.head.energyThreshold & hypot(R,S)>c.head.angleThreshold;
si=ti>=b.steadyStartS & ok;
ratio=max(-1,min(1,Qq./max(E,eps)));
% Q/E=2r/(1+r^2), r=signed minor/major, using the |r|<=1 branch.
minorRatio=ratio./(1+sqrt(max(0,1-ratio.^2)));
m.energy=struct('relativeRms',rms0(E(si)/c.head.energyTarget-1), ...
 'relativeMean',mean(E(si)/c.head.energyTarget-1));
m.quadrature=struct('invariantRatioRms',rms0(ratio(si)), ...
 'minorMajorRatioRms',rms0(minorRatio(si)),'signConvention','project complex envelope convention');
phase=.5*angle(sum(d.^2,2));
m.lock=struct('phaseRmsRad',rms0(phase(si)),'phasePeakRad',peak0(phase(si)), ...
 'definition','calibrated observed IQ phase modulo pi; not independent proof of physical resonance lock');
% Actual mechanical energy avoids the demodulator/filter fill-up transient.
q=out.tap_head_displacement;v=out.tap_head_velocity;
assert(isequal(q.Time,v.Time),'Mechanical q/v logs must share native timestamps');
Et=sum(q.Data.^2+(v.Data/(2*pi*c.head.f0)).^2,2);
m.energy.mechanicalRelativeRms=rms0(Et(q.Time>=b.steadyStartS)/c.head.energyTarget-1);
if any(strcmp(who(out),'tap_accept_nco_phase'))
 % Independent mechanical carrier phase relative to NCO, not an IQ re-expression.
 tn=t(sel);qq=interp1(q.Time,q.Data,tn);vv=interp1(v.Time,v.Data,tn);
 z=qq-1i*vv/(2*pi*c.head.f0);pn=out.tap_accept_nco_phase;
 nco=interp1(pn.Time,pn.Data,tn);
 residual=.5*unwrap(angle(sum(z.^2,2).*exp(-2i*nco)));
 m.lock.physicalPhaseExcursionRad=peak0(residual-mean(residual));
 if numel(tn)>1,m.lock.physicalMeanFrequencyErrorHz=(residual(end)-residual(1))/(2*pi*(tn(end)-tn(1)));else,m.lock.physicalMeanFrequencyErrorHz=NaN;end
 m.lock.physicalReference='q-j*v/omega0 carrier phasor vs logged NCO; slow-envelope approximation; no fitted phase slope';
else
 m.lock.physicalReference='not_logged';
end
m.build=struct('status','not_assessed_precharged','timeS',NaN,'holdS',b.holdS,'relativeBand',b.buildTolerance);
if c.head.initialEnergy<c.head.energyTarget*(1-b.buildTolerance)
 inBand=abs(Et/c.head.energyTarget-1)<=b.buildTolerance;
 dt=median(diff(q.Time));required=ceil(b.holdS/dt)+1;
 cs=[0;cumsum(double(inBand))];
 if required>numel(inBand),ends=[];else,ends=find(cs(required+1:end)-cs(1:end-required)>=required-.5,1);end
 if isempty(ends),m.build.status='not_reached';else,m.build.status='reached_from_seed';m.build.timeS=q.Time(ends);end
 if c.head.initialEnergy==0,m.build.status=['zero_energy_start_' m.build.status];end
end
% Pre-limit requests are observed where available, to expose hidden overload.
names=who(out);rails=struct('name',{},'limit',{},'peakRequest',{},'headroomFraction',{},'overrangeFraction',{});
addrail('ADC',out.tap_sample_hold.Data,c.adcFsV);
addrail('DAC',out.tap_dac_requested.Data,c.dacFsV);
if ismember('tap_accept_afe_request',names),addrail('AFE',out.tap_accept_afe_request.Data,c.afeLimitV);else,addrail('AFE_post_limit_only',out.tap_pga.Data,c.afeLimitV);end
if ismember('tap_accept_driver_request',names),addrail('driver',out.tap_accept_driver_request.Data,c.driverLimitV);else,addrail('driver_post_limit_only',out.tap_driver.Data,c.driverLimitV);end
cmd=out.tap_control_commands.Data;lims=[c.head.energyLimit c.head.quadLimit c.head.pllLimitHz];
for j=1:3,addrail(sprintf('PI%d_output',j),cmd(:,j),lims(j));end
m.saturation=struct('rails',rails,'minimumHeadroomFraction',min([rails.headroomFraction]), ...
 'fullRecord',true,'note','PI values are limited outputs; occupancy at limit is included. Other branches use pre-limit requests.');
% Any corrupt observation must fail, even if the navigation output stayed finite.
for k=1:numel(names)
 if startsWith(names{k},'tap_'),x=out.(names{k}).Data;m.finite=m.finite&&all(isfinite(x(:)));end
end
m.checks=struct('validCoverage',m.validFraction>=b.validFraction,'energy',m.energy.relativeRms<=b.energyRelativeRms, ...
 'quadrature',m.quadrature.invariantRatioRms<=b.quadratureRatioRms,'observedLock',m.lock.phaseRmsRad<=b.lockPhaseRmsRad, ...
 'wholeAngle',m.angle.peakDeg<=b.anglePeakDeg,'rateResidual',m.rate.residualStdDegS<=b.rateResidualStdDegS, ...
 'headroom',m.saturation.minimumHeadroomFraction>=b.minimumHeadroomFraction);
if startsWith(m.build.status,'reached'),m.checks.build=m.build.timeS<=b.buildTimeS;
elseif ~strcmp(m.build.status,'not_assessed_precharged'),m.checks.build=false;end
if c.inputRate==0 && c.inputRateAmplitude==0,m.checks.shortRunZeroMean=abs(m.zeroBias.shortRunMeanDegS)<=b.shortRunZeroMeanDegS;end
m.assessment='functional_metrics_only';enough=m.steadySamples>=b.minSamples&&sum(si)>=b.minSamples;
if ~enough,m.assessment='insufficient_valid_samples';end
m.pass=m.finite&&enough&&all(structfun(@(x)logical(x),m.checks));
m.notAssessed={'bias instability','ARW','zero-energy startup FSM','transistor/PVT feasibility'};
 function addrail(name,x,limit)
  peak=max(abs(x(:)));rails(end+1)=struct('name',name,'limit',limit,'peakRequest',peak, ...
   'headroomFraction',1-peak/limit,'overrangeFraction',mean(abs(x(:))>=limit*(1-1e-12)));
 end
end
function y=rms0(x)
y=sqrt(mean(x.^2));
end
function y=peak0(x)
if isempty(x),y=NaN;else,y=max(abs(x));end
end
