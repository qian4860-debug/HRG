function models = tdm_build(outDir)
% Generate the two native Simulink block diagrams and save their default data.
arguments
    outDir (1,:) char = fullfile(fileparts(mfilename('fullpath')), 'models')
end
if ~isfolder(outDir), mkdir(outDir); end
load_system('simulink');
models = {'hrg_tdm_separate', 'hrg_tdm_shared'};
for k = 1:numel(models)
    m = models{k};
    assert(~bdIsLoaded(m), 'Close %s before regenerating it.', m);
    new_system(m);
    cleanup = onCleanup(@() close_system(m,0));
    c = tdm_config(k==2);
    assignin(get_param(m,'ModelWorkspace'),'c',c);
    set_param(m,'Solver','FixedStepDiscrete','SolverType','Fixed-step', ...
        'FixedStep','c.Ts','StopTime','c.duration','SaveTime','on', ...
        'TimeSaveName','tout','ReturnWorkspaceOutputs','on');

    s = group(m,'Timing',{}, {'Slot','Drive','Sense','Valid','Capture'}); timing(s);
    s = group(m,'Carrier',{}, {'Cos','Sin'}); carrier(s);
    s = group(m,'Converters',{'ADC input','Command','Drive','Valid','Cos','Sin'}, ...
        {'DAC','ADC','ADC clip'}); converters(s);
    plantName = 'Separate electrodes';
    if c.reuse, plantName = 'Shared electrode switch'; end
    s = group(m,plantName,{'DAC','Drive','Sense'}, {'AFE','Motion','Sense electrode'}); plant(s,c.reuse);
    s = group(m,'Coherent demodulation',{'ADC','ADC clip','Slot','Capture','Cos','Sin'}, ...
        {'Estimate','Frame usable','Azimuth','Energy'}); demod(s);
    s = group(m,'Amplitude and quadrature',{'Estimate','Energy','Capture','Accept'}, {'Command'}); control(s);
    s = group(m,'Whole angle',{'Azimuth','Usable','Capture'}, ...
        {'Accept','Frame pulse','Held angle','Angle valid','Lost'}); nav(s);
    s = group(m,'Trace',{'Slot','Drive','Sense','Valid','ADC','DAC','Frame pulse', ...
        'Estimate','Accept','Held angle','Angle valid','Motion','Sense electrode','ADC clip','Lost'}, {});
    logging(s);
    a = 'Timing'; b = 'Carrier'; d = 'Converters'; q = 'Coherent demodulation';
    f = 'Amplitude and quadrature'; h = 'Whole angle'; g = 'Trace';
    wire(m,plantName,1,d,1); wire(m,f,1,d,2); wire(m,a,2,d,3); wire(m,a,4,d,4);
    wire(m,b,1,d,5); wire(m,b,2,d,6);
    wire(m,d,1,plantName,1); wire(m,a,2,plantName,2); wire(m,a,3,plantName,3);
    wire(m,d,2,q,1); wire(m,d,3,q,2); wire(m,a,1,q,3); wire(m,a,5,q,4);
    wire(m,b,1,q,5); wire(m,b,2,q,6);
    wire(m,q,1,f,1); wire(m,q,4,f,2); wire(m,a,5,f,3); wire(m,h,1,f,4);
    wire(m,q,3,h,1); wire(m,q,2,h,2); wire(m,a,5,h,3);
    for j = 1:4, wire(m,a,j,g,j); end
    wire(m,d,2,g,5); wire(m,d,1,g,6); wire(m,h,2,g,7); wire(m,q,1,g,8);
    wire(m,h,1,g,9); wire(m,h,3,g,10); wire(m,h,4,g,11);
    wire(m,plantName,2,g,12); wire(m,plantName,3,g,13); wire(m,d,3,g,14); wire(m,h,5,g,15);
    Simulink.BlockDiagram.arrangeSystem(m);
    save_system(m,fullfile(outDir,[m '.slx']));
    clear cleanup
