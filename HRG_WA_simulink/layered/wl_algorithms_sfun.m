function wl_algorithms_sfun(block)
% Discrete Level-2 library S-function. Numeric DWork holds all algorithm state.
setup(block);
end
function setup(b)
b.NumDialogPrms=1;b.NumInputPorts=6;b.NumOutputPorts=1;
dims=[4 1 1 1 3 1];
for k=1:6,b.InputPort(k).Dimensions=dims(k);b.InputPort(k).DirectFeedthrough=true;end
b.OutputPort(1).Dimensions=35;
b.SampleTimes=[b.DialogPrm(1).Data.head.Ts 0];b.SimStateCompliance='DefaultSimState';
b.RegBlockMethod('PostPropagationSetup',@post);b.RegBlockMethod('InitializeConditions',@init);
b.RegBlockMethod('Outputs',@outputs);b.RegBlockMethod('Update',@update);
end
function post(b)
c=b.DialogPrm(1).Data;s=wl_algorithm_init(c);[v,schema]=pack(s);
set_param(b.BlockHandle,'UserData',struct('template',s,'schema',{schema}));
b.NumDworks=1;b.Dwork(1).Name='AlgorithmState';b.Dwork(1).Dimensions=numel(v);
b.Dwork(1).DatatypeID=0;b.Dwork(1).Complexity='Real';b.Dwork(1).UsedAsDiscState=true;
end
function init(b)
s=wl_algorithm_init(b.DialogPrm(1).Data);[v,~]=pack(s);b.Dwork(1).Data=v;
end
function [s,y]=advance(b)
c=b.DialogPrm(1).Data;meta=get_param(b.BlockHandle,'UserData');s=meta.template;schema=meta.schema;v=b.Dwork(1).Data;
for k=1:numel(schema)
 f=schema{k};n=numel(s.(f));s.(f)=reshape(v(1:n),size(s.(f)));v(1:n)=[];
end
[s,y]=wl_algorithm_tick(b.CurrentTime,b.InputPort(1).Data,b.InputPort(2).Data, ...
 b.InputPort(3).Data,b.InputPort(4).Data,b.InputPort(5).Data,s,c,b.InputPort(6).Data);
end
function outputs(b)
[~,y]=advance(b);b.OutputPort(1).Data=y;
end
function update(b)
[s,~]=advance(b);[v,~]=pack(s);b.Dwork(1).Data=v;
end
function [v,names]=pack(s)
names=fieldnames(s);names=names(cellfun(@(f)isnumeric(s.(f))||islogical(s.(f)),names));
v=[];for k=1:numel(names),v=[v;double(s.(names{k})(:))];end %#ok<AGROW>
end
