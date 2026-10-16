function analysis = HRG_WA_v46_noise_analysis(log, p) % 对最长连续稳定RUN数据段执行Allan偏差和无工具箱Welch功率谱分析。
if nargin < 2 || isempty(p) % 判断调用者是否提供模型参数结构体。
    p = HRG_WA_v46_params(); % 未提供参数时加载V4.2标称配置。
end % 结束默认参数装载判断。
analysis.valid = false; % 默认把噪声可信度分析标记为无效。
analysis.reason = ''; % 初始化分析无效原因文字。
analysis.sampleRateHz = p.sim.fsCtrl; % 记录噪声序列使用的控制域采样率。
analysis.segmentStartTime = NaN; % 初始化最长连续稳定数据段起始时刻。
analysis.segmentEndTime = NaN; % 初始化最长连续稳定数据段结束时刻。
analysis.sampleCount = 0; % 初始化用于噪声分析的有效样本数。
analysis.tauSec = zeros(0, 1); % 初始化Allan平均时间向量。
analysis.allanDeviationDps = zeros(0, 1); % 初始化角速度Allan偏差向量。
analysis.psdFrequencyHz = zeros(0, 1); % 初始化Welch功率谱频率向量。
analysis.psdDps2PerHz = zeros(0, 1); % 初始化角速度功率谱密度向量。
analysis.asdDpsPerSqrtHz = zeros(0, 1); % 初始化角速度幅度谱密度向量。
analysis.angleRandomWalkDegPerSqrtHour = NaN; % 初始化由短时Allan区间估计的角随机游走。
analysis.minimumAllanDph = NaN; % 初始化最小Allan偏差换算的度每小时量级。
finiteMask = isfinite(log.rateOutput) & isfinite(log.inputRate) & isfinite(log.t); % 选择角速度输出、真实输入与时间戳均有限的样本。
runMask = log.mode == 3; % 选择真正处于RUN状态的样本并排除起振、捕获、自检与故障状态。
selftestMask = false(size(runMask)); % 初始化SELFTEST活动样本屏蔽向量以兼容不含该字段的旧日志。
if isfield(log, 'selftestActive') % 判断日志是否包含V4.2真实SELFTEST活动标志。
    selftestMask = log.selftestActive; % 读取SELFTEST活动样本以避免测试载波污染噪声统计。
end % 结束SELFTEST日志字段兼容判断。
stableRateMask = [true; abs(diff(log.inputRate)) < 1e-12]; % 在外部输入角速度发生切换的位置切断连续稳定数据段。
candidateMask = finiteMask & runMask & ~selftestMask & stableRateMask; % 汇总有限数、RUN、非自检和输入稳定条件。
for i = 1:numel(p.test.rateTransitionTimes) % 遍历配置的全部角速度切换时刻。
    candidateMask = candidateMask & abs(log.t - p.test.rateTransitionTimes(i)) > p.test.ignoreAfterTransition; % 排除速率切换附近的滤波与Kalman过渡窗口。
end % 结束角速度切换窗口排除循环。
[segmentStart, segmentEnd] = local_longest_true_run(candidateMask); % 查找满足条件的最长连续样本区间。
if segmentStart == 0 % 判断是否完全没有满足噪声分析条件的数据段。
    analysis.reason = '没有找到连续稳定的RUN数据段。'; % 记录缺少有效噪声数据段的原因。
    return; % 结束当前噪声分析并返回无效结果。
end % 结束无有效数据段判断。
sampleCount = segmentEnd - segmentStart + 1; % 计算最长连续稳定数据段样本数。
if sampleCount < p.analysis.minimumSamples % 判断最长数据段是否达到Allan与PSD最少样本要求。
    analysis.reason = sprintf('最长连续稳定RUN数据段仅%d点，小于minimumSamples=%d。', sampleCount, p.analysis.minimumSamples); % 记录有效样本不足的具体原因。
    return; % 结束当前噪声分析并返回无效结果。
