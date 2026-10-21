function m=wl_metrics(out,c)
% Oracle inputs are used only here, outside the closed-loop algorithm ports.
t=out.tap_navigation.Time;n=out.tap_navigation.Data;
cut=max(.05,.5*c.duration);idx=t>=cut & n(:,3)>.5;
expected=c.inputRate+c.inputRateAmplitude*sin(2*pi*c.inputFrequencyHz*t);
m.stage=c.stage;m.durationS=c.duration;m.validFraction=mean(n(:,3)>.5);
if any(idx)
 err=n(idx,2)-expected(idx);m.rateRmsErrorDegS=sqrt(mean(err.^2))*180/pi;
 m.rateStdErrorDegS=std(err)*180/pi;
 m.rateMeanErrorDegS=mean(err)*180/pi;m.ratePeakErrorDegS=max(abs(err))*180/pi;
else,m.rateRmsErrorDegS=inf;m.rateStdErrorDegS=inf;m.rateMeanErrorDegS=inf;m.ratePeakErrorDegS=inf;end
m.settleWindowStartS=cut;m.finite=all(isfinite(n(:)));
m.supplyAssumptionV=c.afeLimitV;m.adcBits=c.adcBits;m.dacBits=c.dacBits;
m.adcArchitecture=c.adcArchitecture;m.dacArchitecture=c.dacArchitecture;
if isprop(out,'tap_iq') || any(strcmp(who(out),'tap_iq'))
 iq=out.tap_iq.Data;ti=out.tap_iq.Time;sel=ti>=cut;
 E=sum(iq.^2,2);Q=2*(iq(:,1).*iq(:,4)-iq(:,2).*iq(:,3));
 m.energyMean=mean(E(sel));m.energyRippleRms=std(E(sel));m.quadratureRatioRms=sqrt(mean((Q(sel)./max(E(sel),eps)).^2));
end
if any(strcmp(who(out),'tap_adc'))
 a=out.tap_adc;b=out.tap_sample_hold;
 time=a.Time-c.adcDelay/c.fsAdc;sel=time>=max(cut,b.Time(1)) & time<=b.Time(end);
 ref=interp1(b.Time,b.Data,time(sel),'previous');error=a.Data(sel,:)-ref;
 m.adcErrorRmsV=sqrt(mean(error.^2,1));
 m.adcClipFraction=mean(abs(a.Data(:))>=c.adcFsV-2*c.adcFsV/max(2^c.adcBits,1));
 if c.adcBits==0,m.adcClipFraction=0;end
 if strcmp(c.adcArchitecture,'sigma_delta'),m.adcClipFraction=0;end
end
if any(strcmp(who(out),'tap_dac'))
 a=out.tap_dac;b=out.tap_dac_requested;
 time=a.Time-c.dacDelay/c.fsAdc;sel=time>=max(cut,b.Time(1)) & time<=b.Time(end);
 ref=interp1(b.Time,b.Data,time(sel),'previous');error=a.Data(sel,:)-ref;
 m.dacErrorRmsV=sqrt(mean(error.^2,1));
end
if any(strcmp(who(out),'tap_pga'))
 x=out.tap_pga.Data;m.afeClipFraction=mean(abs(x(:))>=c.afeLimitV);
end
if any(strcmp(who(out),'tap_driver'))
 x=out.tap_driver.Data;m.driverPeakV=max(abs(x(:)));m.driverClipFraction=mean(abs(x(:))>=c.driverLimitV);
end
if any(strcmp(who(out),'tap_algorithm_diagnostics'))
 d=out.tap_algorithm_diagnostics.Data;m.kalmanUpdates=d(end,3);m.kalmanRejects=d(end,4);
 m.onlineUpdates=d(end,5);m.frpUpdates=d(end,6);m.frpCoverage=d(end,7);m.frpConfidence=d(end,8);
end
m.note='Conditional on assumed head/circuit scales. Not device signoff; no ARW inferred from these short runs.';
end
