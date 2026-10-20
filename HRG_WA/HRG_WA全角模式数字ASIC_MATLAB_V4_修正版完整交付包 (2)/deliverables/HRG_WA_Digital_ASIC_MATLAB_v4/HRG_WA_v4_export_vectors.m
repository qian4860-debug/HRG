function HRG_WA_v4_export_vectors(result, filename) % 导出可供RTL testbench逐拍读取的关键行为向量。
if nargin < 2 || isempty(filename) % 判断调用者是否指定输出文件名。
    filename = 'HRG_WA_v4_vectors.csv'; % 未指定时使用默认CSV文件名。
end % 结束默认文件名判断。
log = result.log; % 取得仿真日志结构体。
fid = fopen(filename, 'w'); % 以文本写模式打开CSV输出文件。
assert(fid >= 0, '无法创建测试向量文件。'); % 检查文件是否成功打开。
cleanup = onCleanup(@() fclose(fid)); % 注册函数退出时自动关闭文件的清理动作。
fprintf(fid, 'sample,time_s,Cx,Sx,Cy,Sy,E,Q,R,S,L,nco_hz,energy_cmd,quad_cmd,virtual_cmd,angle_rad,rate_rad_s,raw_rate_rad_s,comp_rate_rad_s,status,adc_sat,dac_sat,fixed_overflow,pll_limit,pi_int_limit,ctrl_out_limit,unwrap_fault\n'); % 写入包含分层诊断计数的CSV字段标题。
for k = 1:numel(log.t) % 遍历全部控制域采样点。
    fprintf(fid, '%d,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%u,%d,%d,%d,%d,%d,%d,%d\n', k - 1, log.t(k), log.Cx(k), log.Sx(k), log.Cy(k), log.Sy(k), log.E(k), log.Q(k), log.R(k), log.S(k), log.L(k), log.ncoFrequencyHz(k), log.energyCmd(k), log.quadCmd(k), log.virtualCmd(k), log.angleOutput(k), log.rateOutput(k), log.rawRate(k), log.compensatedRate(k), uint32(log.statusWord(k)), log.adcSatCount(k), log.dacSatCount(k), log.fixedOverflowCount(k), log.pllLimitCount(k), log.piIntegratorLimitCount(k), log.controlOutputLimitCount(k), log.unwrapFaultCount(k)); % 写入当前拍的完整对拍向量与分层诊断计数。
end % 结束测试向量导出循环。
end % 结束测试向量导出函数。
