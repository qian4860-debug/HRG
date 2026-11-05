function a4_plant_sfun(b)
b.NumDialogPrms=2;b.NumInputPorts=1;b.NumOutputPorts=1;
b.InputPort(1).Dimensions=2;b.InputPort(1).DirectFeedthrough=false;b.OutputPort(1).Dimensions=14;
p=b.DialogPrm(1).Data;b.SampleTimes=[p.Ts 0];
b.RegBlockMethod('PostPropagationSetup',@alloc);b.RegBlockMethod('InitializeConditions',@init);
b.RegBlockMethod('Outputs',@out);b.RegBlockMethod('Update',@update);
end
function alloc(b)
b.NumDworks=1;b.Dwork(1).Name='plant';b.Dwork(1).Dimensions=14;
b.Dwork(1).DatatypeID=0;b.Dwork(1).Complexity='Real';b.Dwork(1).UsedAsDiscState=true;
end
function init(b)
z=b.DialogPrm(2).Data;b.Dwork(1).Data=[z.x0;0;0];
end
function out(b)
v=b.Dwork(1).Data;z=b.DialogPrm(2).Data;k=min(numel(z.segment),v(13)+1);j=z.segment(k);
b.OutputPort(1).Data=[v(1:12);z.omega(j);v(14)];
end
function update(b)
v=b.Dwork(1).Data;z=b.DialogPrm(2).Data;p=b.DialogPrm(1).Data;k=min(numel(z.segment),v(13)+1);j=z.segment(k);
b.Dwork(1).Data=[z.Ad(:,:,j)*v(1:12)+z.Bd(:,:,j)*b.InputPort(1).Data;v(13)+1;v(14)+z.omega(j)*p.Ts];
end
