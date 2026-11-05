function a4_adc_sfun(b)
b.NumDialogPrms=2;b.NumInputPorts=1;b.NumOutputPorts=1;
b.InputPort(1).Dimensions=14;b.InputPort(1).DirectFeedthrough=true;b.OutputPort(1).Dimensions=4;
p=b.DialogPrm(1).Data;b.SampleTimes=[p.Ts 0];
b.RegBlockMethod('PostPropagationSetup',@alloc);b.RegBlockMethod('InitializeConditions',@init);
b.RegBlockMethod('Outputs',@out);b.RegBlockMethod('Update',@update);
end
function alloc(b)
b.NumDworks=1;b.Dwork(1).Name='sample';b.Dwork(1).Dimensions=1;
b.Dwork(1).DatatypeID=0;b.Dwork(1).Complexity='Real';b.Dwork(1).UsedAsDiscState=true;
end
function init(b),b.Dwork(1).Data=0;end
function out(b)
p=b.DialogPrm(1).Data;z=b.DialogPrm(2).Data;k=min(size(z.noise,1),b.Dwork(1).Data+1);v=b.InputPort(1).Data;
[y,~,clip]=pcn_quantize(v(11:12)+z.noise(k,:)',p.adc_span,p.adc_bits);b.OutputPort(1).Data=[y;clip];
end
function update(b),b.Dwork(1).Data=b.Dwork(1).Data+1;end
