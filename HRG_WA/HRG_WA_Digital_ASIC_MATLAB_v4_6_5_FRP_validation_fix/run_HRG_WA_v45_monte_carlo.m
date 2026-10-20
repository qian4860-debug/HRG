function report = run_HRG_WA_v45_monte_carlo(seedCount, user) % 执行多种子并可选器件参数离散的HRG全角数字ASIC Monte Carlo回归。
if nargin < 2 || isempty(user) % 判断调用者是否提供集中式用户参数表头。
    user = HRG_WA_v45_user_config(); % 未提供表头时加载V4.2标称用户配置。
end % 结束Monte Carlo用户参数来源判断。
base = HRG_WA_v45_params(user); % 把用户表头转换为完整内部参数结构体。
if nargin < 1 || isempty(seedCount) % 判断调用者是否显式指定Monte Carlo运行次数。
    seedCount = base.monteCarlo.seedCount; % 未指定时使用参数表头中的正式默认种子数量。
end % 结束Monte Carlo运行次数来源判断。
assert(seedCount >= 1 && seedCount == round(seedCount), 'seedCount必须是正整数。'); % 检查Monte Carlo运行次数是否为正整数。
seeds = (base.monteCarlo.firstSeed:base.monteCarlo.firstSeed + seedCount - 1).'; % 生成可复现且互不相同的随机种子列表。
passed = false(seedCount, 1); % 预分配每组Monte Carlo性能回归通过标志。
lockTimeSec = NaN(seedCount, 1); % 预分配每组闭环锁定时间。
angleRmsDeg = NaN(seedCount, 1); % 预分配每组角度RMS误差。
rateRmsDps = NaN(seedCount, 1); % 预分配每组角速度RMS误差。
maximumRateErrorDps = NaN(seedCount, 1); % 预分配每组最大角速度误差。
kalmanRejectCount = NaN(seedCount, 1); % 预分配每组Kalman创新拒绝次数。
fixedOverflowCount = NaN(seedCount, 1); % 预分配每组真实定点溢出次数。
unwrapFaultCount = NaN(seedCount, 1); % 预分配每组四倍角展开异常次数。
qScale = ones(seedCount, 1); % 预分配每组机械Q值相对比例。
splitScale = ones(seedCount, 1); % 预分配每组频率裂解相对比例。
dampingScale = ones(seedCount, 1); % 预分配每组阻尼不均匀相对比例。
for i = 1:seedCount % 逐个执行独立随机种子和器件参数离散用例。
    p = base; % 为当前Monte Carlo样本复制一份独立完整参数。
    p.sim.seed = seeds(i); % 设置当前闭环噪声仿真的确定性随机种子。
    rng(seeds(i), 'twister'); % 设置参数离散使用的确定性随机数流。
    if p.monteCarlo.enableParameterSpread % 判断是否同时施加器件和接口参数高斯离散。
        qScale(i) = max(0.20, 1 + p.monteCarlo.qRelativeSigma * randn); % 生成带正值保护的机械Q值相对比例。
        splitScale(i) = max(0, 1 + p.monteCarlo.frequencySplitRelativeSigma * randn); % 生成带非负保护的频率裂解相对比例。
        dampingScale(i) = max(0, 1 + p.monteCarlo.dampingAnisotropyRelativeSigma * randn); % 生成带非负保护的阻尼不均匀相对比例。
        p.res.Q = base.res.Q * qScale(i); % 应用当前样本机械Q值离散。
        p.res.meanDamping = pi * p.res.f0 / p.res.Q; % 根据离散后的机械Q值重新计算平均阻尼率。
        p.res.frequencySplitHz = base.res.frequencySplitHz * splitScale(i); % 应用当前样本频率裂解离散。
        p.res.dampingAnisotropy = base.res.dampingAnisotropy * dampingScale(i); % 应用当前样本阻尼不均匀离散。
        p.afe.crossMatrix = base.afe.crossMatrix + diag(p.monteCarlo.afeGainSigma * randn(2, 1)); % 向两检测通道叠加独立增益离散。
        p.afe.offset = base.afe.offset + p.monteCarlo.afeOffsetSigma * randn(2, 1); % 向两检测通道叠加独立直流偏置离散。
        p.dac.gain = base.dac.gain .* (1 + p.monteCarlo.dacGainSigma * randn(3, 1)); % 向三路执行通道叠加独立增益离散。
    end % 结束器件与接口参数离散判断。
    validation = HRG_WA_v45_validate_params(p, false); % 在仿真前检查当前随机参数样本的一致性与动态范围。
    assert(validation.ok, 'Monte Carlo第%d组随机参数违反致命参数约束。', i); % 阻止非法随机参数进入闭环仿真。
    result = HRG_WA_v45_simulate(p); % 运行当前随机样本的多速率闭环行为仿真。
    metrics = result.metrics; % 读取当前随机样本的分层性能指标。
    passed(i) = metrics.passPerformance; % 保存当前样本完整标称性能回归通过标志。
    lockTimeSec(i) = metrics.lockTime; % 保存当前样本闭环锁定时间。
    angleRmsDeg(i) = metrics.rmsAngleErrorDeg; % 保存当前样本角度RMS误差。
    rateRmsDps(i) = metrics.rmsRateErrorDps; % 保存当前样本角速度RMS误差。
    maximumRateErrorDps(i) = metrics.maxRateErrorDps; % 保存当前样本最大角速度误差。
    kalmanRejectCount(i) = metrics.kalmanRejectCount; % 保存当前样本Kalman创新拒绝次数。
    fixedOverflowCount(i) = metrics.fixedOverflowCount; % 保存当前样本真实定点溢出次数。
    unwrapFaultCount(i) = metrics.unwrapFaultCount; % 保存当前样本四倍角展开异常次数。
    fprintf('MC %02d/%02d seed=%d PASS=%d lock=%.4fs angleRMS=%.6gdeg rateRMS=%.6gdeg/s reject=%d\n', i, seedCount, seeds(i), passed(i), lockTimeSec(i), angleRmsDeg(i), rateRmsDps(i), kalmanRejectCount(i)); % 打印当前Monte Carlo样本摘要。
