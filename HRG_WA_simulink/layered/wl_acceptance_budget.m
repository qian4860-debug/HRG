function b=wl_acceptance_budget(c)
% Illustrative functional allocations, NOT measured-head/product requirements.
b.steadyStartS=max(.05,c.duration/2);
b.holdS=.05;b.buildTolerance=.02;b.minSamples=20;
b.buildTimeS=4;b.energyRelativeRms=.05;b.quadratureRatioRms=.05;
b.lockPhaseRmsRad=.1;b.anglePeakDeg=.5;b.rateResidualStdDegS=.2;
b.shortRunZeroMeanDegS=.25;b.minimumHeadroomFraction=.05;
b.validFraction=.95;
b.status='Illustrative research allocations; replace with instrument requirements';
end
