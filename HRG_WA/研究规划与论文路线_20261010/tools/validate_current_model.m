% Independent report validation; no source files or historical results overwritten.
out = 'C:\Users\11725\Desktop\HRG_WA\研究规划与论文路线_20261010\evidence';
source = 'C:\Users\11725\Desktop\HRG_WA\HRG_WA_Digital_ASIC_MATLAB_v4_6_5_FRP_validation_fix';
cd(out);
addpath(source, '-begin');
diary(fullfile(out, 'matlab_validation_20261010.log'));
summary.matlabVersion = version;
summary.started = char(datetime('now'));
summary.source = source;
summary.resolvedSimulator = which('HRG_WA_v46_simulate');
summary.resolvedAB = which('run_HRG_WA_v46_ab_validation');
try
    p = HRG_WA_v46_params();
    p.sim.makePlots = false;
    p.analysis.autoRun = false;
    r = HRG_WA_v46_simulate(p);
    summary.baseline = r.metrics;
    save(fullfile(out, 'current_baseline.mat'), 'r');
catch exc
    summary.baselineError = getReport(exc, 'extended', 'hyperlinks', 'off');
end
try
    modules = test_HRG_WA_v46_advanced(false);
    summary.modules = modules;
    save(fullfile(out, 'current_modules.mat'), 'modules');
catch exc
    summary.modulesError = getReport(exc, 'extended', 'hyperlinks', 'off');
end
try
    ab = run_HRG_WA_v46_ab_validation(false);
    summary.ab = ab;
    save(fullfile(out, 'current_ab.mat'), 'ab');
catch exc
    summary.abError = getReport(exc, 'extended', 'hyperlinks', 'off');
end
summary.finished = char(datetime('now'));
fid = fopen(fullfile(out, 'current_validation_summary.json'), 'w', 'n', 'UTF-8');
assert(fid >= 0, 'Cannot open validation summary.');
fprintf(fid, '%s', jsonencode(summary, 'PrettyPrint', true));
fclose(fid);
fprintf('REPORT_VALIDATION_FINISHED\n');
diary off;