end % 结束噪声分析最少样本检查。
rateErrorDps = (log.rateOutput(segmentStart:segmentEnd) - log.inputRate(segmentStart:segmentEnd)) * 180 / pi; % 构造连续稳定区间的角速度误差序列并转换为度每秒。
timeLocal = (0:sampleCount - 1).' / p.sim.fsCtrl; % 生成噪声数据段相对时间向量。
timeCentered = timeLocal - mean(timeLocal); % 对时间向量去均值以改善线性趋势拟合数值条件。
rateCentered = rateErrorDps - mean(rateErrorDps); % 对角速度误差去均值以移除常值零偏。
trendSlope = sum(timeCentered .* rateCentered) / max(sum(timeCentered .^ 2), eps); % 使用最小二乘估计角速度误差的线性漂移斜率。
rateDetrended = rateCentered - trendSlope * timeCentered; % 去除线性漂移以避免短记录PSD被确定性温漂主导。
[tauSec, allanDeviationDps] = local_overlapping_allan(rateDetrended, p.sim.fsCtrl, p.analysis.maximumAllanPoints); % 计算重叠Allan偏差曲线。
[frequencyHz, psdDps2PerHz] = local_welch_psd(rateDetrended, p.sim.fsCtrl, p.analysis.psdSegmentSec, p.analysis.psdOverlapRatio); % 计算不依赖信号处理工具箱的Welch功率谱密度。
analysis.valid = true; % 标记Allan与PSD计算已经成功完成。
analysis.reason = 'OK'; % 记录噪声可信度分析成功状态。
analysis.segmentStartTime = log.t(segmentStart); % 记录实际噪声数据段起始时刻。
analysis.segmentEndTime = log.t(segmentEnd); % 记录实际噪声数据段结束时刻。
analysis.sampleCount = sampleCount; % 记录实际参与分析的样本数。
analysis.meanRateErrorDps = mean(rateErrorDps); % 记录去趋势前角速度误差均值。
analysis.linearDriftDpsPerSec = trendSlope; % 记录角速度误差线性漂移斜率。
analysis.tauSec = tauSec; % 保存Allan平均时间向量。
analysis.allanDeviationDps = allanDeviationDps; % 保存角速度Allan偏差曲线。
analysis.psdFrequencyHz = frequencyHz; % 保存Welch功率谱频率向量。
analysis.psdDps2PerHz = psdDps2PerHz; % 保存角速度功率谱密度曲线。
analysis.asdDpsPerSqrtHz = sqrt(max(psdDps2PerHz, 0)); % 由功率谱密度计算幅度谱密度。
shortMask = tauSec <= max(1 / p.sim.fsCtrl, min(1.0, tauSec(end))); % 选择不超过一秒的短平均时间区间估算白噪声系数。
analysis.angleRandomWalkDegPerSqrtHour = median(allanDeviationDps(shortMask) .* sqrt(tauSec(shortMask))) * 60; % 把短时Allan白噪声系数换算为度每根号小时。
analysis.minimumAllanDph = min(allanDeviationDps) * 3600; % 把记录内最小Allan偏差换算为度每小时量级供版本比较。
end % 结束Allan与PSD噪声可信度分析函数。

function [startIndex, endIndex] = local_longest_true_run(mask) % 查找逻辑向量中最长连续真值区间的起止索引。
paddedMask = [false; mask(:); false]; % 在逻辑向量两端补假值以统一处理边界区间。
edges = diff(double(paddedMask)); % 计算真值区间的上升沿与下降沿。
starts = find(edges == 1); % 查找全部连续真值区间的起始索引。
ends = find(edges == -1) - 1; % 查找全部连续真值区间的结束索引。
if isempty(starts) % 判断逻辑向量中是否没有任何真值区间。
    startIndex = 0; % 使用零表示不存在有效连续区间。
    endIndex = 0; % 使用零表示不存在有效连续区间。
    return; % 结束最长连续区间查找。
end % 结束空区间判断。
[~, longestIndex] = max(ends - starts + 1); % 查找样本数最多的连续真值区间序号。
startIndex = starts(longestIndex); % 返回最长连续真值区间起始索引。
endIndex = ends(longestIndex); % 返回最长连续真值区间结束索引。
end % 结束最长连续真值区间函数。

function [tauSec, allanDeviation] = local_overlapping_allan(rateData, sampleRateHz, maximumPoints) % 计算角速度序列的重叠Allan偏差。
sampleCount = numel(rateData); % 读取角速度噪声序列样本数。
maximumCluster = max(1, floor(sampleCount / 4)); % 把最大聚类长度限制为总样本数四分之一以保留充分差分样本。
clusterSizes = unique(max(1, round(logspace(0, log10(maximumCluster), maximumPoints)))); % 生成对数分布且不重复的Allan聚类长度。
tauSec = zeros(numel(clusterSizes), 1); % 预分配Allan平均时间向量。
allanDeviation = zeros(numel(clusterSizes), 1); % 预分配Allan偏差向量。
cumulativeRate = [0; cumsum(rateData(:))]; % 构造快速计算滑动聚类平均值的累加和向量。
validCount = 0; % 初始化实际有效Allan点计数器。
for i = 1:numel(clusterSizes) % 遍历全部候选聚类长度。
    clusterLength = clusterSizes(i); % 读取当前Allan聚类包含的样本数。
    clusterAverage = (cumulativeRate(1 + clusterLength:end) - cumulativeRate(1:end - clusterLength)) / clusterLength; % 使用累加和计算所有重叠聚类平均值。
    if numel(clusterAverage) <= clusterLength % 判断当前聚类长度是否仍具有相隔一个聚类的差分样本。
        continue; % 跳过无法形成Allan差分的过长聚类。
    end % 结束Allan差分样本数检查。
    allanDifference = clusterAverage(1 + clusterLength:end) - clusterAverage(1:end - clusterLength); % 计算相隔一个平均时间的重叠聚类差分。
    validCount = validCount + 1; % 累加实际有效Allan点数量。
    tauSec(validCount) = clusterLength / sampleRateHz; % 保存当前聚类对应的平均时间。
    allanDeviation(validCount) = sqrt(0.5 * mean(allanDifference .^ 2)); % 按重叠Allan方差定义计算当前平均时间的偏差。