end % 结束Monte Carlo随机样本循环。
report.modelRevision = base.meta.revision; % 记录Monte Carlo对应的模型修订标识。
report.seedCount = seedCount; % 记录实际执行的随机样本数量。
report.seeds = seeds; % 保存全部确定性随机种子。
report.passed = passed; % 保存每组完整性能回归通过标志。
report.passRate = mean(double(passed)); % 计算Monte Carlo性能回归通过率。
report.minimumRequiredPassRate = base.monteCarlo.minimumPassRate; % 记录配置要求的最低通过率。
report.pass = report.passRate >= report.minimumRequiredPassRate; % 判断Monte Carlo总体通过率是否满足配置门限。
report.lockTimeSec = lockTimeSec; % 保存每组闭环锁定时间。
report.angleRmsDeg = angleRmsDeg; % 保存每组角度RMS误差。
report.rateRmsDps = rateRmsDps; % 保存每组角速度RMS误差。
report.maximumRateErrorDps = maximumRateErrorDps; % 保存每组最大角速度误差。
report.kalmanRejectCount = kalmanRejectCount; % 保存每组Kalman创新拒绝次数。
report.fixedOverflowCount = fixedOverflowCount; % 保存每组真实定点溢出次数。
report.unwrapFaultCount = unwrapFaultCount; % 保存每组四倍角展开异常次数。
report.qScale = qScale; % 保存每组机械Q值相对比例。
report.splitScale = splitScale; % 保存每组频率裂解相对比例。
report.dampingScale = dampingScale; % 保存每组阻尼不均匀相对比例。
report.summary.lockMeanSec = mean(lockTimeSec); % 计算Monte Carlo锁定时间均值。
report.summary.lockMaximumSec = max(lockTimeSec); % 计算Monte Carlo锁定时间最大值。
report.summary.angleRmsMeanDeg = mean(angleRmsDeg); % 计算Monte Carlo角度RMS误差均值。
report.summary.angleRmsP95Deg = local_percentile(angleRmsDeg, 95); % 计算Monte Carlo角度RMS误差第九十五百分位。
report.summary.rateRmsMeanDps = mean(rateRmsDps); % 计算Monte Carlo角速度RMS误差均值。
report.summary.rateRmsP95Dps = local_percentile(rateRmsDps, 95); % 计算Monte Carlo角速度RMS误差第九十五百分位。
report.summary.rateRmsMaximumDps = max(rateRmsDps); % 计算Monte Carlo角速度RMS误差最大值。
report.summary.totalFixedOverflow = sum(fixedOverflowCount); % 计算全部随机样本真实定点溢出总次数。
report.summary.totalUnwrapFault = sum(unwrapFaultCount); % 计算全部随机样本四倍角展开异常总次数。
fprintf('Monte Carlo通过率=%.2f%%，要求>=%.2f%%，角度RMS P95=%.6gdeg，角速度RMS P95=%.6gdeg/s，总体PASS=%d\n', 100 * report.passRate, 100 * report.minimumRequiredPassRate, report.summary.angleRmsP95Deg, report.summary.rateRmsP95Dps, report.pass); % 打印Monte Carlo总体可信度摘要。
save('HRG_WA_v45_monte_carlo_result.mat', 'report', 'base'); % 保存可复现的Monte Carlo完整结果和基准参数。
local_write_csv('HRG_WA_v45_monte_carlo_result.csv', report); % 导出便于版本比较和统计绘图的Monte Carlo CSV表。
end % 结束多种子与参数离散Monte Carlo回归函数。

