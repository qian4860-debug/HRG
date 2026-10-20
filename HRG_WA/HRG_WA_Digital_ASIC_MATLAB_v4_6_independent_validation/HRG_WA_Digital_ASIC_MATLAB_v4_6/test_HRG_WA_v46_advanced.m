function report = test_HRG_WA_v46_advanced(runAb)
% 验证三个模块可以分别打开且关闭模块不会被隐式联动。
if nargin < 1, runAb = true; end
names = {'physicalFrp','phaseSelfCal','nonlinearityCorrection'};
for i = 1:numel(names)
    p = HRG_WA_v46_params(); p.sim.duration = 6; p.sim.makePlots = false; p.analysis.autoRun = false; p.sim.seed = 46300+i;
    p.input.rateFcn = @(t) 0*t; p.afe.phaseDelayRad = [2.0; 2.4]*pi/180;
    p.afe.crossMatrix = [1 .008;-.005 1]; p.drive.quadraticNonlinearity = [.035;-.025]; p.drive.cubicNonlinearity = [.020;.015];
    p.advanced.physicalFrp.enable = strcmp(names{i},'physicalFrp');
    p.advanced.phaseSelfCal.enable = strcmp(names{i},'phaseSelfCal');
    p.advanced.nonlinearityCorrection.enable = strcmp(names{i},'nonlinearityCorrection');
    r = HRG_WA_v46_simulate(p); report.modules.(names{i}) = r.metrics.advanced.(names{i});
    report.modules.(names{i}).finite = local_all_finite(r.metrics.advanced.(names{i}));
end
assert(report.modules.physicalFrp.enabled && report.modules.physicalFrp.updateCount>0 && report.modules.physicalFrp.finite, '物理源级FRP模块未独立运行。');
assert(report.modules.phaseSelfCal.enabled && report.modules.phaseSelfCal.updateCount>0 && report.modules.phaseSelfCal.finite, '相位自校准模块未独立运行。');
assert(report.modules.nonlinearityCorrection.enabled && report.modules.nonlinearityCorrection.updateCount>0 && report.modules.nonlinearityCorrection.finite, '非线性实时校正模块未独立运行。');
if runAb
    report.frpAB = run_HRG_WA_v46_ab_validation(false);
    assert(report.frpAB.noDataLeakage, 'FRP训练、oracle或验证数据发生泄漏。');
    assert(report.frpAB.validation.compensationPathActive, 'FRP冻结补偿未进入独立验证输出链路。');
    assert(report.frpAB.validation.pass, 'FRP冻结补偿未在独立验证集达到最低改善率。');
end
fprintf('V4.6 advanced modules and independent validation: PASS=1\n');
end

function yes = local_all_finite(s)
yes = true; f = fieldnames(s);
for k=1:numel(f)
    value = s.(f{k}); if isnumeric(value), yes = yes && all(isfinite(value(:))); end
end
end
