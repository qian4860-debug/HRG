function p101_adc_sfun(b)
b.NumDialogPrms=1;b.NumInputPorts=1;b.NumOutputPorts=1;
b.InputPort(1).Dimensions=2;b.InputPort(1).DirectFeedthrough=true;
b.OutputPort(1).Dimensions=4;p=b.DialogPrm(1).Data;b.SampleTimes=[p.Ts 0];
b.RegBlockMethod('Outputs',@outputs);
b.RegBlockMethod('PostPropagationSetup',@work);
b.RegBlockMethod('InitializeConditions',@initialize);
b.RegBlockMethod('Update',@update);
end
function work(b)
p=b.DialogPrm(1).Data;b.NumDworks=2;
b.Dwork(1).Name='NoiseFixture';b.Dwork(1).Dimensions=2*(round(p.duration/p.Ts)+1);
b.Dwork(2).Name='SampleIndex';b.Dwork(2).Dimensions=1;
for k=1:2,b.Dwork(k).DatatypeID=0;b.Dwork(k).Complexity='Real';b.Dwork(k).UsedAsDiscState=true;end
end
function initialize(b)
p=b.DialogPrm(1).Data;stream=RandStream('mt19937ar','Seed',p.noise_seed);
b.Dwork(1).Data=p.noise_rms_V*randn(stream,b.Dwork(1).Dimensions,1);b.Dwork(2).Data=1;
end
function outputs(b)
p=b.DialogPrm(1).Data;k=b.Dwork(2).Data;
noise=b.Dwork(1).Data(2*k-1:2*k);
[v,~,clip]=p101_quantize(b.InputPort(1).Data+noise,p.adc_span,p.adc_bits);
b.OutputPort(1).Data=[v;clip];
end
function update(b)
b.Dwork(2).Data=min(b.Dwork(2).Data+1,b.Dwork(1).Dimensions/2);
end
