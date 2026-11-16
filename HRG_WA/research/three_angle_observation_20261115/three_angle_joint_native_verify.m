function result = three_angle_joint_native_verify(outPath,outDir,profile)
% 比较原生与 MATLAB 闭环逐拍行为，并检验因果 DAC 整形控制。
arguments
    outPath (1,:) char = fullfile(fileparts(mfilename('fullpath')),'joint_native_verification.json')
    outDir (1,:) char = fullfile(fileparts(mfilename('fullpath')),'joint_models')
    profile (1,1) struct = three_angle_joint_profile()
end
models = three_angle_joint_native_build(outDir,profile);
for k = 1:numel(models), load_system(fullfile(outDir,[models{k} '.slx'])); end
cleanup = onCleanup(@() closeModels(models)); %#ok<NASGU>
for k = 1:numel(models)
    blocks = find_system(models{k},'LookUnderMasks','all','FollowLinks','on','Type','Block');
    types = get_param(blocks,'BlockType');
    assert(~any(ismember(types,{'MATLABFcn','InterpretedMATLABFcn', ...
        'S-Function','MATLABSystem','FromWorkspace'})));
    assert(isempty(find_system(models{k},'SFBlockType','MATLAB Function')));
end

rateBudget = .25e-3;
short = three_angle_joint_closed_config(profile,0,.05,22.5,.012,16);
[shortParity,~] = compareClosed(models{3},short,0,rateBudget,true);
suite = {
    'nominal',     22.5, 0,    .05, 16, .12, .04, struct()
    'mirrored',    67.5, 0,    .05, 16, .06, .02, struct()
    'nonzero_rate',22.5, .05,  .05, 16, .06, .02, struct()
    'cap_corner',  22.5, 0,    .05, 16, .06, .02, struct('Cs',720e-12)
    };
scenarioRows = {};
comparisons = {};
for k = 1:size(suite,1)
    [scenario,beta,rate,split,bits,duration,scoreStart,extra] = deal(suite{k,:});
    dedicated = three_mode_split_config('tdm_separate',rate,split,beta,duration,bits,extra);
    baseline = three_mode_split_config('tdm_shared',rate,split,beta,duration,bits,extra);
    shaped = three_angle_joint_closed_config(profile,rate,split,beta,duration,bits,extra,true);
    bleed = rmfield(shaped,'dacShape');
    cfgs = {dedicated,baseline,bleed,shaped};
    labels = {'dedicated','shared_15k','shared_optimized_bleed_only','shared_bleed_and_shape'};
    paths = models([1 2 2 3]);
    series = cell(1,numel(cfgs));
    for row = 1:numel(cfgs)
        [score,series{row}] = compareClosed(paths{row},cfgs{row},scoreStart,rateBudget,false);
        score.scenario = scenario;
        score.condition_beta_deg = beta;
        score.mode = labels{row};
        scenarioRows{end+1} = score; %#ok<AGROW>
        fprintf('%s %s: total error %.5g mrad/s, %d / %d releases, DAC limit %d\n', ...
            scenario,labels{row},score.total_slope_error_mrad_s, ...
            score.accepted_candidates,score.expected_candidates,score.dac_limiting_ticks);
    end
    comparisons{end+1} = crossTopology(scenario,labels,series); %#ok<AGROW>
end

% 开启整形且系数全零时，转换器码与候选/发布帧均应逐拍复现基线。
c = three_mode_split_config('tdm_shared',0,.05,22.5,.012,16);
c.logDecimation = 1;
zero = c;
zero.dacShape = struct('coeffs',zeros(size(profile.coeffs)),'taus_s',profile.taus_s);
legacyRun = nativeRun(models{2},c);
zeroRun = nativeRun(models{3},zero);
[~,baseRef,baseFrames,~,baseAngles] = five_reference(c,false);
[~,zeroRef,zeroFrames,~,zeroAngles] = five_reference(zero,false);
assert(isequal(legacyRun.trace,zeroRun.trace) && isequal(legacyRun.frames,zeroRun.frames) && ...
    isequal(legacyRun.angleCandidates,zeroRun.angleCandidates), ...
    'An explicit zero profile changed native baseline outputs.');
