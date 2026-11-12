function models = h68_build(outDir, models, configs, inspect)
% 生成三份 6800 Hz 原生 Simulink 模型，并把默认参数写入模型工作区。
% 只使用原生 Gain/Sum/Delay/Switch 等块，不生成 MATLAB Function 或 S-Function。
% Generate native Simulink diagrams and save their default model workspace.
arguments
    outDir (1,:) char = fullfile(fileparts(mfilename('fullpath')), 'models')
    models (1,:) cell = {'hrg_6800_continuous', 'hrg_6800_tdm_shared', 'hrg_6800_tdm_separate'}
    configs (1,:) cell = {}
    inspect (1,1) logical = false
end
if isempty(configs)
    modes = {'continuous','tdm_shared','tdm_separate'};
    configs = cellfun(@h68_config,modes,'UniformOutput',false);
end
assert(numel(models)==numel(configs),'Provide one configuration for each model name.');
if ~isfolder(outDir), mkdir(outDir); end
load_system('simulink');
for k = 1:numel(models)
    m = models{k};
    assert(~bdIsLoaded(m), 'Close %s before regenerating it.', m);
    new_system(m);
    cleanup = onCleanup(@() close_system(m,0));
    c = configs{k};
    assignin(get_param(m,'ModelWorkspace'),'c',c);
    set_param(m,'Solver','FixedStepDiscrete','SolverType','Fixed-step', ...
        'FixedStep','c.Ts','StopTime','c.duration','SaveTime','on', ...
        'TimeSaveName','tout','ReturnWorkspaceOutputs','on');

    s = group(m,'Timing',{}, {'Slot','Drive','Sense','Valid','Capture'}); timing(s);
    s = group(m,'Carrier',{}, {'Cos','Sin'}); carrier(s);
    s = group(m,'ADC sample alignment',{'Slot','Capture','Cos','Sin'}, {'Slot delayed','Capture delayed','Cos delayed','Sin delayed'}); alignment(s);
    s = group(m,'Converters',{'ADC input','Command','Drive','Valid','Cos','Sin'}, ...
        {'DAC','ADC','ADC clip','DAC clip'}); converters(s);
    plantName = 'Separate electrodes';
    if c.reuse, plantName = 'Shared electrode switch'; end
    plantOutputs = {'AFE','Motion','Sense electrode'};
    traceInputs = {'Slot','Drive','Sense','Valid','ADC','DAC','Frame pulse', ...
        'Estimate','Accept','Held angle','Angle valid','Motion','Sense electrode','ADC clip','Lost','DAC clip'};
    fiveElectrode = isfield(c,'groupVoltage');
    if fiveElectrode
        plantName = 'Four electrode groups and COM';
        plantOutputs{end+1} = 'Group terminal voltages';
        traceInputs{end+1} = 'Group terminal voltages';
    end
    s = group(m,plantName,{'DAC','Drive','Sense'},plantOutputs);
    plant(s,c,fiveElectrode,plantOutputs);
    s = group(m,'Coherent demodulation',{'ADC','ADC clip','Slot','Capture','Cos','Sin'}, ...
        {'Estimate','Frame usable','Azimuth','Energy'}); demod(s);
    s = group(m,'Amplitude and quadrature',{'Estimate','Energy','Capture','Accept'}, {'Command'}); control(s);
    s = group(m,'Whole angle',{'Azimuth','Usable','Capture'}, ...
        {'Accept','Frame pulse','Held angle','Angle valid','Lost'}); nav(s);
    s = group(m,'Trace',traceInputs,{});
    logging(s,fiveElectrode);
    a = 'Timing'; b = 'Carrier'; d = 'Converters'; q = 'Coherent demodulation';
    f = 'Amplitude and quadrature'; h = 'Whole angle'; g = 'Trace';
    wire(m,plantName,1,d,1); wire(m,f,1,d,2); wire(m,a,2,d,3); wire(m,a,4,d,4);
    wire(m,b,1,d,5); wire(m,b,2,d,6);
    wire(m,d,1,plantName,1); wire(m,a,2,plantName,2); wire(m,a,3,plantName,3);
    wire(m,a,1,'ADC sample alignment',1); wire(m,a,5,'ADC sample alignment',2);
    wire(m,b,1,'ADC sample alignment',3); wire(m,b,2,'ADC sample alignment',4);
    wire(m,d,2,q,1); wire(m,d,3,q,2); wire(m,'ADC sample alignment',1,q,3); wire(m,'ADC sample alignment',2,q,4);
    wire(m,'ADC sample alignment',3,q,5); wire(m,'ADC sample alignment',4,q,6);
    wire(m,q,1,f,1); wire(m,q,4,f,2); wire(m,'ADC sample alignment',2,f,3); wire(m,h,1,f,4);
    wire(m,q,3,h,1); wire(m,q,2,h,2); wire(m,'ADC sample alignment',2,h,3);
    for j = 1:4, wire(m,a,j,g,j); end
    wire(m,d,2,g,5); wire(m,d,1,g,6); wire(m,h,2,g,7); wire(m,q,1,g,8);
    wire(m,h,1,g,9); wire(m,h,3,g,10); wire(m,h,4,g,11);
    wire(m,plantName,2,g,12); wire(m,plantName,3,g,13); wire(m,d,3,g,14); wire(m,h,5,g,15); wire(m,d,4,g,16);
    if fiveElectrode
        line = add_line(m,[plantName '/4'],[g '/17'],'autorouting','on');
        set_param(line,'Name','A B C D relative to COM');
    end
    Simulink.BlockDiagram.arrangeSystem(m);
    description = ['6800 Hz / 50 mHz / Q=30000 / 600 pF. ' ...
        'THX2024 analog CV gain with matched channels; piezo adapter scale is assumed. ' ...
        'Native blocks only. See h68_config and evidence.'];
    if fiveElectrode
        description = ['6800 Hz whole-angle gyro. Four grouped terminals A/B/C/D relative to COM. ' ...
            'See five_config for signed routing and physical assumptions. ' ...
            'Native blocks only; trace columns 23:26 are the group terminal voltages.'];
    end
    set_param(m,'Description',description);
    % 检查版在同一原生图上添加旁路测量，行为模型的连接不变。
    if inspect, h68_instrument_model(m); end
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
seedClock = block(s,'Startup clock','Sources/Clock');
seedGate = logic(s,'Bounded startup enabled','AND',cmp(s,'Startup duration','<',seedClock,constant(s,'Startup seconds','c.p.seed_seconds')),constant(s,'Startup requested','c.p.seed_enabled'));
seed = sumblk(s,'Startup waveform','++',product(s,'Seed cosine',gain(s,'Seed I','[eye(2) zeros(2)]',constant(s,'Seed command','c.seedCommand')),'Cos'), ...
    product(s,'Seed sine',gain(s,'Seed Q','[zeros(2) eye(2)]',constant(s,'Seed command Q','c.seedCommand')),'Sin'));