end
end

function timing(s)
zero = constant(s,'Zero','0');
one = constant(s,'One','1');
slot = delay(s,'Slot counter','0');
inc = sumblk(s,'Increment','++',slot,one);
wrap = cmp(s,'Frame boundary','>=',inc,constant(s,'Frame length','c.frame'));
next = select(s,'Modulo frame',zero,wrap,inc); wire(s,next,1,slot,1);
drive = cmp(s,'Drive contact','<',slot,constant(s,'Drive end','c.driveEnd'));
after = cmp(s,'Sense contact starts','>=',slot,constant(s,'Sense start','c.senseStart'));
before = cmp(s,'Sense contact ends','<',slot,constant(s,'Sense end','c.validEnd'));
sense = logic(s,'Sense contact','AND',after,before);
ready = cmp(s,'AFE settled','>=',slot,constant(s,'Valid start','c.validStart'));
valid = logic(s,'Valid ADC window','AND',sense,ready);
capture = cmp(s,'Last valid sample','==',slot,constant(s,'Last valid slot','c.validEnd-1'));
outputs(s,{'Slot','Drive','Sense','Valid','Capture'},slot,drive,sense,valid,capture);
end

function carrier(s)
cosine = block(s,'Cosine NCO','Sources/Sine Wave','Frequency','c.w','Phase','pi/2','SampleTime','c.Ts');
sine = block(s,'Sine NCO','Sources/Sine Wave','Frequency','c.w','Phase','0','SampleTime','c.Ts');
outputs(s,{'Cos','Sin'},cosine,sine);
end

function converters(s)
zero = constant(s,'Zero volts','zeros(2,1)');
cmdCos = gain(s,'DAC cosine coefficients','[eye(2) zeros(2)]','Command');
cmdSin = gain(s,'DAC sine coefficients','[zeros(2) eye(2)]','Command');
raw = sumblk(s,'Modulated DAC','++',product(s,'Cosine DAC',cmdCos,'Cos'),product(s,'Sine DAC',cmdSin,'Sin'));
dac = select(s,'DAC drive gate',convert(s,'DAC quantizer',raw,'dac'),'Drive',zero);
adc = select(s,'ADC valid gate',convert(s,'ADC quantizer','ADC input','adc'),'Valid',zero);
% Dot product reduces both per-channel flags to a scalar.
below = cmp(s,'ADC below range','<','ADC input',constant(s,'ADC lower','c.adcMin'));
above = cmp(s,'ADC above range','>','ADC input',constant(s,'ADC upper','c.adcMax'));
flags = logic(s,'Channel clips','OR',below,above);
flagCount = gain(s,'Reduce clip flags','[1 1]',cast(s,'Clip flags to double',flags));
clip = logic(s,'Valid sample clipped','AND','Valid',cmp(s,'Any channel clipped','>',flagCount,constant(s,'No clip','0')));
outputs(s,{'DAC','ADC','ADC clip'},dac,adc,clip);
end

function y = convert(s,name,x,kind)
bounded = unary(s,[name ' input limit'],'Discontinuities/Saturation',x, ...
    'LowerLimit',['c.' kind 'Min'],'UpperLimit',['c.' kind 'Max']);
% Round the code directly to match MATLAB's ties-away-from-zero rule.
codes = gain(s,[name ' to codes'],['1/c.' kind 'Step'],bounded);
rounded = unary(s,name,'Math Operations/Rounding Function',codes,'Operator','round');
y = gain(s,[name ' volts'],['c.' kind 'Step'],rounded);
end

function plant(s,reuse)
x = delay(s,'Piezo states','c.x0');
drive = sumblk(s,'Drive next state','++',gain(s,'Drive state matrix','c.Ad',x), ...
    gain(s,'Drive voltage matrix','c.Bd','DAC'));
