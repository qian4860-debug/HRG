function [t, trace, frames] = five_reference(c)
% Sample-by-sample MATLAB reference for the four groups plus COM.
% Trace columns 23:26 give A/B/C/D voltage relative to COM.
arguments
    c (1,1) struct = five_config()
end
assert(isfield(c,'groupVoltage'), 'Use a configuration from five_config.');
[t,trace,frames] = h68_reference(c);
end