raw = select(s,'Startup or feedback drive',seed,seedGate,raw);
heldDAC=unary(s,'DAC update clock and hold','Discrete/Zero-Order Hold',convert(s,'DAC quantizer',raw,'dac'),'SampleTime','c.Ts*c.p.dac_divisor');
dac = select(s,'DAC drive gate',heldDAC,'Drive',zero);
noiseState = delay(s,'ADC noise generator','[c.p.noise_seed;c.p.noise_seed+1]');
noiseNext = binary(s,'LCG modulo','Math Operations/Math Function',sumblk(s,'LCG increment','++', ...
    gain(s,'LCG multiplier','1664525',noiseState),constant(s,'LCG offset','1013904223')), ...
    constant(s,'LCG modulus','2^32'),'Operator','mod');
wire(s,noiseNext,1,noiseState,1);
noise = gain(s,'ADC noise RMS','sqrt(12)*c.p.adc_noise_rms',sumblk(s,'Centered uniform noise','+-', ...
    gain(s,'Uniform generator','1/2^32',noiseState),constant(s,'Noise midpoint','0.5')));
adcInput = sumblk(s,'ADC input and noise','++','ADC input',noise);
adcNow = select(s,'ADC valid gate',convert(s,'ADC quantizer',adcInput,'adc'),'Valid',zero);
adc = pipeline(s,'ADC pipeline data',adcNow,'0');
% Dot product reduces both per-channel flags to a scalar.
below = cmp(s,'ADC below range','<',adcInput,constant(s,'ADC lower','c.adcMin'));
above = cmp(s,'ADC above range','>',adcInput,constant(s,'ADC upper','c.adcMax'));
flags = logic(s,'Channel clips','OR',below,above);
flagCount = gain(s,'Reduce clip flags','[1 1]',cast(s,'Clip flags to double',flags));
clip = logic(s,'Valid sample clipped','AND','Valid',cmp(s,'Any channel clipped','>',flagCount,constant(s,'No clip','0')));
clip = pipeline(s,'ADC pipeline clip',cast(s,'Clip as data',clip),'0');
dacFlags = logic(s,'DAC over range','OR',cmp(s,'DAC low','<',raw,constant(s,'DAC min','c.dacMin')), ...
    cmp(s,'DAC high','>',raw,constant(s,'DAC max','c.dacMax')));