end % 结束Allan聚类长度循环。
tauSec = tauSec(1:validCount); % 删除预分配但未使用的Allan平均时间元素。
allanDeviation = allanDeviation(1:validCount); % 删除预分配但未使用的Allan偏差元素。
end % 结束重叠Allan偏差函数。

function [frequencyHz, powerSpectralDensity] = local_welch_psd(rateData, sampleRateHz, segmentSec, overlapRatio) % 使用Hann窗和重叠分段计算单边Welch功率谱密度。
sampleCount = numel(rateData); % 读取待分析角速度噪声序列样本数。
segmentLength = min(sampleCount, max(32, round(segmentSec * sampleRateHz))); % 根据配置时长确定PSD分段长度并限制到有效数据范围。
overlapLength = floor(segmentLength * overlapRatio); % 计算相邻Welch数据段重叠样本数。
stepLength = max(1, segmentLength - overlapLength); % 计算相邻Welch数据段起点步长。
windowIndex = (0:segmentLength - 1).'; % 生成Hann窗离散样本索引。
hannWindow = 0.5 - 0.5 * cos(2 * pi * windowIndex / max(segmentLength - 1, 1)); % 构造对称Hann窗以降低谱泄漏。
windowEnergy = sum(hannWindow .^ 2); % 计算Hann窗平方和用于保持PSD量纲。
oneSidedLength = floor(segmentLength / 2) + 1; % 计算实序列FFT单边频谱点数。
powerAccumulator = zeros(oneSidedLength, 1); % 初始化Welch单边功率谱累加器。
segmentCount = 0; % 初始化Welch有效数据段计数器。
for startIndex = 1:stepLength:(sampleCount - segmentLength + 1) % 遍历全部能够完整放置的Welch数据段。
    segment = rateData(startIndex:startIndex + segmentLength - 1); % 截取当前Welch角速度数据段。
    segment = segment - mean(segment); % 去除当前数据段均值以抑制直流泄漏。
    spectrum = fft(segment .* hannWindow); % 对加Hann窗的数据段执行离散傅里叶变换。
    twoSidedPsd = abs(spectrum) .^ 2 / (sampleRateHz * windowEnergy); % 计算保持度每秒平方每赫兹量纲的双边PSD。
    oneSidedPsd = twoSidedPsd(1:oneSidedLength); % 截取从直流到奈奎斯特频率的单边PSD。
    if rem(segmentLength, 2) == 0 && oneSidedLength > 2 % 判断偶数长度单边谱是否包含直流与奈奎斯特之外的内部频点。
        oneSidedPsd(2:end - 1) = 2 * oneSidedPsd(2:end - 1); % 偶数长度时保留直流与奈奎斯特点并折叠其余负频率能量。
    elseif rem(segmentLength, 2) ~= 0 && oneSidedLength > 1 % 判断奇数长度单边谱是否包含直流之外的正频率点。
        oneSidedPsd(2:end) = 2 * oneSidedPsd(2:end); % 奇数长度没有独立奈奎斯特点，因此折叠全部非直流正频率点。
    end % 结束奇偶长度单边PSD能量折叠判断。
    powerAccumulator = powerAccumulator + oneSidedPsd; % 累加当前数据段单边功率谱。
    segmentCount = segmentCount + 1; % 累加Welch有效数据段数量。
end % 结束Welch重叠数据段循环。
powerSpectralDensity = powerAccumulator / max(segmentCount, 1); % 对全部Welch数据段的功率谱取平均。
frequencyHz = (0:oneSidedLength - 1).' * sampleRateHz / segmentLength; % 生成单边PSD对应频率坐标。
end % 结束无工具箱Welch功率谱函数。