if reuse
    floating = gain(s,'Electrode bleed and amplifier reset','c.Af',x);
    sense = gain(s,'AFE load connected','c.As',x);
    idle = select(s,'Read or discharge',sense,'Sense',floating);
    next = select(s,'Physical drive or sense connection',drive,'Drive',idle);
else
    % DAC is already blanked. The dedicated read port stays loaded.
    next = drive;
    unary(s,'Drive timing observed','Sinks/Terminator','Drive');
    unary(s,'Sense timing observed','Sinks/Terminator','Sense');
end
wire(s,next,1,x,1);
outputs(s,{'AFE','Motion','Sense electrode'},gain(s,'AFE voltage','c.pickoff',x), ...
    gain(s,'Motional charge','c.motion',x),gain(s,'Electrode voltage','c.electrode',x));
end

function demod(s)
zero = constant(s,'Zero','0');
reset = cmp(s,'Reset at frame start','==','Slot',zero);
acc = delay(s,'Window accumulator','zeros(4,1)');
prior = select(s,'Clear old window',constant(s,'Zero IQ','zeros(4,1)'),reset,acc);
mixed = mux(s,'Mixed IQ',product(s,'Cosine mixing','ADC','Cos'),product(s,'Sine mixing','ADC','Sin'));
accNext = sumblk(s,'Include current sample','++',prior,mixed); wire(s,accNext,1,acc,1);
clip = delay(s,'Window clipping history','0');
previousClip = select(s,'Clear old clip',zero,reset,clip);
clipNext = logic(s,'Clip in this window','OR',previousClip,'ADC clip');
wire(s,cast(s,'Remember window clip',clipNext),1,clip,1);
iq = gain(s,'IQ and channel calibration','2/c.n*c.detect',accNext);
I = gain(s,'I components','[eye(2) zeros(2)]',iq);
Q = gain(s,'Q components','[zeros(2) eye(2)]',iq);
modal = sumblk(s,'Modal powers','++',product(s,'I squared',I,I),product(s,'Q squared',Q,Q));
energy = gain(s,'Motional energy','[1 1]',modal);
N = gain(s,'Stokes N','[1 -1]',modal);
ix = gain(s,'Ix','[1 0]',I); iy = gain(s,'Iy','[0 1]',I);
qx = gain(s,'Qx','[1 0]',Q); qy = gain(s,'Qy','[0 1]',Q);
M = gain(s,'Stokes M','2',sumblk(s,'Cross modal terms','++',product(s,'IxIy',ix,iy),product(s,'QxQy',qx,qy)));
az = atan(s,'Four times standing wave angle',M,N);
radius = squareRoot(s,'Stokes radius',sumblk(s,'Radius squared','++',product(s,'N squared',N,N),product(s,'M squared',M,M)));
strong = cmp(s,'Energy above floor','>=',energy,constant(s,'Energy floor','c.minEnergy'));
line = cmp(s,'Standing wave resolvable','>=',radius,gain(s,'Linearity floor','c.minLinearity',energy));
usable = logic(s,'Valid fit','AND',strong,line,logic(s,'Unclipped','NOT',clipNext));
unary(s,'Capture timing observed','Sinks/Terminator','Capture');
outputs(s,{'Estimate','Frame usable','Azimuth','Energy'},iq,usable,az,energy);
end

