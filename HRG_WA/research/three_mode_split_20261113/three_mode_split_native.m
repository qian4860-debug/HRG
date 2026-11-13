function result = three_mode_split_native(outPath,outDir)
% 三种五端模式在相同 ADC/DAC 设置下逐拍对拍原生模型和 MATLAB。
% 并用相同连续电气网络检查分时不复用是否仅改变驱动与采样门控。
arguments
    outPath (1,:) char = fullfile(fileparts(mfilename('fullpath')),'three_mode_split_native.json')
    outDir (1,:) char = tempname
end
models = three_mode_split_build(outDir);
modes = {'continuous','tdm_separate','tdm_shared'};
checks = [];
cases = [
    0,    16, 0
    .05,  16, 0
    .05,  10, 0
    .05,  16, 1
    ];
reference = three_mode_split_config('continuous',.5,.05,22.5,.006,16);
separate = three_mode_split_config('tdm_separate',.5,.05,22.5,.006,16);
% 两者在同一驱动命令下使用相同组端导纳、电极映射与持续加载的 C/V。
assert(isequal(separate.Ad,separate.Af,separate.As), ...
    '不复用版在各窗应保持同一持续加载的电气状态矩阵。');
plantDelta = max(maxDifference(reference.Ad,separate.Ad),maxDifference(reference.Bd,separate.Bd));
assert(plantDelta<1e-13 && isequal(reference.portDriveMap,separate.portDriveMap) && ...
    isequal(reference.portSenseMap,separate.portSenseMap), ...
    '连续与分时不复用的匹配电路差 %.6g 超限。',plantDelta);
for k = 1:numel(models)
    model = models{k};
    path = fullfile(outDir,[model '.slx']);
    load_system(path);
    cleanup = onCleanup(@() close_system(model,0));
    blockCount = auditModel(model);
    for row = 1:size(cases,1)
        c = three_mode_split_config(modes{k},.5,cases(row,1),22.5,.006,cases(row,2));
        c.logDecimation = 1;
        forcedClip = logical(cases(row,3));
        if forcedClip
            % 用真实 ADC 整码轨限制造 ADC 过载，确认过载随采样流水线传播。
            clipCode = floor(.02/c.adcStep);
            c.adcMin = -clipCode*c.adcStep;
            c.adcMax = (clipCode-1)*c.adcStep;
        end
        entry = checkModel(model,c,blockCount,forcedClip);
        checks = [checks;entry]; %#ok<AGROW>
        fprintf('%s，频差 %.2f Hz，%d 位 ADC，强制过载 %d：逐拍差 %.3g，发布 %d 帧\n', ...
            entry.mode,entry.split_Hz,entry.adc_bits,forcedClip,entry.max_trace_delta,entry.frames);
    end
    clear cleanup
end
result = struct('release',version('-release'),'status','passed', ...
    'scope','native five-terminal matched converter and distinct wiring parity', ...
    'models',{models},'dedicated_plant_max_matrix_delta',plantDelta,'checks',{checks});
if ~isempty(outPath)
    [fid,msg] = fopen(outPath,'w','n','UTF-8');
    assert(fid>=0,'三模式原生回执写入失败：%s',msg);
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid,'%s\n',jsonencode(result,'PrettyPrint',true));
end
end

function count = auditModel(model)
% 拒绝运行 MATLAB 或回放预录信号的块，要求保留原生旁路观察。
blocks = find_system(model,'LookUnderMasks','all','FollowLinks','on','Type','Block');
types = get_param(blocks,'BlockType');
assert(~any(ismember(types,{'MATLABFcn','InterpretedMATLABFcn','S-Function','MATLABSystem','FromWorkspace'})));
assert(isempty(find_system(model,'SFBlockType','MATLAB Function')));
assert(all(ismember({'Gain','Switch','Sum','UnitDelay'},types)));
assert(getSimulinkBlockHandle([model '/Scoreboard monitor'])>0);
count = numel(blocks);
end

function result = checkModel(model,c,blockCount,forcedClip)
% 同时核对原始码、驱检门控、流水延迟、帧发布与五组端连续电压。
[~,trace,frames] = five_reference(c);
in = Simulink.SimulationInput(model);
in = in.setVariable('c',c,'Workspace',model);
in = in.setModelParameter('SaveTime','off');
out = sim(in);
traceDelta = maxDifference(out.trace,trace);
frameDelta = maxDifference(out.frames,frames);
eventColumns = [1:4 9 15 20:22];
assert(isequal(out.trace(:,eventColumns),trace(:,eventColumns)));
assert(isequal(out.frames(:,1+eventColumns),frames(:,1+eventColumns)));
assert(isequal(out.trace(:,5:8),trace(:,5:8)),'转换器输出码不一致。');
assert(traceDelta<1e-8 && frameDelta<1e-8);

slot = trace(:,1);
drive = slot<c.driveEnd;
sense = slot>=c.senseStart & slot<c.validEnd;
valid = slot>=c.validStart & sense;
assert(isequal(logical(trace(:,2:4)),[drive,sense,valid]));
assert(c.continuous || ~any(drive & sense));
assert(~any(trace(~drive,7:8),'all'));
aligned = [false(c.adcLatency,1);valid(1:end-c.adcLatency)];
assert(~any(trace(~aligned,5:6),'all') && ~any(trace(~aligned,20)));
assert(all(slot(trace(:,9)>0)==mod(c.validEnd+c.adcLatency,c.frame)));
if forcedClip
    assert(any(trace(:,20)) && isempty(frames));
else
    assert(~any(trace(:,20)) && ~isempty(frames));
end
logNames = {'terminal_voltage_V','cv_output_V','afe_xy_V','adc_input_V','adc_output_V', ...
    'dac_output_V','timing_drive','timing_sense','timing_valid','frame_pulse','angle_rad'};
assert(all(ismember(logNames,out.logsout.getElementNames())));
result = struct('mode',c.mode,'split_Hz',c.p.split_hz,'adc_bits',c.p.adc_bits, ...
    'dac_bits',c.p.dac_bits,'adc_Hz',1/c.Ts,'dac_Hz',1/(c.Ts*c.p.dac_divisor), ...
    'adc_latency_ticks',c.adcLatency,'frame_ticks',c.frame,'samples',size(trace,1), ...
    'frames',size(frames,1),'native_blocks',blockCount,'forced_clip',forcedClip, ...
    'adc_clipped_samples',nnz(trace(:,20)),'max_trace_delta',traceDelta, ...
    'max_frame_delta',frameDelta,'max_terminal_voltage_delta_V', ...
    maxDifference(out.trace(:,23:26),trace(:,23:26)), ...
    'event_flags_equal',true,'adc_dac_codes_equal',true);
end

function gap = maxDifference(a,b)
assert(isequal(size(a),size(b)));
delta = abs(a-b);
gap = max([0;delta(:)]);
end
