function HRG_WA_v42_export_vectors(result, filename) % 导出可供RTL testbench逐拍读取的关键行为向量。
if nargin < 2 || isempty(filename) % 判断调用者是否指定输出文件名。
    filename = 'HRG_WA_v42_vectors.csv'; % 未指定时使用默认CSV文件名。
end % 结束默认文件名判断。
log = result.log; % 取得仿真日志结构体。
fid = fopen(filename, 'w'); % 以文本写模式打开CSV输出文件。
assert(fid >= 0, '无法创建测试向量文件。'); % 检查文件是否成功打开。
cleanup = onCleanup(@() fclose(fid)); % 注册函数退出时自动关闭文件的清理动作。
fprintf(fid, 'sample,time_s,Cx,Sx,Cy,Sy,E,Q,R,S,L,nco_hz,energy_cmd,quad_cmd,virtual_cmd,angle_rad,rate_rad_s,raw_rate_rad_s,comp_rate_rad_s,status,adc_sat,dac_sat,fixed_overflow,pll_limit,pi_int_limit,ctrl_out_limit,unwrap_fault,phase_valid,pll_frozen,pll_freeze_count,anti_windup_active,anti_windup_count,ctrl_slew_count,kalman_angle_rad,kalman_theta_rate_rad_s,kalman_innovation_rad,kalman_p11,kalman_p22,kalman_updated,kalman_reject_count,selftest_active,selftest_done,selftest_passed,selftest_failed,selftest_gain,selftest_quad_ratio,measurement_invalid_reason,actuator_tracking_count\n'); % 写入包含DPLL冻结、完整抗饱和、Kalman和SELFTEST诊断的CSV字段标题。
for k = 1:numel(log.t) % 遍历全部控制域采样点。
    fprintf(fid, '%d,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%u,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%.9g,%.9g,%.9g,%.9g,%.9g,%d,%d,%d,%d,%d,%d,%.9g,%.9g,%u,%d\n', k - 1, log.t(k), log.Cx(k), log.Sx(k), log.Cy(k), log.Sy(k), log.E(k), log.Q(k), log.R(k), log.S(k), log.L(k), log.ncoFrequencyHz(k), log.energyCmd(k), log.quadCmd(k), log.virtualCmd(k), log.angleOutput(k), log.rateOutput(k), log.rawRate(k), log.compensatedRate(k), uint32(log.statusWord(k)), log.adcSatCount(k), log.dacSatCount(k), log.fixedOverflowCount(k), log.pllLimitCount(k), log.piIntegratorLimitCount(k), log.controlOutputLimitCount(k), log.unwrapFaultCount(k), log.phaseValid(k), log.pllFrozen(k), log.pllFreezeCount(k), log.antiWindupActive(k), log.antiWindupCount(k), log.controlSlewLimitCount(k), log.kalmanAngle(k), log.kalmanThetaRate(k), log.kalmanInnovation(k), log.kalmanP11(k), log.kalmanP22(k), log.kalmanUpdated(k), log.kalmanRejectCount(k), log.selftestActive(k), log.selftestDone(k), log.selftestPassed(k), log.selftestFailed(k), log.selftestGainEstimate(k), log.selftestQuadratureRatio(k), uint32(log.measurementInvalidReason(k)), log.actuatorTrackingCount(k)); % 写入当前拍的完整对拍向量与测量可信度分层诊断数据。
end % 结束测试向量导出循环。
end % 结束测试向量导出函数。
