function sn_quality_sfun(b)
% 无DWork的只读显示适配器；不影响Outputs/Update控制时序。
b.NumDialogPrms=1;b.NumInputPorts=1;b.NumOutputPorts=1;
b.InputPort(1).Dimensions=23;b.InputPort(1).DirectFeedthrough=true;b.OutputPort(1).Dimensions=11;
p=b.DialogPrm(1).Data;b.SampleTimes=[p.Ts 0];b.RegBlockMethod('Outputs',@outputs);
end
function outputs(b)
b.OutputPort(1).Data=quality_values(b.InputPort(1).Data,b.DialogPrm(1).Data);
end