dacClip = logic(s,'Driven DAC clip','AND','Drive',cmp(s,'DAC any clip','>', ...
    gain(s,'DAC clip count','[1 1]',cast(s,'DAC flags as double',dacFlags)),constant(s,'DAC no clip','0')));
outputs(s,{'DAC','ADC','ADC clip','DAC clip'},dac,adc,clip,dacClip);
end

function y = convert(s,name,x,kind)
bounded = unary(s,[name ' input limit'],'Discontinuities/Saturation',x, ...
    'LowerLimit',['c.' kind 'Min'],'UpperLimit',['c.' kind 'Max']);
% Round the code directly to match MATLAB's ties-away-from-zero rule.
codes = gain(s,[name ' to codes'],['1/c.' kind 'Step'],bounded);
rounded = unary(s,name,'Math Operations/Rounding Function',codes,'Operator','round');
y = gain(s,[name ' volts'],['c.' kind 'Step'],rounded);
end

function plant(s,c,fiveElectrode,ports)
x = 'State vector';
statePorts = {'Mechanical charge and velocity','Driver voltage','Electrode residual voltage','Analog CV and anti-alias filter'};
stateRows = {'1:4','5:6','7:8','9:18'};
if fiveElectrode
    statePorts{3} = 'A B C D terminal voltages';
    stateRows = c.stateRows;
    if isfield(c,'readoutAnalogMismatch')
        statePorts{end+1} = 'Analog readout gain and pole';
    end
end
for z=1:numel(stateRows)
    q=group(s,statePorts{z},{'Next state'},{'State'});
    row=['c.x0(' stateRows{z} ')']; d=delay(q,'Physical memory',row); wire(q,'Next state',1,d,1); wire(q,d,1,'State',1);
end
mux(s,x,statePorts{:});
drive = sumblk(s,'Drive next state','++',gain(s,'Drive state matrix','c.Ad',x), ...
    gain(s,'Drive voltage matrix','c.Bd','DAC'));
if c.reuse
    bleedName = 'Electrode bleed and amplifier reset';
    if fiveElectrode, bleedName = 'Four groups bleed and filter decay'; end
    floating = gain(s,bleedName,'c.Af',x);
    sense = gain(s,'AFE load connected','c.As',x);
    idle = select(s,'Read or discharge',sense,'Sense',floating);
    next = select(s,'Physical drive or sense connection',drive,'Drive',idle);