function control(s)
I = gain(s,'In-phase vector','[eye(2) zeros(2)]','Estimate');
Q = gain(s,'Quadrature vector','[zeros(2) eye(2)]','Estimate');
diff = sumblk(s,'Temporal variance difference','+-',dotblk(s,'I energy',I,I),dotblk(s,'Q energy',Q,Q));
cross = gain(s,'Temporal covariance','2',dotblk(s,'I dot Q',I,Q));
phi = gain(s,'Tracked carrier phase','0.5',atan(s,'Principal temporal axis',cross,diff));
c = trig(s,'Tracked cosine','cos',phi);
d = trig(s,'Tracked sine','sin',phi);
major = sumblk(s,'Major ellipse vector','++',product(s,'I cos phase',I,c),product(s,'Q sin phase',Q,d));
minor = sumblk(s,'Minor ellipse vector','+-',product(s,'Q cos phase',Q,c),product(s,'I sin phase',I,d));
norm = squareRoot(s,'Major norm',dotblk(s,'Major energy',major,major));
floor = unary(s,'Norm floor','Discontinuities/Saturation',norm,'LowerLimit','1e-9','UpperLimit','inf');
e = binary(s,'Drive direction','Math Operations/Divide',major,floor);
err = sumblk(s,'Amplitude error','+-',constant(s,'Target amplitude','1'),squareRoot(s,'Amplitude','Energy'));
fr = sumblk(s,'Damping feedforward plus amplitude correction','++',constant(s,'Damping loss','c.gamma'),gain(s,'Amplitude gain','c.agc',err));
fs = gain(s,'Velocity force','-1',product(s,'Radial force',fr,e));
fc = gain(s,'Orthogonal displacement force','-c.quad',minor);
rc = sumblk(s,'Force cosine component','+-',product(s,'Fc cosine',fc,c),product(s,'Fs sine',fs,d));
rs = sumblk(s,'Force sine component','++',product(s,'Fc sine',fc,d),product(s,'Fs cosine',fs,c));
cmd = gain(s,'DAC phase and duty correction','c.forceScale*c.drive',mux(s,'Force coefficients',rc,rs));
held = delay(s,'Last DAC command','c.startCommand');
safe = select(s,'Invalid frame disables drive',cmd,'Accept',constant(s,'No drive','c.startCommand'));
next = select(s,'Hold to next drive window',safe,'Capture',held);
wire(s,next,1,held,1); outputs(s,{'Command'},held);
end

function nav(s)
seen = delay(s,'Reference acquired','0');
lost = delay(s,'Angle tracking lost','0');
last = delay(s,'Previous azimuth','0');
angle = delay(s,'Continuous body angle','0');
accept = logic(s,'Accept this frame','AND','Capture','Usable',logic(s,'Tracking available','NOT',lost));
frame = delay(s,'Frame published next sample','0');
wire(s,cast(s,'Frame pulse to state',accept),1,frame,1);
nextSeen = logic(s,'Keep reference','OR',seen,accept);
bad = logic(s,'Bad frame after anchor','AND',seen,'Capture',logic(s,'Unusable frame','NOT','Usable'));
nextLost = logic(s,'Latch lost state','OR',lost,bad);
wire(s,cast(s,'Store reference flag',nextSeen),1,seen,1); wire(s,cast(s,'Store lost flag',nextLost),1,lost,1);
newLast = select(s,'Keep last accepted azimuth','Azimuth',accept,last); wire(s,newLast,1,last,1);
delta = sumblk(s,'Unwrap increment','+-','Azimuth',last);
wrapped = atan(s,'Principal increment',trig(s,'Increment sine','sin',delta),trig(s,'Increment cosine','cos',delta));
nextAngle = sumblk(s,'Accumulate body angle','++',angle,gain(s,'Bryan scaling','-1/(4*c.B)',wrapped));
advance = logic(s,'Advance after first anchor','AND',accept,seen);
held = select(s,'Keep prior angle',nextAngle,advance,angle); wire(s,held,1,angle,1);
valid = logic(s,'Body angle valid','AND',seen,logic(s,'Reference not lost','NOT',lost));
outputs(s,{'Accept','Frame pulse','Held angle','Angle valid','Lost'},accept,frame,angle,valid,lost);
end

function logging(s)
iq = delay(s,'Last accepted IQ','zeros(4,1)');
new = select(s,'Store valid IQ','Estimate','Accept',iq); wire(s,new,1,iq,1);
signals = {'Slot','Drive','Sense','Valid','ADC','DAC','Frame pulse',iq,'Held angle', ...
    'Angle valid','Motion','Sense electrode','ADC clip','Lost'};
