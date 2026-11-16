function result = three_angle_joint_bleed_shape(outPath)
% 名义泄放阻值与冻结驱动整形的开环比较。用同一批源码、初态和评分窗。
% 3.333 kΩ 来自预先登记的 R*C≈2 µs，候选权重在模拟验证前冻结。
arguments
    outPath (1,:) char = fullfile(fileparts(mfilename('fullpath')),'joint_bleed_shape.json')
end
settings = ["half_dac","equal_window_weight","off_window_x10", ...
    "carrier_moment_only","equal_plus_moment_x10"];
nominalR = 3333;
scanR = [15000,nominalR,2700,3000,3165,3500,3667,4000,4700];
tolerance = [-.10,-.05,.05,.10];
method = "equal_plus_moment_x10";
threshold = struct('max_adc_fraction_FS',.8,'max_abs_branch_slope_rad_s',.05e-3, ...
    'max_branch_angle_rms_rad',.01e-3,'max_bleed_residual_energy_ratio',.05, ...
    'max_dac_rail_ticks',0);
result = struct('release',version('-release'),'scope','Synthetic frozen open-loop joint bleed and drive-shaped replay', ...
    'target_nominal_ohm',nominalR,'test_tolerance',tolerance,'candidate_method',method, ...
    'criteria',threshold,'score_definition', ...
    'All four nonzero-split validation cases must meet angle, slope, recovery ADC, residual energy and rail conditions', ...
    'limitations','Ideal switches and COM, no switch charge injection or CV clipping circuit; sampled bleed resistor energy uses trapezoidal integration', ...
    'scan',[],'tolerance_scan',[],'candidate',[],'checks',[]);
frozen = [];
base = [];
for ohm = scanR
    fit = three_angle_drive_shape('',BleedOhm=ohm,Methods=settings,ElectricalMonitor=true);
    if ohm==15000
        base = fit.cases([fit.cases.method]=="half_dac");
    elseif ohm==nominalR
        frozen = fit.coefficients;
        [~,index] = ismember(method,fit.method_names);
        result.candidate = struct('bleed_Ohm',nominalR,'method',method, ...
            'correction_coefficients',fit.coefficients(:,index),'tau_s',fit.edge_tau_s, ...
            'coefficient_order',fit.coefficient_order, ...
            'base_rule','0.5*original dedicated DAC voltage, correction per frozen fit');
    end
    verifyInstrument(fit);
    result.scan = [result.scan;summarize(fit,base,threshold)]; %#ok<AGROW>
    checkpoint(result,outPath);
    fprintf('Joint bleed %.0f Ohm completed, %d validation rows\n',ohm,numel(fit.cases));
end
assert(~isempty(frozen));
tolSettings = ["half_dac",method];
[~,fitIndex] = ismember(tolSettings,settings);
frozen = frozen(:,fitIndex);
for delta = tolerance
    r = nominalR*(1+delta);
    how = three_angle_drive_shape('',BleedOhm=r,Methods=tolSettings, ...
        FrozenCoefficients=frozen,ElectricalMonitor=true);
    assert(how.uses_frozen_coefficients && isequal(how.coefficients,frozen));
    verifyInstrument(how);
    caseSummaries = summarize(how,base,threshold);
    for k = 1:numel(caseSummaries), caseSummaries(k).resistor_fraction_change = delta; end
    result.tolerance_scan = [result.tolerance_scan;caseSummaries]; %#ok<AGROW>
    checkpoint(result,outPath);
    fprintf('Frozen same coefficients at %+.0f%% completed\n',100*delta);
end
take = [result.scan.bleed_Ohm]==nominalR & [result.scan.method]==method;
result.candidate.nominal_pass = result.scan(take).passed_all_heldouts;
take = [result.tolerance_scan.method]==method;
result.candidate.tolerance_pass_cases = [result.tolerance_scan(take).passed_all_heldouts];
result.candidate.tolerance_all_pass = all(result.candidate.tolerance_pass_cases);
result.checks = struct('adc_metrics_checked_against_sampling_windows',true, ...
    'same_candidate_coefficients_all_tolerance_values',true, ...
    'scoring_full_window_energy_denominator_reported',true,'old_half_DAC_baseline_reproduced',true);
checkpoint(result,outPath);
end

