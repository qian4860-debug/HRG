function outputDir = five_rtl_vectors(outputDir, duration, scenarios)
% 逐拍导出 MATLAB 参考数据和定点系数，供 Verilog / SystemVerilog 记分板使用。
% 向量的 ADC 输入取物理采样时钟，期望结果取同一时刻的参考输出。
arguments
    outputDir (1,1) string = string(tempname)
    duration (1,1) double {mustBePositive,mustBeFinite} = 0.012
    scenarios (1,:) string = ["continuous","tdm_shared"]
end
assert(duration >= 0.006,'至少运行 6 ms，覆盖连续和分时的多个完整控制帧。');
if ~isfolder(outputDir)
    [ok,msg] = mkdir(outputDir);
    assert(ok,'%s',msg);
end
for scenario = scenarios
    c = caseConfig(scenario,duration);
    if strcmp(c.mode,'tdm_separate')
        % 独立驱检电极对照沿用 6800 Hz 的 18 状态参考，不套用同电极复用模型。
        [~,trace,~,adc] = h68_reference(c);
    else
        [~,trace,~,adc] = five_reference(c);
    end
    writeCase(outputDir,scenario,c,trace,adc);
end
fprintf('已导出 %d 套 MATLAB 对照向量：%s\n',numel(scenarios),outputDir);
end

function c = caseConfig(scenario,duration)
% 测试场景共享表头，只改变 DAC 时钟或 ADC 过载条件。
mode = "continuous";
if startsWith(scenario,"tdm_shared")
    mode = "tdm_shared";
elseif startsWith(scenario,"tdm_separate")
    mode = "tdm_separate";
end
options = struct('duration',duration,'log_decimation',1);
switch scenario
    case {"continuous","tdm_shared","tdm_separate"}
    case {"tdm_shared_div25","tdm_separate_div25"}
        options.dac_divisor = 25;
    case {"continuous_overload","tdm_shared_overload"}
        options.duration = max(duration,0.15);
        options.initial_fraction = 0.3;
    otherwise
        error('未定义的 RTL 对照工况：%s',scenario);
end
if mode == "tdm_separate"
    addpath(fullfile(fileparts(mfilename('fullpath')),'..','head6800_20261109'));
    c = h68_config(char(mode),0.5,options);
else
    c = five_config(char(mode),0.5,options);
end
if endsWith(scenario,"_overload")
    c.adcMin = -0.05;
    c.adcMax = 0.05;
end
end

function writeCase(outputDir,mode,c,trace,adc)
% 把模拟电压换成有符号转换器码。检测窗之外保持零，流水延迟由 RTL 实现。
n = size(trace,1);
acquired = zeros(n,3,'int64');
indices = adc(:,1)+1;
acquired(indices,1:2) = int64(round(adc(:,7:8)/c.adcStep));
acquired(indices,3) = int64(adc(:,9));
assert(isequal(find(trace(:,4)),indices(logical(adc(:,2)))), ...
    '物理采样时刻与参考数据的有效窗口不一致。');

% 标志和发布脉冲用原始整数。角度用 rad，和归一化 I/Q 一起量化为 Q24。
q24 = 2^24;
vec = [acquired, int64(round(trace(:,7:8)/c.dacStep)), ...
    int64(trace(:,[9 15 21])),int64(round(q24*trace(:,[14 10:13])))];
writeIntegers(fullfile(outputDir,mode+".vec"),vec);

% 转置后按 MATLAB 列顺序取元素，得到 Verilog 读入所需的行优先矩阵。
detect = reshape(c.detect.',[],1);
drive = reshape((c.forceScale*c.drive).',[],1);
scalars = [c.minEnergy;c.minLinearity;c.gamma;c.agc;c.quad;1/(4*c.B)];
writeIntegers(fullfile(outputDir,mode+".cfg"),int64(round(q24*[detect;drive;scalars])));

% 供闭环 SV 模型使用：三个窗的状态推进矩阵、双路 DAC 输入、读出及初态。
% 文件只包含离散电路系数，实际 ADC 码由 SV 使用 RTL 当前驱动生成。
plant = [reshape(c.Ad.',[],1);reshape(c.As.',[],1);reshape(c.Af.',[],1); ...
    reshape(c.Bd.',[],1);reshape(c.pickoff.',[],1);c.x0; ...
    c.adcStep;c.adcMin;c.adcMax;c.dacStep;c.Ts;c.omega];
writeValues(fullfile(outputDir,mode+".plant"),plant,'%.17g');
end

function writeIntegers(path,values)
% 文本文件由 testbench 按有符号十进制读取，无表头且每拍一行。
writeValues(path,values,'%d');
end

function writeValues(path,values,format)
% 按行导出，保留双精度电路系数或有符号整数的原始精度。
[fid,msg] = fopen(path,'wt');
assert(fid >= 0,'%s',msg);
closeFile = onCleanup(@() fclose(fid));
fmt = [repmat([format,' '],1,size(values,2)-1),format,'\n'];
fprintf(fid,fmt,values.');
[message,number] = ferror(fid);
assert(number==0,'%s',message);
end
