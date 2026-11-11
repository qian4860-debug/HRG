function result = five_verify(modelDir, receiptPath)
% 五电极两版原生模型回归：
%   1) 拓扑/极性检查：四组+COM 的 H、驱动/检测映射必须秩 2；
%   2) 逐拍 parity：原生 Simulink 对独立 MATLAB 参考，含 DAC 整数分频；
%   3) 名义闭环：0/0.5/-4 rad/s 下的角增量 RMS 与归一化振幅；
%   4) 起振：从零机械状态施加有界启动激励，检查首次有效帧；
%   5) 故障：ADC 锁定前/后过载不得发布角度或使能反馈。
% 输出 verification.json。所有判据只针对行为级仿真，不是硬件验收。
arguments
    modelDir (1,:) char = fullfile(fileparts(mfilename('fullpath')),'models')
    receiptPath (1,:) char = fullfile(fileparts(mfilename('fullpath')),'verification.json')
end

modes = {'continuous','tdm_shared'};
result = struct('release',version('-release'), ...
    'scope','Behavioral model with nominal group symmetry and assumed circuit values', ...
    'status','running','topology',[],'parity',[],'nominal',[],'startup',[],'faults',[]);
heads = cell(size(modes));
for idx = 1:numel(modes)
    mode = modes{idx};
    model = ['hrg_5e_' mode];
    assert(~bdIsLoaded(model),'Close %s before verifying the saved model.',model);
    load_system(fullfile(modelDir,[model '.slx']));
    closeModel = onCleanup(@() close_system(model,0));

    blockCount = checkNative(model);
    c = getVariable(get_param(model,'ModelWorkspace'),'c');
    assert(strcmp(c.mode,mode) && strcmp(c.p.cv_mode,'thx2024'));
    heads{idx} = c.head;
    result.topology = [result.topology; checkPorts(c)]; %#ok<AGROW>

    % 逐拍 parity：同一组 ADC 码/开关状态/DAC 命令，原生块与 MATLAB
    % 参考必须逐列一致；分时版再加一组 DAC /25 整数分频。
    c = five_config(mode,.5,struct('duration',.006,'log_decimation',1));
    result.parity = [result.parity; checkParity(model,c,blockCount)]; %#ok<AGROW>
    if c.reuse
        c = five_config(mode,.5,struct('duration',.006,'log_decimation',1,'dac_divisor',25));
        result.parity = [result.parity; checkParity(model,c,blockCount)]; %#ok<AGROW>
    end

    % 名义闭环：每个速率跑 0.18 s，前 0.06 s 不计分；角度按首个
    % 有效帧锚定，避免把启动瞬态混进 RMS。
    for rate = [0 .5 -4]
        c = five_config(mode,rate,struct('duration',.18,'log_decimation',200));
        measurement = checkNominal(runModel(model,c),c,.06);
        result.nominal = [result.nominal; measurement]; %#ok<AGROW>
        fprintf('NOMINAL %s at %+.2f rad/s: %d frames, RMS %.6g rad\n', ...
            mode,rate,measurement.frames,measurement.body_rms_rad);
    end

    % 起振：从零机械状态给 0.5 s，前 0.35 s 允许捕获；首次有效帧
    % 必须早于 0.35 s，且稳态振幅回到 0.8–1.2。
    c = five_config(mode,.5,struct('duration',.5,'initial_fraction',0, ...
        'seed_enabled',true,'log_decimation',200));
    out = runModel(model,c);
    measurement = checkNominal(out,c,.35);
    assert(out.frames(1,1)<.35,'Startup did not acquire a valid angle.');
    measurement.first_valid_frame_s = out.frames(1,1);
    result.startup = [result.startup; measurement]; %#ok<AGROW>
    fprintf('STARTUP %s: first valid frame %.6g s, settled amplitude %.6g to %.6g\n', ...
        mode,measurement.first_valid_frame_s,measurement.minimum_amplitude,measurement.maximum_amplitude);

    % 故障：把 ADC 输入压到极小量程，锁定前/后过载都必须撤销发布
    % 和驱动；这里只验证数字安全行为，不模拟模拟前端的真实恢复。
    c = five_config(mode,.5,struct('duration',.006,'log_decimation',1));
    c.adcMin = -2*c.adcStep;
    c.adcMax = 2*c.adcStep;
    out = runModel(model,c);
    trace = out.trace;
    assert(any(trace(:,20)) && ~any(trace(:,[7:9 15]),'all'), ...
        'ADC overload must not publish angle or arm feedback.');
    result.faults = [result.faults; struct('mode',mode, ...
        'fault','ADC overload before acquisition','overflow_samples',nnz(trace(:,20)), ...
        'frames',nnz(trace(:,9)),'passed',true)]; %#ok<AGROW>

    c = five_config(mode,.5,struct('duration',.15,'initial_fraction',.3,'log_decimation',1));
    c.adcMin = -.05;
    c.adcMax = .05;
    out = runModel(model,c);
    trace = out.trace;
    lost = trace(:,21)>0;
    assert(any(trace(:,15)) && any(trace(:,20)) && any(lost) && ...
        ~any(trace(lost,[7:9 15]),'all'), ...
        'An overloaded sample after acquisition must latch loss and stop feedback.');
    result.faults = [result.faults; struct('mode',mode, ...
        'fault','ADC overload after acquisition','overflow_samples',nnz(trace(:,20)), ...
        'frames',nnz(trace(:,9)),'passed',true)]; %#ok<AGROW>
    clear closeModel
