function p101_adc_sfun(b)
b.NumDialogPrms=1;b.NumInputPorts=1;b.NumOutputPorts=1;
b.InputPort(1).Dimensions=2;b.InputPort(1).DirectFeedthrough=true;
b.OutputPort(1).Dimensions=4;p=b.DialogPrm(1).Data;b.SampleTimes=[p.Ts 0];
b.RegBlockMethod('Outputs',@outputs);
end
function outputs(b)
p=b.DialogPrm(1).Data;[v,~,clip]=p101_quantize(b.InputPort(1).Data,p.adc_span,p.adc_bits);
b.OutputPort(1).Data=[v;clip];
end
