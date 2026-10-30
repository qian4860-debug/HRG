function p101_sfun(b)
b.NumDialogPrms=2;b.NumInputPorts=1;b.NumOutputPorts=2;
b.InputPort(1).Dimensions=4;b.InputPort(1).DirectFeedthrough=false;
b.OutputPort(1).Dimensions=2;b.OutputPort(2).Dimensions=18;
p=b.DialogPrm(1).Data;b.SampleTimes=[p.Ts 0];
b.RegBlockMethod('PostPropagationSetup',@alloc);b.RegBlockMethod('InitializeConditions',@init);
b.RegBlockMethod('Outputs',@outputs);b.RegBlockMethod('Update',@update);
end
function alloc(b)
b.NumDworks=1;b.Dwork(1).Name='controller';b.Dwork(1).Dimensions=35;
b.Dwork(1).DatatypeID=0;b.Dwork(1).Complexity='Real';b.Dwork(1).UsedAsDiscState=true;
end
function init(b),b.Dwork(1).Data=p101_state('init',b.DialogPrm(1).Data);end
function outputs(b)
[~,u,d]=p101_tick(p101_state('unpack',b.Dwork(1).Data),zeros(4,1),b.DialogPrm(1).Data,b.DialogPrm(2).Data);
b.OutputPort(1).Data=u;b.OutputPort(2).Data=d;
end
function update(b)
[s,~,~]=p101_tick(p101_state('unpack',b.Dwork(1).Data),b.InputPort(1).Data,b.DialogPrm(1).Data,b.DialogPrm(2).Data);
b.Dwork(1).Data=p101_state('pack',s);
end
