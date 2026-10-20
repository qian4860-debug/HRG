function report = verify_HRG_WA_v4_install() % 检查MATLAB实际解析的V4测试、仿真和参数文件是否属于同一修订版本。
report.testPath = which('test_HRG_WA_v4'); % 取得MATLAB当前优先解析的回归脚本绝对路径。
report.simulatePath = which('HRG_WA_v4_simulate'); % 取得MATLAB当前优先解析的仿真器绝对路径。
report.paramsPath = which('HRG_WA_v4_params'); % 取得MATLAB当前优先解析的参数装载器绝对路径。
assert(~isempty(report.testPath), 'MATLAB路径中找不到test_HRG_WA_v4.m。'); % 检查回归脚本是否可见。
assert(~isempty(report.simulatePath), 'MATLAB路径中找不到HRG_WA_v4_simulate.m。'); % 检查仿真器是否可见。
assert(~isempty(report.paramsPath), 'MATLAB路径中找不到HRG_WA_v4_params.m。'); % 检查参数装载器是否可见。
testText = fileread(report.testPath); % 读取MATLAB实际执行的回归脚本文本。
simulateText = fileread(report.simulatePath); % 读取MATLAB实际调用的仿真器文本。
paramsText = fileread(report.paramsPath); % 读取MATLAB实际调用的参数装载器文本。
report.oldEnergyThresholdPresent = contains(testText, 'p.protect.energyMin = 0.99'); % 检查旧版提前故障门限改写是否仍然存在。
report.explicitLoopFaultPresent = contains(simulateText, 'loopDisableFault'); % 检查显式控制环关闭故障条件是否已经存在。
report.revisionPresent = contains(paramsText, 'V4.1-loopfault-fix-20260713'); % 检查参数文件是否包含本维护版本标识。
report.sameDirectory = strcmp(fileparts(report.testPath), fileparts(report.simulatePath)) && strcmp(fileparts(report.testPath), fileparts(report.paramsPath)); % 检查三个核心文件是否来自同一目录。
fprintf('test路径=%s\n', report.testPath); % 打印实际回归脚本路径供人工检查。
fprintf('simulate路径=%s\n', report.simulatePath); % 打印实际仿真器路径供人工检查。
fprintf('params路径=%s\n', report.paramsPath); % 打印实际参数文件路径供人工检查。
fprintf('旧门限残留=%d，显式loop故障=%d，V4.1标识=%d，同目录=%d\n', report.oldEnergyThresholdPresent, report.explicitLoopFaultPresent, report.revisionPresent, report.sameDirectory); % 打印四项安装一致性结论。
report.ok = ~report.oldEnergyThresholdPresent && report.explicitLoopFaultPresent && report.revisionPresent && report.sameDirectory; % 汇总安装是否满足V4.1回归要求。
assert(report.ok, '检测到旧版或混合路径文件，请切换到独立V4.1目录后执行clear functions和rehash。'); % 在错误安装条件下立即停止，避免输出具有误导性的回归结果。
end % 结束V4安装一致性检查函数。
