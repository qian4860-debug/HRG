function result = five_verify_native_dither(outPath,outDir)
% 逐拍核对原生 ADC 注入、X/Y 随机序列、码值及过载标志。
% 同一份新模型分别验证默认零注入、双路抖动和短时过载。
arguments
    outPath (1,:) char = fullfile(fileparts(mfilename('fullpath')),'native_dither.json')
    outDir (1,:) char = tempname
end
here = fileparts(mfilename('fullpath'));
repo = fileparts(fileparts(here));
fiveDir = fullfile(repo,'HRG_WA_simulink','piezo_v10','five_electrode_20261110');
addpath(fiveDir);
models = five_build_dither_study(outDir);
modes = {'continuous','tdm_shared'};
checks = [];
for k = 1:numel(models)
    model = models{k};
    mode = modes{k};
    modelPath = fullfile(outDir,[model '.slx']);
    for label = ["default","positive","forced_clip"]
        settings = struct('duration',.006,'log_decimation',1);
        if label~="default"
            settings.adc_dither_lsb_rms = .3;
            settings.adc_dither_seeds = [89723 2978563921];
            settings.adc_noise_rms = 10e-6;
        end
        c = five_config(mode,.5,settings);
        if label=="forced_clip"
            % 以狭量程触发真实过载逻辑，同时保留 ADC 步长与时序。
            clipCode = floor(.02/c.adcStep);
            c.adcMin = -clipCode*c.adcStep;
            c.adcMax = (clipCode-1)*c.adcStep;
        end
        entry = verifyOne(modelPath,model,c,label);
        checks = [checks; entry]; %#ok<AGROW>
        fprintf('%s %s：逐拍差 %.3g，ADC 注入差 %.3g V，溢出拍数 %d\n', ...
            entry.mode,entry.case_name,entry.max_trace_difference, ...
            entry.max_adc_input_difference_V,entry.clipped_monitor_samples);
    end
end
result = struct('release',version('-release'),'scope','native ADC dither parity, 6 ms cases', ...
    'models',{models},'checks',{checks});
if ~isempty(outPath)
    [fid,msg] = fopen(outPath,'w','n','UTF-8');
    assert(fid>=0,'原生抖动回执写入失败：%s',msg);
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid,'%s\n',jsonencode(result,'PrettyPrint',true));
end
end

function entry = verifyOne(modelPath,model,c,label)
% 从同一物理时钟对拍 MATLAB 参考与 Simulink 的原生旁路日志。
load_system(modelPath);
cleanup = onCleanup(@() close_system(model,0));
types = get_param(find_system(model,'Type','Block'),'BlockType');
assert(~any(ismember(types,{'MATLABFcn','S-Function','MATLABSystem','FromWorkspace'})) && ...
    isempty(find_system(model,'SFBlockType','MATLAB Function')));
[time,reference,frames,monitor] = five_reference(c);
in = Simulink.SimulationInput(model);
in = in.setVariable('c',c,'Workspace',model);
in = in.setModelParameter('SaveTime','off');
out = sim(in);
traceError = maxDifference(out.trace,reference);
frameError = maxDifference(out.frames,frames);
assert(traceError<1e-8 && frameError<1e-8, ...
    '%s %s 的逐拍差 %.9g 或逐帧差 %.9g 超限。',c.mode,label,traceError,frameError);
flags = [1:4 9 15 20:22];
assert(isequal(out.trace(:,flags),reference(:,flags)));
assert(isequal(out.trace(:,5:6),reference(:,5:6)));
assert(isequal(out.frames(:,flags+1),frames(:,flags+1)));

dither = getTwoLaneSignal(out,'adc_dither_V',time);
beforeDither = getTwoLaneSignal(out,'adc_input_pre_dither_V',time);
adcInput = getTwoLaneSignal(out,'adc_input_V',time);
% 每拍使用旧状态生成注入，再按 32 位模运算推进两路 LCG。
state = double(c.p.adc_dither_seeds(:));
expected = zeros(numel(time),2);
scale = sqrt(12)*(c.p.adc_dither_lsb_rms*c.adcStep);
for k = 1:numel(time)
    expected(k,:) = (scale*(state/2^32-.5)).';
    state = mod(69069*state+1,2^32);
end
assert(isequal(dither,expected) && isequal(adcInput,beforeDither+dither));
rows = monitor(:,1)+1;
adcError = maxDifference(adcInput(rows,:),monitor(:,5:6));
assert(adcError<1e-9);
if label=="default"
    assert(all(dither==0,'all'),'默认配置的抖动电压应恒为零。');
elseif label=="forced_clip"
    assert(any(monitor(:,9)) && any(out.trace(:,20)),'过载试验应触发标志。');
else
    assert(any(dither(:,1)~=dither(:,2)),'两路抖动应使用不同序列。');
end
entry = struct('mode',c.mode,'case_name',label,'adc_samples',numel(time), ...
    'frames',size(out.frames,1),'adc_dither_lsb_rms',c.p.adc_dither_lsb_rms, ...
    'observed_dither_rms_V',sqrt(mean(dither.^2,1)), ...
    'clipped_monitor_samples',nnz(monitor(:,9)), ...
    'max_trace_difference',traceError,'max_frame_difference',frameError, ...
    'max_adc_input_difference_V',adcError,'adc_codes_equal',true,'dither_rng_equal',true);
end

function values = getTwoLaneSignal(out,name,time)
% 不依赖向量的日志存储方向，统一成时间在行、两路 ADC 在列。
values = out.logsout.getElement(name).Values;
assert(numel(values.Time)==numel(time) && maxDifference(values.Time,time)<1e-15);
count = numel(time);
if values.IsTimeFirst
    values = reshape(values.Data,count,2);
else
    values = reshape(values.Data,2,count).';
end
end

function difference = maxDifference(a,b)
assert(isequal(size(a),size(b)));
delta = abs(a-b);
difference = max([0;delta(:)]);
end
