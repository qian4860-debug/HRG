function comp_sfun(b)
% Simulink二级S函数适配层，执行内核在comp_tick中。
% DWork保存35维控制状态；Outputs不消费新ADC，Update才提交新状态。
% 此安排保证输入不直接贯通到输出，窗口发布时刻为end+Ts。
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
function init(b),b.Dwork(1).Data=comp_state('init',b.DialogPrm(1).Data);end
function outputs(b)
[~,u,d]=comp_tick(comp_state('unpack',b.Dwork(1).Data),zeros(4,1),b.DialogPrm(1).Data,b.DialogPrm(2).Data);
b.OutputPort(1).Data=u;b.OutputPort(2).Data=d;
end
function update(b)
[s,~,~]=comp_tick(comp_state('unpack',b.Dwork(1).Data),b.InputPort(1).Data,b.DialogPrm(1).Data,b.DialogPrm(2).Data);
b.Dwork(1).Data=comp_state('pack',s);
end