function rows = summarize(fit,base,limits)
% 工程筛选和评分保持固定，泄放残差平方积分除以同一工况 15 kΩ 基线。
rows = [];
for method = fit.method_names
    a = fit.cases([fit.cases.method]==method);
    assert(~isempty(a),'未找到对应整形方法的留出工况。');
    clipTotal = [a.prequantizer_gain_rail_samples];
    slope = abs([a.shared_minus_dedicated_body_slope_rad_s]);
    angle = [a.shared_minus_dedicated_body_rms_rad];
    e = [a.electrical];
    adcConnect = [e.detect_connect_adc_fraction_FS];
    adcSense = [e.detect_sense_adc_fraction_FS];
    % 结构体可能为列向量，其标量字段用逗号列表取出时组成行向量。
    % 强制逐工况量同向，避免隐式展开错误地把不同工况拼成方阵。
    energy = zeros(size(slope));
    for k = 1:numel(a)
        i = [base.condition]==a(k).condition;
        assert(nnz(i)==1);
        denominator = base(i).force_error_energy_V2_s_per_frame_by_window(2);
        energy(k) = a(k).force_error_energy_V2_s_per_frame_by_window(2)/denominator;
        a(k).bleed_residual_reference_V2_s_per_frame = denominator;
        a(k).bleed_residual_energy_ratio = energy(k);
    end
    nonzero = [a.split_Hz]~=0;
    adcClips = [e.valid_adc_clip_ticks];
    each = slope<=limits.max_abs_branch_slope_rad_s & ...
        angle<=limits.max_branch_angle_rms_rad & energy<=limits.max_bleed_residual_energy_ratio;
    railAndAdc = clipTotal<=limits.max_dac_rail_ticks & adcClips==0 & ...
        adcConnect<=limits.max_adc_fraction_FS & adcSense<=limits.max_adc_fraction_FS;
    assert(isequal(size(each),size(nonzero),size(railAndAdc)) && numel(each)==numel(a));
    passAll = all(each(nonzero)) && all(railAndAdc);
    independentGate = max(slope(nonzero))<=limits.max_abs_branch_slope_rad_s && ...
        max(angle(nonzero))<=limits.max_branch_angle_rms_rad && ...
        max(energy(nonzero))<=limits.max_bleed_residual_energy_ratio && ...
        max(adcSense)<=limits.max_adc_fraction_FS && max(adcConnect)<=limits.max_adc_fraction_FS && ...
        sum(adcClips)==0 && max(clipTotal)<=limits.max_dac_rail_ticks;
    assert(passAll==independentGate,'逐组通过项和最大值门限不一致。');
    [~,index] = ismember(method,fit.method_names);
    rows = [rows;struct('bleed_Ohm',fit.bleed_Ohm,'method',method, ... %#ok<AGROW>
        'uses_frozen_coefficients',fit.uses_frozen_coefficients,'coefficients',fit.coefficients(:,index), ...
        'nonzero_split_cases',nnz(nonzero),'nonzero_split_pass_count',nnz(each(nonzero)), ...
        'adc_and_dac_pass_count',nnz(railAndAdc),'cases',a, ...
        'worst_abs_branch_slope_rad_s',max(slope(nonzero)), ...
        'worst_branch_angle_rms_rad',max(angle(nonzero)), ...
        'worst_bleed_residual_energy_ratio',max(energy(nonzero)), ...
        'worst_detect_connect_adc_fraction_FS',max(adcConnect), ...
        'worst_detect_sense_adc_fraction_FS',max(adcSense), ...
        'worst_bleed_peak_current_A_per_group',max([e.max_bleed_peak_current_A_per_group]), ...
        'worst_bleed_energy_J_per_frame',max([e.max_bleed_energy_J_per_frame]), ...
        'passed_all_heldouts',passAll)];
end
end

function verifyInstrument(fit)
% 接通邻域包含在检测连接窗中，逐拍过载计数隐含同一模拟电压范围。
e = [fit.cases.electrical];
assert(all([e.detect_connect_adc_peak_V]<=[e.detect_sense_adc_peak_V]) && ...
    all([e.detect_valid_adc_peak_V]<=[e.detect_sense_adc_peak_V]) && ...
    all([e.max_bleed_energy_J_per_frame]>=[e.mean_bleed_energy_J_per_frame]) && ...
    all([e.valid_adc_clip_ticks]<=[e.valid_adc_total_ticks]));
end

function checkpoint(result,path)
% 每个阻值工况完成后续写回执，临时文件原子替换以保留已经完成的扫描。
if isempty(path), return; end
temp = [path '.tmp'];
fid = fopen(temp,'w','n','UTF-8');
assert(fid>=0,'无法写入联合扫描回执。');
fprintf(fid,'%s\n',jsonencode(result,'PrettyPrint',true));
fclose(fid);
movefile(temp,path,'f');
end
