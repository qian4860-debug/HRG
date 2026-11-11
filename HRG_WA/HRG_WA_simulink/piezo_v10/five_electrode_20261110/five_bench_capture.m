function report = five_bench_capture(csvPath, sampleRate_Hz, adcBits, adcFullScale_Vpp, opts)
% 分析不分时样机假负载的共时基采样。CSV 码值为已解码的有符号原始 ADC 码。
% 板卡实际采样率、ADC 位数和差分满量程由调用方按实物配置输入。
arguments
    csvPath (1,1) string
    sampleRate_Hz (1,1) double {mustBeFinite,mustBePositive}
    adcBits (1,1) double {mustBeInteger,mustBeInRange(adcBits,2,32)}
    adcFullScale_Vpp (1,1) double {mustBeFinite,mustBePositive}
    opts.Carrier_Hz (1,1) double {mustBeFinite,mustBePositive} = 6800
    opts.TimingTolerance_ticks (1,1) double {mustBeFinite,mustBePositive} = 0.1
end

capture = readtable(csvPath,'VariableNamingRule','preserve');
columns = ["sample_index","time_s","reference_V","dac_V","drive_V","cv_x_V","cv_y_V", ...
    "adc_x_code","adc_y_code","adc_clip","dac_clip"];
assert(all(ismember(columns,string(capture.Properties.VariableNames))), ...
    'CSV 缺少字段：%s',strjoin(setdiff(columns,string(capture.Properties.VariableNames)),', '));
raw = capture{:,cellstr(columns)};
assert(isnumeric(raw) && size(raw,1)>=16 && all(isfinite(raw(:,1:9)),'all'), ...
    '需要至少 16 行有限数值采样，过载标志允许未知。');
tick = raw(:,1);
t = raw(:,2)-raw(1,2);
assert(all(tick==fix(tick) & tick>=0) && all(diff(t)>0), ...
    'sample_index 须为非负整数，time_s 须严格递增。');
assert(t(end)*opts.Carrier_Hz>=4 && sampleRate_Hz>2*opts.Carrier_Hz, ...
    '记录须覆盖至少 4 个载波周期，采样率须高于奈奎斯特下限。');
codes = raw(:,8:9);
flags = raw(:,10:11);
assert(all(ismember(flags,[0 1]) | isnan(flags),'all'), ...
    '过载标志必须为 0、1 或代表不可观测的 NaN。');

% FPGA 采样编号检查漏拍和乱序。时间列与编号步长比较，允许采集器时间量化。
advance = diff(tick);
lost = sum(max(advance-1,0));
orderErrors = nnz(advance<=0);
timeError = max(abs(diff(t)*sampleRate_Hz-advance));
halfCodes = 2^(adcBits-1);
codeInvalid = nnz(any(codes~=fix(codes) | codes < -halfCodes | codes > halfCodes-1,2));
railCount = nnz(any(codes==-halfCodes | codes==halfCodes-1,2));
clipCount = sum(flags==1,1);
adcVoltage = codes*(adcFullScale_Vpp/(2*halfCodes));

% 同一时间轴拟合 6.8 kHz 基波和直流。a*cos+b*sin 的复幅值为 a-j*b。
phase = 2*pi*opts.Carrier_Hz*t;
basis = [ones(size(t)),cos(phase),sin(phase)];
assert(rank(basis)==3,'采样相位不足，无法分离直流、正弦和余弦。');
signals = [raw(:,3:7),adcVoltage];
fit = basis\signals;
phasor = complex(fit(2,:),-fit(3,:));
residual = sqrt(mean((signals-basis*fit).^2,1));
names = ["Reference","DAC","Driver","CV_X","CV_Y","ADC_X","ADC_Y"];
node = table(names.',fit(1,:).',abs(phasor).',residual.', ...
    'VariableNames',{'Node','DC_V','CarrierPeak_V','ResidualRMS_V'});

% 弱节点或无激励时保留测得的幅值，增益和相位标为 NaN 以避免误报。
present = abs(phasor)>max(3*residual,64*eps(max(abs(signals),[],1)));
pairs = [3 2;4 1;5 1;6 4;7 5;5 4;7 6];
labels = ["Driver / DAC","CV_X / Reference","CV_Y / Reference", ...
    "ADC_X / CV_X","ADC_Y / CV_Y","CV_Y / CV_X","ADC_Y / ADC_X"];
gain = NaN(size(pairs,1),1);
phase_deg = gain;
for k = 1:size(pairs,1)
    p = pairs(k,:);
    if all(present(p))
        ratio = phasor(p(1))/phasor(p(2));
        gain(k) = abs(ratio);
        phase_deg(k) = rad2deg(angle(ratio));
    end
end
transfer = table(labels.',gain,phase_deg,'VariableNames',{'Path','Gain_V_per_V','Phase_deg'});

test = ["采样编号连续";"采样时间与配置一致";"ADC 码合法";"ADC 未触轨";"ADC 无过载";"DAC 无限幅"];
value = [lost+orderErrors;timeError;codeInvalid;railCount;clipCount(:)];
limit = [0;opts.TimingTolerance_ticks;0;0;0;0];
% 部分过载标志不可用时，仍保留观测到的故障，但不能据此宣称全程通过。
complete = [true(4,1);all(~isnan(flags),1).'];
failed = value>limit;
passed = complete & ~failed;
checks = table(test,value,limit,complete,passed, ...
    'VariableNames',{'Check','Measured','Limit','Complete','Passed'});
status = "PASS_DATA_CHECKS";
if any(failed)
    status = "FAIL_DATA_CHECKS";
elseif ~all(complete)
    status = "INCOMPLETE_DATA_CHECKS";
end
report = struct('status',status,'sample_count',height(capture),'missing_samples',lost, ...
    'out_of_order_or_duplicate',orderErrors,'max_time_step_error_ticks',timeError, ...
    'adc_peak_fraction_of_full_scale',max(abs(codes),[],1)/halfCodes, ...
    'nodes',node,'transfers',transfer,'checks',checks);
if nargout==0
    fprintf('假负载采集数据判定 %s，%d 拍\n',status,height(capture));
    disp(checks); disp(node); disp(transfer);
end
end