else
    % DAC is already blanked. The dedicated read port stays loaded.
    next = drive;
    unary(s,'Drive timing observed','Sinks/Terminator','Drive');
    unary(s,'Sense timing observed','Sinks/Terminator','Sense');
end
for z=1:numel(stateRows)
    index=block(s,['State selection ' num2str(z)],'Signal Routing/Selector','NumberOfDimensions','1', ...
        'IndexOptionArray',{'Index vector (dialog)'},'Indices',stateRows{z}, ...
        'InputPortWidth',num2str(c.stateCount));
    wire(s,next,1,index,1); wire(s,index,1,statePorts{z},1);
end
filteredMap = 'c.pickoff/c.cvOutputGain';
if fiveElectrode, filteredMap = 'c.portCV/c.cvOutputGain'; end
filteredInput=gain(s,'Filtered equivalent CV input',filteredMap,x);
cvVoltage=gain(s,'THX2024 matched CV gain','c.cvOutputGain',filteredInput);
afe = cvVoltage;
if fiveElectrode
    afe = gain(s,'Group readout to X and Y','c.portSenseMap',cvVoltage);
    if isfield(c,'readoutAnalogMismatch')
        % 失配版 ADC 从附加模拟状态取样；保留半差节点用于对照。
        unary(s,'Readout before analog mismatch','Sinks/Terminator',afe);
        afe = gain(s,'ADC input after analog channel mismatch','c.pickoff',x);
    end
end
signals = {afe,gain(s,'Motional charge','c.motion',x), ...
    gain(s,'Electrode voltage','c.electrode',x)};
if fiveElectrode
    signals{end+1} = gain(s,'Four group voltages relative to COM','c.groupVoltage',x);
end
outputs(s,ports,signals{:});
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

function logging(s,fiveElectrode)
iq = delay(s,'Last accepted IQ','zeros(4,1)');
new = select(s,'Store valid IQ','Estimate','Accept',iq); wire(s,new,1,iq,1);
signals = {'Slot','Drive','Sense','Valid','ADC','DAC','Frame pulse',iq,'Held angle', ...
    'Angle valid','Motion','Sense electrode','ADC clip','Lost','DAC clip'};
for i = [2 3 4 10 13 15]
    signals{i} = cast(s,[signals{i} ' to trace'],signals{i});
end
if fiveElectrode
    signals{end+1} = 'Group terminal voltages';
end
trace = mux(s,'Trace vector',signals{:});
unary(s,'Export trace','Sinks/To Workspace',trace,'VariableName','trace','SaveFormat','Array','MaxDataPoints','inf','Decimation','c.logDecimation');
frames=group(s,'Frame records',{'Data'},{});
block(frames,'Enable','Ports & Subsystems/Enable');
unary(frames,'Export frames','Sinks/To Workspace','Data','VariableName','frames','SaveFormat','Array','MaxDataPoints','inf');
clock=block(s,'Record time','Sources/Clock');
stamped=mux(s,'Timestamped trace',clock,trace); wire(s,stamped,1,'Frame records',1); wire(s,'Frame pulse',1,'Frame records','Enable');
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
if isnumeric(dstPort), dstPort=num2str(dstPort); end
add_line(s,sprintf('%s/%d',src,srcPort),[dst '/' dstPort],'autorouting','on');
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

function alignment(s)
names={'Slot','Capture','Cos','Sin'}; dest={'Slot delayed','Capture delayed','Cos delayed','Sin delayed'};
for k=1:4
 initial='0'; if k==1, initial='-1'; end
 y=pipeline(s,['Timestamp alignment ' names{k}],names{k},initial); wire(s,y,1,dest{k},1);
end
end
function y=pipeline(s,name,input,initial)
y=unary(s,name,'Discrete/Delay',input,'DelayLength','c.adcLatency','InitialCondition',initial,'SampleTime','c.Ts');
end
