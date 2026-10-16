function HRG_WA_export_test_vectors(matFile, csvFile)
% HRG_WA_EXPORT_TEST_VECTORS  Export MATLAB model log as FPGA/ASIC verification CSV vectors.
%
% 功能说明：
%   FPGA 验证阶段通常需要把 MATLAB golden model 输出成 testbench 输入/参考输出。
%   本函数读取 run_HRG_WA_ASIC_FPGA_demo.m 保存的 HRG_WA_ASIC_FPGA_result.mat，
%   并导出 CSV：ADC 输入、控制输出、角度/角速度参考、状态字。
%
% 用法：
%   HRG_WA_export_test_vectors('HRG_WA_ASIC_FPGA_result.mat','HRG_WA_vectors.csv')

if nargin < 1 || isempty(matFile)
    matFile = 'HRG_WA_ASIC_FPGA_result.mat';
end
if nargin < 2 || isempty(csvFile)
    csvFile = 'HRG_WA_vectors.csv';
end

s = load(matFile,'log');
log = s.log;

T = table();
T.sample = uint32((0:length(log.t)-1).');
T.time_s = log.t;
T.adc_E = log.adcE;
T.adc_Q = log.adcQ;
T.adc_S = log.adcS;
T.adc_R = log.adcR;
T.fa_cmd = log.faCmd;
T.fq_cmd = log.fqCmd;
T.virt_cmd = log.virtCmd;
T.angle_ref_rad = log.angleOut;
T.rate_ref_rads = log.rateOut;
T.input_rate_rads = log.inputRate;
T.status_word = log.statusWord;
T.mode = uint32(log.mode);

writetable(T, csvFile);
fprintf('Exported FPGA/ASIC verification vectors to %s\n', csvFile);
end
