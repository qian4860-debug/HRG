function a4_controller_sfun(b)
b.NumDialogPrms=2;b.NumInputPorts=1;b.NumOutputPorts=2;
b.InputPort(1).Dimensions=4;b.InputPort(1).DirectFeedthrough=false;
b.OutputPort(1).Dimensions=2;b.OutputPort(2).Dimensions=23;p=b.DialogPrm(1).Data;b.SampleTimes=[p.Ts 0];
b.RegBlockMethod('PostPropagationSetup',@alloc);b.RegBlockMethod('InitializeConditions',@init);
b.RegBlockMethod('Outputs',@out);b.RegBlockMethod('Update',@update);
end
function alloc(b)
b.NumDworks=1;b.Dwork(1).Name='controller';b.Dwork(1).Dimensions=165;
b.Dwork(1).DatatypeID=0;b.Dwork(1).Complexity='Real';b.Dwork(1).UsedAsDiscState=true;
end
function init(b),b.Dwork(1).Data=sn_state('init',b.DialogPrm(1).Data);end
function out(b)
s=sn_state('unpack',b.Dwork(1).Data);p=b.DialogPrm(1).Data;c=b.DialogPrm(2).Data;
b.OutputPort(1).Data=a4_drive(s,p,c);b.OutputPort(2).Data=a4_observe(s,p);
end
function update(b)
s=a4_control_tick(sn_state('unpack',b.Dwork(1).Data),b.InputPort(1).Data,b.DialogPrm(1).Data,b.DialogPrm(2).Data);
b.Dwork(1).Data=sn_state('pack',s);
end
