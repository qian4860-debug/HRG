function wz_navigation_sfun(b)
b.NumDialogPrms=1;b.NumInputPorts=3;b.NumOutputPorts=1;
dims=[4 1 1];
for k=1:3,b.InputPort(k).Dimensions=dims(k);b.InputPort(k).DirectFeedthrough=true;end
b.OutputPort(1).Dimensions=4;b.SampleTimes=[b.DialogPrm(1).Data.head.Ts 0];
b.SimStateCompliance='DefaultSimState';
b.RegBlockMethod('PostPropagationSetup',@post);b.RegBlockMethod('InitializeConditions',@init);
b.RegBlockMethod('Outputs',@outputs);b.RegBlockMethod('Update',@update);
end
function post(b)
b.NumDworks=1;b.Dwork(1).Name='GeometricNavigation';b.Dwork(1).Dimensions=10;
b.Dwork(1).DatatypeID=0;b.Dwork(1).Complexity='Real';b.Dwork(1).UsedAsDiscState=true;
end
function init(b)
s=zeros(10,1);s(7)=-1;b.Dwork(1).Data=s;
end
function [s,y]=advance(b)
[s,y]=wz_navigation_tick(b.CurrentTime,b.InputPort(1).Data,b.InputPort(2).Data,b.InputPort(3).Data,b.Dwork(1).Data,b.DialogPrm(1).Data);
end
function outputs(b)
[~,y]=advance(b);b.OutputPort(1).Data=y;
end
function update(b)
[s,~]=advance(b);b.Dwork(1).Data=s;
end
