function p10e_sfun(b)
b.NumDialogPrms=1;b.NumInputPorts=1;b.NumOutputPorts=2;b.InputPort(1).Dimensions=2;b.InputPort(1).DirectFeedthrough=false;
b.OutputPort(1).Dimensions=2;b.OutputPort(2).Dimensions=7;p=b.DialogPrm(1).Data;b.SampleTimes=[p.Ts 0];
b.RegBlockMethod('PostPropagationSetup',@alloc);b.RegBlockMethod('InitializeConditions',@init);b.RegBlockMethod('Outputs',@outputs);b.RegBlockMethod('Update',@update);
end
function alloc(b)
b.NumDworks=1;b.Dwork(1).Name='controller';b.Dwork(1).Dimensions=17;b.Dwork(1).DatatypeID=0;b.Dwork(1).Complexity='Real';b.Dwork(1).UsedAsDiscState=true;
end
function s=unpack(x)
s=struct('phase',x(1),'freq',x(2),'sumI',x(3:4),'sumQ',x(5:6),'count',x(7),'Vc',x(8:9),'Vs',x(10:11),'integ',x(12),'I',x(13:14),'Q',x(15:16),'sat',x(17));
end
function x=pack(s)
x=[s.phase;s.freq;s.sumI;s.sumQ;s.count;s.Vc;s.Vs;s.integ;s.I;s.Q;s.sat];
end
function init(b)
p=b.DialogPrm(1).Data;[s,~,~]=p10e_tick([],zeros(2,1),p,1);s.phase=0;s.count=0;s.sumI(:)=0;s.sumQ(:)=0;b.Dwork(1).Data=pack(s);
end
function outputs(b)
p=b.DialogPrm(1).Data;[~,u,d]=p10e_tick(unpack(b.Dwork(1).Data),zeros(2,1),p,1);b.OutputPort(1).Data=u;b.OutputPort(2).Data=d;
end
function update(b)
persistent last H
p=b.DialogPrm(1).Data;if isempty(last)||~isequal(last,p),[~,~,~,H]=p10e_plant(p);last=p;end
[s,~,~]=p10e_tick(unpack(b.Dwork(1).Data),b.InputPort(1).Data,p,H);b.Dwork(1).Data=pack(s);
end