assert(isequal(baseRef,zeroRef) && isequal(baseFrames,zeroFrames) && ...
    isequal(baseAngles,zeroAngles),'An explicit zero profile changed MATLAB baseline.');
seeded = three_angle_joint_closed_config(profile,0,.05,22.5,.012,16);
seeded.p.seed_enabled = true;
seeded.p.seed_seconds = (2*seeded.frame-.5)*seeded.Ts;
seeded.seedCommand = [2*seeded.dacMax;0;0;0];
seeded.logDecimation = 1;
[startup,~] = compareClosed(models{3},seeded,0,rateBudget,true);
startupRun = nativeRun(models{3},seeded);
withoutShape = nativeRun(models{2},rmfield(seeded,'dacShape'));
seed = (0:size(startupRun.trace,1)-1)'*seeded.Ts < seeded.p.seed_seconds;
assert(startup.dac_limiting_ticks>0 && ...
    isequal(startupRun.trace(seed,7:8),withoutShape.trace(seed,7:8)), ...
    'Shaping must bypass the forced startup seed and retain rail diagnostics.');
startup.mode = 'shared_bleed_and_shape';
result = struct('release',version('-release'),'status','passed', ...
    'scope','Native and MATLAB parity for causal closed-loop shaped DAC and frozen bleed resistance', ...
    'profile',profile,'rate_error_budget_rad_s',rateBudget,'cases',{[scenarioRows{:}]}, ...
    'cross_topology',{[comparisons{:}]},'startup_seed_bypass',startup, ...
    'shaped_short_exact_parity',shortParity,'zero_shape_full_trace_and_frames_equal',true);
if ~isempty(outPath)
    fid = fopen(outPath,'w','n','UTF-8');
    assert(fid>=0,'Could not write native closed-loop verification.');
    receipt = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid,'%s\n',jsonencode(result,'PrettyPrint',true));
end
end

function [stats,series] = compareClosed(model,c,scoreStart,rateBudget,exactCodes)
c.logDecimation = 1;
[~,expected,frames,analog,candidate] = five_reference(c,true);
out = nativeRun(model,c);
assert(isequal(size(out.trace),size(expected)) && isequal(size(out.frames),size(frames)));
eventColumns = [1:4 9 15 20:22];
assert(isequal(out.trace(:,eventColumns),expected(:,eventColumns)), ...
    'Native and reference differ in discrete control events.');
codeMismatch = out.trace(:,5:8)~=expected(:,5:8);
firstCodeDifference = find(any(codeMismatch,2),1);
if isempty(firstCodeDifference), firstCodeDifference = -1; end
if exactCodes
    assert(~any(codeMismatch,'all'),'Short native and reference converter codes differ.');
end
assert(isequal(size(out.angleCandidates),size(candidate)) && ...
    isequal(out.angleCandidates(:,[5:8 10]),candidate(:,[5:8 10])));
delta = out.angleCandidates(:,2:4)-candidate(:,2:4);
maxAngle = max([0;abs(atan2(sin(delta(:)),cos(delta(:))))]);
traceError = maxDifference(out.trace,expected);
framesError = maxDifference(out.frames,frames);
if exactCodes
    assert(traceError<1e-8 && framesError<1e-8 && maxAngle<1e-8);
else
    fprintf('  max trace %.3g, frames %.3g, azimuth %.3g; converter mismatches %d, first row %d\n', ...
        traceError,framesError,maxAngle,nnz(codeMismatch),firstCodeDifference);
end
[series,metrics] = three_angle_series(c,out.angleCandidates,scoreStart);
[~,referenceMetrics] = three_angle_series(c,candidate,scoreStart);
assert(metrics.observed_candidates==metrics.expected_candidates);
assert(all(isfinite(out.trace),'all') && all(isfinite(analog),'all'));

