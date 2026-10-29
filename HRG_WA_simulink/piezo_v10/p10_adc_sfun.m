function p10_adc_sfun(b)
b.NumDialogPrms=1;b.NumInputPorts=1;b.NumOutputPorts=1;b.InputPort(1).Dimensions=2;
b.InputPort(1).DirectFeedthrough=true;b.OutputPort(1).Dimensions=2;
p=b.DialogPrm(1).Data;b.SampleTimes=[p.Ts 0];b.RegBlockMethod('Outputs',@out);
end
function out(b)
p=b.DialogPrm(1).Data;y=b.InputPort(1).Data;lsb=p.adc_span/2^p.adc_bits;
y=max(-p.adc_span/2,min(p.adc_span/2-lsb,y));b.OutputPort(1).Data=round(y/lsb)*lsb;
end
