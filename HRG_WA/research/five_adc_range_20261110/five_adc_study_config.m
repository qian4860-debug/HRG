function c = five_adc_study_config(omega, span, gain, slots, overrides)
% Experimental five-electrode TDM configuration. span is differential Vpp.
% slots is [bleed, settle] in carrier cycles. Drive and valid are one cycle
% each. The frame remains four cycles. See five_config for other options.
arguments
    omega (1,1) double {mustBeFinite} = .5
    span (1,1) double {mustBePositive,mustBeFinite} = 2
    gain (1,1) double {mustBePositive,mustBeFinite} = 1
    slots (1,2) double {mustBeNonnegative,mustBeFinite} = [.5 1]
    overrides (1,1) struct = struct()
end
overrides.adc_span = span;
c = five_config('tdm_shared',omega,overrides);
sampleSlots = round(slots*c.n);
assert(all(abs(slots*c.n-sampleSlots)<1e-10), ...
    'Bleed and settle must be integer converter clock counts.');
assert(all(sampleSlots>0),'Both bleed and settle must leave a positive guard.');
c.senseStart = c.driveEnd+sampleSlots(1);
c.validStart = c.senseStart+sampleSlots(2);
c.validEnd = c.validStart+c.n;
assert(c.validEnd+c.adcLatency<c.frame, ...
    'The valid window and publication must end before the next drive.');

% portSenseMap is the electrical combiner to the ADC. Include the extra
% post-combiner gain here so existing native SLX and MATLAB agree.
c.portSenseMap = gain*c.portSenseMap;
c.pickoff = c.portSenseMap*c.portCV;
c.detect = c.detect/gain;
c.gain_check.detector_V_per_normalized_charge = ...
    gain*c.gain_check.detector_V_per_normalized_charge;
c.adcStudyGain = gain;
end
