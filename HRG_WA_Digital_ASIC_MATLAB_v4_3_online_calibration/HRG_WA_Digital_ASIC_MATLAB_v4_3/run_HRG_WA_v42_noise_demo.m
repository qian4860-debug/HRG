clear; % 清除工作区变量以避免旧版噪声分析参数污染本次运行。
clc; % 清空命令窗口以便集中查看Allan与PSD结果。
close all; % 关闭旧图窗以避免不同版本噪声曲线混淆。
user = HRG_WA_v42_user_config(); % 加载V4.2集中式用户参数表头。
user.sim.duration = 30.0; % 把零速仿真延长到三十秒以获得基本Allan和PSD统计样本。
user.input.rateTransitionTimesSec = []; % 清除动态角速度切换时刻以形成连续平稳噪声数据段。
user.input.rateLevelsDps = 0; % 把外部真实角速度设置为零以评价输出噪声与残余零偏。
user.env.temperatureStartC = user.env.referenceTemperature; % 把噪声试验起始温度固定在标定参考温度。
user.env.temperatureEndC = user.env.referenceTemperature; % 把噪声试验结束温度固定在标定参考温度。
user.selftest.enable = false; % 关闭SELFTEST以避免受控测试载波污染平稳噪声序列。
user.analysis.autoRun = true; % 使能闭环仿真结束后的Allan与PSD自动分析。
p = HRG_WA_v42_params(user); % 把零速长时表头转换为完整内部参数结构体。
fprintf('模型修订=%s，零速噪声仿真时长=%.3fs\n', p.meta.revision, p.sim.duration); % 打印模型版本和噪声试验时长。
result = HRG_WA_v42_simulate(p); % 运行零速长时HRG全角数字ASIC闭环仿真。
analysis = result.noiseAnalysis; % 读取仿真器自动生成的Allan与PSD可信度分析结果。
assert(analysis.valid, '噪声分析无效：%s', analysis.reason); % 要求最长连续RUN数据段满足噪声分析样本条件。
fprintf('噪声段=%.3f至%.3fs，样本数=%d，平均速率误差=%.6gdeg/s\n', analysis.segmentStartTime, analysis.segmentEndTime, analysis.sampleCount, analysis.meanRateErrorDps); % 打印实际参与噪声分析的数据段信息。
fprintf('ARW估计=%.6gdeg/sqrt(h)，最小Allan量级=%.6gdeg/h\n', analysis.angleRandomWalkDegPerSqrtHour, analysis.minimumAllanDph); % 打印由有限记录估计的角随机游走和最小Allan量级。
save('HRG_WA_v42_noise_result.mat', 'result', 'analysis'); % 保存零速闭环日志和完整Allan与PSD结果。
fid = fopen('HRG_WA_v42_noise_result.csv', 'w'); % 创建Allan与PSD统一CSV输出文件。
assert(fid >= 0, '无法创建噪声分析CSV文件。'); % 检查噪声分析CSV文件是否成功打开。
cleanup = onCleanup(@() fclose(fid)); % 注册脚本结束时自动关闭CSV文件的清理动作。
fprintf(fid, 'allan_tau_s,allan_deviation_dps,psd_frequency_hz,psd_dps2_per_hz,asd_dps_per_sqrt_hz\n'); % 写入Allan与PSD统一CSV字段标题。
rowCount = max(numel(analysis.tauSec), numel(analysis.psdFrequencyHz)); % 计算统一CSV需要写入的最大行数。
for i = 1:rowCount % 遍历Allan或PSD结果的全部输出行。
    allanTau = NaN; % 初始化当前行Allan平均时间为空值。
    allanDeviation = NaN; % 初始化当前行Allan偏差为空值。
    psdFrequency = NaN; % 初始化当前行PSD频率为空值。
    psdValue = NaN; % 初始化当前行PSD数值为空值。
    asdValue = NaN; % 初始化当前行ASD数值为空值。
    if i <= numel(analysis.tauSec) % 判断当前行是否存在Allan结果。
        allanTau = analysis.tauSec(i); % 读取当前行Allan平均时间。
        allanDeviation = analysis.allanDeviationDps(i); % 读取当前行Allan偏差。
    end % 结束当前行Allan结果读取判断。
    if i <= numel(analysis.psdFrequencyHz) % 判断当前行是否存在PSD结果。
        psdFrequency = analysis.psdFrequencyHz(i); % 读取当前行PSD频率。
        psdValue = analysis.psdDps2PerHz(i); % 读取当前行功率谱密度。
        asdValue = analysis.asdDpsPerSqrtHz(i); % 读取当前行幅度谱密度。
    end % 结束当前行PSD结果读取判断。
    fprintf(fid, '%.9g,%.9g,%.9g,%.9g,%.9g\n', allanTau, allanDeviation, psdFrequency, psdValue, asdValue); % 写入当前Allan与PSD统一结果行。
end % 结束噪声分析CSV写入循环。
figure('Color', 'w', 'Position', [120 120 1100 440]); % 创建白色背景的Allan与PSD双联图。
subplot(1, 2, 1); % 选择左侧Allan偏差子图。
loglog(analysis.tauSec, analysis.allanDeviationDps, 'LineWidth', 1.2); % 绘制角速度Allan偏差对数曲线。
grid on; % 打开Allan偏差子图网格。
xlabel('平均时间 \tau / s'); % 设置Allan偏差横轴标签。
ylabel('Allan偏差 / (deg/s)'); % 设置Allan偏差纵轴标签。
title('V4.2角速度Allan偏差'); % 设置Allan偏差子图标题。
subplot(1, 2, 2); % 选择右侧角速度幅度谱密度子图。
loglog(analysis.psdFrequencyHz(2:end), analysis.asdDpsPerSqrtHz(2:end), 'LineWidth', 1.2); % 跳过直流点并绘制角速度幅度谱密度曲线。
grid on; % 打开幅度谱密度子图网格。
xlabel('频率 / Hz'); % 设置幅度谱密度横轴标签。
ylabel('ASD / ((deg/s)/sqrt(Hz))'); % 设置幅度谱密度纵轴标签。
title('V4.2角速度Welch ASD'); % 设置幅度谱密度子图标题。
exportgraphics(gcf, 'HRG_WA_v42_noise_summary.png', 'Resolution', 160); % 把Allan与PSD双联图导出为PNG文件。