steady = series.common_scored;
numbers = abs(analog(logical(analog(:,2)),3:4));
sampleCodes = out.trace(:,5:6);
drive = logical(out.trace(:,2));
stats = struct('bleed_R_ohm',c.p.bleed_R,'group_capacitance_F',diag(c.portCapacitance_F)', ...
    'split_Hz',c.p.split_hz,'body_rate_rad_s',c.omega,'adc_bits',c.p.adc_bits, ...
    'dac_bits',c.p.dac_bits,'duration_s',c.duration,'score_start_s',scoreStart, ...
    'expected_candidates',metrics.expected_candidates, ...
    'accepted_candidates',metrics.accepted_candidates,'joint_scored_candidates',nnz(steady), ...
    'joint_score_candidates_expected',metrics.score_candidates, ...
    'tracking_lost',any(out.trace(:,21)),'adc_limiting_ticks',nnz(out.trace(:,20)), ...
    'dac_limiting_ticks',nnz(out.trace(:,22)),'drive_ticks',nnz(drive), ...
    'max_dac_V',max(abs(out.trace(:,7:8)),[],'all'), ...
    'min_adc_V',min(sampleCodes,[],'all'),'max_adc_V',max(sampleCodes,[],'all'), ...
    'mean_abs_cv_by_axis_V',mean(numbers,1),'peak_abs_cv_by_axis_V',max(numbers,[],1), ...
    'nearest_adc_rail_margin_V',min(c.adcMax-max(analog(:,5:6),[],'all'), ...
    min(analog(:,5:6),[],'all')-c.adcMin), ...
    'mechanical_slope_error_mrad_s',1000*metrics.mechanical_slope_error_rad_s, ...
    'readout_slope_error_mrad_s',1000*metrics.readout_slope_error_rad_s, ...
    'publication_slope_error_mrad_s',1000*metrics.publication_slope_error_rad_s, ...
    'total_slope_error_mrad_s',1000*metrics.total_slope_error_rad_s, ...
    'reference_total_slope_error_mrad_s',1000*referenceMetrics.total_slope_error_rad_s, ...
    'total_error_below_absolute_rate_budget',abs(metrics.total_slope_error_rad_s)<=rateBudget, ...
    'total_rms_rad',metrics.total_rms_rad,'max_candidate_azimuth_delta_rad',maxAngle, ...
    'max_trace_delta',traceError,'max_frames_delta',framesError,'event_flags_equal',true, ...
    'converter_code_mismatch_count',nnz(codeMismatch), ...
    'first_converter_code_mismatch_row',firstCodeDifference);
end

function comparison = crossTopology(scenario,labels,series)
reference = series{1};
rows = cell(1,numel(series)-1);
for k = 2:numel(series)
    variant = series{k};
    assert(isequal(reference.t_center_s,variant.t_center_s));
    joint = reference.common_scored & variant.common_scored;
    errors = nan(1,3);
    if nnz(joint)>=2
        first = find(joint,1);
        columns = {'mechanical_body_rel_rad','clean_cv_body_rel_rad','published_body_rel_rad'};
        for j = 1:numel(columns)
            a = reference.(columns{j});
            b = variant.(columns{j});
            d = (b(joint)-b(first))-(a(joint)-a(first));
            p = polyfit(reference.t_center_s(joint)-reference.t_center_s(first),d,1);
            errors(j) = 1000*p(1);
        end
    end
    rows{k-1} = struct('mode',labels{k},'common_scored_frames',nnz(joint), ...
        'mechanical_slope_delta_mrad_s',errors(1),'clean_cv_slope_delta_mrad_s',errors(2), ...
        'published_slope_delta_mrad_s',errors(3));
end
comparison = struct('scenario',scenario,'reference_mode',labels{1},'cases',[rows{:}]);
end

function out = nativeRun(model,c)
input = Simulink.SimulationInput(model);
input = input.setVariable('c',c,'Workspace',model);
input = input.setModelParameter('SaveTime','off');
out = sim(input);
end

function delta = maxDifference(a,b)
delta = max([0;abs(a(:)-b(:))]);
end

function closeModels(models)
for k = 1:numel(models), close_system(models{k},0); end
end