function value = local_percentile(data, percentile) % 使用线性插值计算不依赖统计工具箱的样本百分位数。
sortedData = sort(data(isfinite(data))); % 提取有限样本并按升序排列。
if isempty(sortedData) % 判断是否没有任何有限样本可供计算。
    value = NaN; % 无有限样本时返回非数值。
    return; % 结束当前百分位数计算。
end % 结束空有限样本判断。
position = 1 + (numel(sortedData) - 1) * percentile / 100; % 计算目标百分位在排序样本中的连续位置。
lowerIndex = floor(position); % 取得目标位置下侧样本索引。
upperIndex = ceil(position); % 取得目标位置上侧样本索引。
fraction = position - lowerIndex; % 计算上下相邻样本之间的线性插值比例。
value = sortedData(lowerIndex) * (1 - fraction) + sortedData(upperIndex) * fraction; % 对相邻排序样本执行线性插值得到百分位数。
end % 结束无工具箱百分位数函数。

function local_write_csv(filename, report) % 将Monte Carlo逐样本结果写入CSV文件。
fid = fopen(filename, 'w'); % 以文本写模式创建Monte Carlo CSV输出文件。
assert(fid >= 0, '无法创建Monte Carlo CSV文件。'); % 检查CSV输出文件是否成功打开。
cleanup = onCleanup(@() fclose(fid)); % 注册函数退出时自动关闭CSV文件的清理动作。
fprintf(fid, 'index,seed,pass,lock_s,angle_rms_deg,rate_rms_dps,max_rate_error_dps,kalman_reject,fixed_overflow,unwrap_fault,q_scale,split_scale,damping_scale\n'); % 写入Monte Carlo CSV字段标题。
for i = 1:report.seedCount % 遍历全部Monte Carlo随机样本。
    fprintf(fid, '%d,%d,%d,%.9g,%.9g,%.9g,%.9g,%d,%d,%d,%.9g,%.9g,%.9g\n', i, report.seeds(i), report.passed(i), report.lockTimeSec(i), report.angleRmsDeg(i), report.rateRmsDps(i), report.maximumRateErrorDps(i), report.kalmanRejectCount(i), report.fixedOverflowCount(i), report.unwrapFaultCount(i), report.qScale(i), report.splitScale(i), report.dampingScale(i)); % 写入当前Monte Carlo随机样本全部统计字段。
end % 结束Monte Carlo CSV逐样本写入循环。
end % 结束Monte Carlo CSV导出函数。
