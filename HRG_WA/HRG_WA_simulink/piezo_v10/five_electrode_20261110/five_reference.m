function [t, trace, frames, adcMonitor] = five_reference(c)
% Sample-by-sample MATLAB reference for the four groups plus COM.
% Trace columns 23:26 give A/B/C/D voltage relative to COM.
% Request the fourth output for pre-quantizer sensing samples (see h68_reference).
arguments
    c (1,1) struct = five_config()
end
assert(isfield(c,'groupVoltage'), 'Use a configuration from five_config.');
if nargout>=4
    [t,trace,frames,adcMonitor] = h68_reference(c);
else
    [t,trace,frames] = h68_reference(c);
end
end
