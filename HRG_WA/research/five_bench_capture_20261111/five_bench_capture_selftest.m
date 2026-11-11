% 使用可计算的合成载波测试分析入口，并注入漏拍与 ADC 过载。
function report = five_bench_capture_selftest()
sampleRate = 1088000;
tick = (0:1600).';
t = tick/sampleRate;
w = 2*pi*6800;
ref = 0.05*cos(w*t);
dac = 0.10*cos(w*t);
drive = 0.20*cos(w*t-0.1);
cvX = 0.1*cos(w*t-0.2);
cvY = 0.08*cos(w*t-0.4);
adcX = round(0.12*cos(w*t-0.23)*32768);
adcY = round(0.064*cos(w*t-0.43)*32768);
zero = zeros(size(t));
columns = {'sample_index','time_s','reference_V','dac_V','drive_V','cv_x_V','cv_y_V', ...
    'adc_x_code','adc_y_code','adc_clip','dac_clip'};
data = table(tick,t,ref,dac,drive,cvX,cvY,adcX,adcY,zero,zero,'VariableNames',columns);
path = [tempname '.csv'];
cleanup = onCleanup(@() delete(path));
writetable(data,path);
nominal = five_bench_capture(path,sampleRate,16,2);
assert(nominal.status=="PASS_DATA_CHECKS");
assert(abs(nominal.transfers.Gain_V_per_V(1)-2)<1e-10);
assert(abs(nominal.transfers.Phase_deg(1)-rad2deg(-0.1))<1e-8);
assert(max(abs(nominal.transfers.Gain_V_per_V(4:5)-[1.2;0.8]))<2e-4);
assert(max(abs(nominal.transfers.Phase_deg(4:5)-rad2deg(-0.03)))<0.005);

% 散片未引出限幅标志时标记不可观测，不能判定通过。
data.dac_clip(:) = NaN;
writetable(data,path);
incomplete = five_bench_capture(path,sampleRate,16,2);
assert(incomplete.status=="INCOMPLETE_DATA_CHECKS" && ~incomplete.checks.Complete(6));

% 删除一条记录并置过载位，保留原采样计数，验证负例必须给出 FAIL。
data(400,:) = [];
data.adc_clip(120) = 1;
writetable(data,path);
fault = five_bench_capture(path,sampleRate,16,2);
assert(fault.status=="FAIL_DATA_CHECKS" && fault.missing_samples==1 && ...
    fault.checks.Measured(5)==1 && fault.checks.Passed(2));
report = struct('source',"SYNTHETIC_SELFTEST",'nominal_status',nominal.status, ...
    'driver_gain',nominal.transfers.Gain_V_per_V(1),'driver_phase_deg',nominal.transfers.Phase_deg(1), ...
    'adc_gain',nominal.transfers.Gain_V_per_V(4:5),'adc_phase_deg',nominal.transfers.Phase_deg(4:5), ...
    'incomplete_status',incomplete.status,'injected_fault_status',fault.status, ...
    'missing_samples',fault.missing_samples,'adc_clip_samples',fault.checks.Measured(5));
disp(report)
end