for i = [2 3 4 10 13]
    signals{i} = cast(s,[signals{i} ' to trace'],signals{i});
end
trace = mux(s,'Trace vector',signals{:});
unary(s,'Export trace','Sinks/To Workspace',trace,'VariableName','trace','SaveFormat','Array','MaxDataPoints','inf');
end

function s = group(parent,name,inNames,outNames)
s = [parent '/' name];
block(parent,name,'Ports & Subsystems/Subsystem');
Simulink.SubSystem.deleteContents(s);
for i = 1:numel(inNames), block(s,inNames{i},'Ports & Subsystems/In1','Port',num2str(i)); end
for i = 1:numel(outNames), block(s,outNames{i},'Ports & Subsystems/Out1','Port',num2str(i)); end
end

function name = block(s,name,path,varargin)
names = find_system(s,'SearchDepth',1,'Type','block');
i = numel(names);
x = 35+mod(i,7)*130; y = 35+floor(i/7)*65;
add_block(['simulink/' path],[s '/' name],'Position',[x y x+45 y+25],varargin{:});
end

function wire(s,src,srcPort,dst,dstPort)
add_line(s,sprintf('%s/%d',src,srcPort),sprintf('%s/%d',dst,dstPort),'autorouting','on');
end

function outputs(s,ports,varargin)
for i = 1:numel(ports), wire(s,varargin{i},1,ports{i},1); end
Simulink.BlockDiagram.arrangeSystem(s);
end

function y = connect(s,name,path,sources,varargin)
y = block(s,name,path,varargin{:});
for i = 1:numel(sources), wire(s,sources{i},1,y,i); end
end

function y = unary(s,name,path,x,varargin)
y = connect(s,name,path,{x},varargin{:});
end

function y = binary(s,name,path,x,z,varargin)
y = connect(s,name,path,{x,z},varargin{:});
end

function y = constant(s,name,value)
y = block(s,name,'Sources/Constant','Value',value);
end

function y = delay(s,name,init)
y = block(s,name,'Discrete/Unit Delay','InitialCondition',init,'SampleTime','c.Ts');
end

function y = select(s,name,yes,gate,no)
y = connect(s,name,'Signal Routing/Switch',{yes,gate,no},'Criteria','u2 ~= 0');
end

function y = cmp(s,name,op,x,z)
y = binary(s,name,'Logic and Bit Operations/Relational Operator',x,z,'Operator',op);
end

function y = logic(s,name,op,varargin)
y = connect(s,name,'Logic and Bit Operations/Logical Operator',varargin,'Operator',op,'Inputs',num2str(numel(varargin)));
end

function y = gain(s,name,k,x)
y = unary(s,name,'Math Operations/Gain',x,'Gain',k,'Multiplication','Matrix(K*u)');
end

function y = sumblk(s,name,signs,varargin)
y = connect(s,name,'Math Operations/Sum',varargin,'Inputs',signs);
end

function y = product(s,name,x,z)
y = binary(s,name,'Math Operations/Product',x,z);
end

function y = dotblk(s,name,x,z)
y = binary(s,name,'Math Operations/Dot Product',x,z);
end

function y = trig(s,name,op,x)
y = unary(s,name,'Math Operations/Trigonometric Function',x,'Operator',op);
end

function y = atan(s,name,x,z)
y = binary(s,name,'Math Operations/Trigonometric Function',x,z,'Operator','atan2');
end

function y = squareRoot(s,name,x)
y = unary(s,name,'Math Operations/Sqrt',x);
end

function y = mux(s,name,varargin)
y = connect(s,name,'Signal Routing/Mux',varargin,'Inputs',num2str(numel(varargin)));
end

function y = cast(s,name,x)
y = unary(s,name,'Signal Attributes/Data Type Conversion',x,'OutDataTypeStr','double');
end