end
assert(isequal(heads{1},heads{2}),'Electrical topology must not change the nominal head.');
result.head = heads{1};
result.status = 'passed';

if ~isempty(receiptPath)
    [fid,msg] = fopen(receiptPath,'w','n','UTF-8');
    assert(fid>=0,'Could not write verification receipt: %s',msg);
    closeFile = onCleanup(@() fclose(fid));
    fprintf(fid,'%s\n',jsonencode(result,'PrettyPrint',true));
end
end

function blockCount = checkNative(model)
blocks = find_system(model,'LookUnderMasks','all','FollowLinks','on','Type','Block');
blockTypes = get_param(blocks,'BlockType');
forbidden = {'S-Function','MATLABFcn','InterpretedMATLABFcn','MATLABSystem','FromWorkspace'};
assert(~any(ismember(blockTypes,forbidden)),'Runtime code or prerecorded input in %s.',model);
assert(isempty(find_system(model,'LookUnderMasks','all','SFBlockType','MATLAB Function')));
assert(all(ismember({'Gain','Sum','UnitDelay','Switch'},blockTypes)));
blockCount = numel(blocks);
end

function metrics = checkPorts(c)
assert(isequal(size(c.portCapacitance_F),[4 4]) && ...
    norm(c.portCapacitance_F-c.portCapacitance_F.',inf)<1e-20);
[~,notPositiveDefinite] = chol(c.portCapacitance_F);
assert(notPositiveDefinite==0,'Terminal capacitance must be positive definite.');

coupling = c.portCoupling;
drive = c.portDriveMap;
sense = c.portSenseMap;
assert(isequal(size(coupling),[4 2]) && rank(coupling.'*drive)==2 && rank(sense*coupling)==2);
assert(isequal(size(c.groupVoltage),[4 c.stateCount]) && rank(c.groupVoltage)==4);
assert(isequal(size(c.portCV),[4 c.stateCount]));
assert(norm(c.pickoff-sense*c.portCV,inf)<1e-12);

if c.reuse
    assert(isequal(sign(drive),[1 0;0 1;-1 0;0 -1]));
    assert(isequal(sense~=0,logical([1 0 1 0;0 1 0 1])));
    assert(sense(1,1)*sense(1,3)<0 && sense(2,2)*sense(2,4)<0);
else
    assert(isequal(sign(drive),[1 0;0 1;0 0;0 0]));
    assert(isequal(sense~=0,logical([0 0 1 0;0 0 0 1])));
end

% Step both modal drive commands from rest. A quarter-carrier test allows
% the nominal electrical poles to settle while remaining inside the drive slot.
u = [.1;.06];
x = zeros(c.stateCount,1);
for k = 1:round(c.n/4)
    x = c.Ad*x+c.Bd*u;
end
actual = c.groupVoltage*x;
pattern = drive*u;
driveGain = (pattern.'*actual)/(pattern.'*pattern);
assert(driveGain>0 && norm(actual-driveGain*pattern,inf)<.02*max(abs(actual)), ...
    'Held drive must reach the intended group terminals and polarities.');

afterBleed = [];
if c.reuse
    for k = 1:c.senseStart-c.driveEnd
        x = c.Af*x;
    end
    afterBleed = c.groupVoltage*x;
    assert(max(abs(afterBleed))<.05*max(abs(actual)), ...
        'The nominal shared-terminal bleed did not discharge the drive residue.');
end
metrics = struct('mode',c.mode,'drive_map',drive,'sense_map',sense, ...
    'modal_drive_rank',rank(coupling.'*drive),'modal_sense_rank',rank(sense*coupling), ...
    'group_drive_step_V',actual.','group_after_bleed_V',afterBleed.');
end

function metrics = checkParity(model,c,blockCount)
[~,reference,refFrames] = five_reference(c);
out = runModel(model,c);
trace = out.trace;
frames = out.frames;
assert(size(trace,2)==26 && size(frames,2)==27);
assert(isequal(size(reference),size(trace)) && isequal(size(refFrames),size(frames)));
flags = [1:4 9 15 20:22];
assert(isequal(reference(:,flags),trace(:,flags)) && ...
    isequal(refFrames(:,1+flags),frames(:,1+flags)));
maxDelta = max(abs(reference-trace),[],'all');
assert(maxDelta<1e-4 && ~isempty(frames) && max(abs(refFrames-frames),[],'all')<1e-4);

slot = trace(:,1);
driveOn = trace(:,2)>0;
senseOn = trace(:,3)>0;
valid = trace(:,4)>0;
assert(isequal(driveOn,slot<c.driveEnd));
assert(isequal(senseOn,slot>=c.senseStart & slot<c.validEnd));
assert(isequal(valid,senseOn & slot>=c.validStart));
assert(c.continuous || ~any(driveOn & senseOn));
assert(~any(trace(~driveOn,7:8),'all'));
available = [false(c.adcLatency,1); valid(1:end-c.adcLatency)];
assert(~any(trace(~available,5:6),'all') && ~any(trace(~available,20)));
assert(all(slot(trace(:,9)>0)==mod(c.validEnd+c.adcLatency,c.frame)));

metrics = struct('mode',c.mode,'samples',size(trace,1),'native_blocks',blockCount, ...
    'adc_Hz',1/c.Ts,'dac_Hz',1/(c.Ts*c.p.dac_divisor),'frames',size(frames,1), ...
    'max_trace_delta',maxDelta, ...
    'max_terminal_voltage_delta_V',max(abs(reference(:,23:26)-trace(:,23:26)),[],'all'));
fprintf('PARITY %s, DAC %.0f S/s: %d samples, max delta %.6g\n', ...
    c.mode,metrics.dac_Hz,metrics.samples,maxDelta);
end

function out = runModel(model,c)
in = Simulink.SimulationInput(model);
in = in.setVariable('c',c,'Workspace',model);
in = in.setModelParameter('SaveTime','off');
out = sim(in);
assert(all(isfinite(out.trace),'all') && all(isfinite(out.frames),'all'));
end

function metrics = checkNominal(out,c,settle)
frames = out.frames(out.frames(:,1)>=settle,:);
assert(size(frames,1)>100 && ~any(out.trace(:,21)),'Frame loss in nominal closed-loop run.');
sample = round(frames(:,1)/c.Ts);
assert(all(diff(sample)==c.frame));
assert(all(frames(:,16)));
measuredAngle = frames(:,15)-frames(1,15);
truthAngle = c.omega*(frames(:,1)-frames(1,1));
errorAngle = measuredAngle-truthAngle;
amplitude = sqrt(sum(frames(:,11:14).^2,2));
rmse = sqrt(mean(errorAngle.^2));
assert(rmse<.015 && min(amplitude)>.8 && max(amplitude)<1.2);
metrics = struct('mode',c.mode,'rate_rad_s',c.omega,'frames',size(frames,1), ...
    'body_rms_rad',rmse,'body_peak_rad',max(abs(errorAngle)), ...
    'minimum_amplitude',min(amplitude),'maximum_amplitude',max(amplitude), ...
    'peak_group_voltage_V',max(abs(out.trace(:,23:26)),[],1));
end
