function p101_envelope_sfun(b)
b.NumDialogPrms=1;b.NumInputPorts=0;b.NumOutputPorts=1;b.OutputPort(1).Dimensions=6;b.OutputPort(1).SamplingMode='Sample';
p=b.DialogPrm(1).Data;b.SampleTimes=[p.envTs 0];
b.RegBlockMethod('PostPropagationSetup',@alloc);b.RegBlockMethod('InitializeConditions',@init);
b.RegBlockMethod('Outputs',@outputs);b.RegBlockMethod('Update',@update);
end
function alloc(b)
b.NumDworks=1;b.Dwork(1).Name='complex_envelope';b.Dwork(1).Dimensions=4;b.Dwork(1).DatatypeID=0;b.Dwork(1).Complexity='Real';b.Dwork(1).UsedAsDiscState=true;
end
function init(b)
p=b.DialogPrm(1).Data;b.Dwork(1).Data=[p.initial_fraction*[cos(p.theta0);sin(p.theta0)];0;0];
end
function outputs(b)
x=b.Dwork(1).Data;p=b.DialogPrm(1).Data;[~,v]=p101_envelope_rhs(x(1:2)+1i*x(3:4),p);
b.OutputPort(1).Data=[x(1:2);-x(3:4);p.virtual_rate;v];
end
function update(b)
x=b.Dwork(1).Data;p=b.DialogPrm(1).Data;x=p101_envelope_step(x(1:2)+1i*x(3:4),p);b.Dwork(1).Data=[real(x);imag(x)];
end
