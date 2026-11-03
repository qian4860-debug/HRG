function a3_reference_sfun(block)
% Level-2 S函数保存13个DWork状态；Outputs不改状态，Update仅推进一次。
setup(block);
end
function setup(b)
b.NumDialogPrms=1;b.NumInputPorts=1;b.NumOutputPorts=1;
b.SetPreCompInpPortInfoToDynamic;b.SetPreCompOutPortInfoToDynamic;
b.InputPort(1).Dimensions=5;b.InputPort(1).DatatypeID=0;b.InputPort(1).Complexity='Real';b.InputPort(1).DirectFeedthrough=true;
b.OutputPort(1).Dimensions=9;b.OutputPort(1).DatatypeID=0;b.OutputPort(1).Complexity='Real';
p=b.DialogPrm(1).Data;b.SampleTimes=[p.frame_decimation/p.sample_rate_Hz 0];b.SimStateCompliance='DefaultSimState';
b.RegBlockMethod('PostPropagationSetup',@post);b.RegBlockMethod('InitializeConditions',@init);
b.RegBlockMethod('Outputs',@outputs);b.RegBlockMethod('Update',@update);
end
function post(b)
b.NumDworks=1;b.Dwork(1).Name='reference_state';b.Dwork(1).Dimensions=13;
b.Dwork(1).DatatypeID=0;b.Dwork(1).Complexity='Real';b.Dwork(1).UsedAsDiscState=true;
end
function init(b),b.Dwork(1).Data=zeros(13,1);end
function outputs(b)
[~,y]=a3_reference_step(b.Dwork(1).Data,b.InputPort(1).Data,b.DialogPrm(1).Data,true);b.OutputPort(1).Data=y;
end
function update(b)
[next,~]=a3_reference_step(b.Dwork(1).Data,b.InputPort(1).Data,b.DialogPrm(1).Data,true);b.Dwork(1).Data=next;
end
