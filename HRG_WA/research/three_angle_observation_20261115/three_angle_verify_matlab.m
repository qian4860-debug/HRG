function result = three_angle_verify_matlab(outDir)
% 三种拓扑、零速及非零速下验证全角观测、门控、信号单位与原接口兼容。
arguments
    outDir (1,:) char = fileparts(mfilename('fullpath'))
end
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here,'..','three_mode_split_20261113'));
result = struct('release',version('-release'), ...
    'scope','Three-angle MATLAB closed-loop diagnostic; mechanical reference is model state', ...
    'nominal',[],'overload',[],'missing_frame_probe',[]);
modes = ["continuous","tdm_separate","tdm_shared"];
for mode = modes
    for point = [0 .05;.5 0;-.05 .05]'
        rate = point(1);
        split = point(2);
        c = three_mode_split_config(mode,rate,split,22.5,.04,16);
        [t,trace,frames,adc,cand] = five_reference(c);
        [t0,trace0,frames0,adc0] = five_reference(c);
        assert(isequal(t,t0) && isequal(trace,trace0) && ...
            isequal(frames,frames0) && isequal(adc,adc0),'旁路观测改变了原闭环输出。');
        accepted = cand(:,8)==1;
        assert(isequal(cand(accepted,[1 9 10]),frames(:,[1 15 16])), ...
            '角观测的发布时间、发布角与已发布帧不同。');
        [series,metrics] = three_angle_series(c,cand,.01);
        assert(metrics.expected_candidates==metrics.observed_candidates);
        assert(metrics.common_scored_candidates==metrics.score_candidates);
        assert(all(~isnan(series.published_minus_truth_rad(series.common_scored))));
        assert(abs(metrics.total_slope_error_rad_s-metrics.mechanical_slope_error_rad_s- ...
            metrics.readout_slope_error_rad_s-metrics.publication_slope_error_rad_s)<1e-10);
        metrics.split_Hz = split;
        metrics.initial_beta_deg = 22.5;
        metrics.original_outputs_exact = true;
        result.nominal = [result.nominal;metrics]; %#ok<AGROW>
        % 用连续模式检验缺帧后显示断开，而不是重新选取数据锚点。
        if mode=="continuous" && rate==.5
            eligible = find(series.common_scored);
            mid = eligible(6);
            disrupted = cand;
            disrupted(mid,:) = [];
            [disruptedSeries,summary] = three_angle_series(c,disrupted,.01);
            assert(summary.common_scored_candidates==5);
            assert(all(isnan(disruptedSeries.published_minus_truth_rad(mid:end))));
            result.missing_frame_probe = struct('after_anchor_frames', ...
                summary.common_scored_candidates,'missing_candidates', ...
                summary.expected_candidates-summary.observed_candidates);
        end
        if rate==0 && split==.05 && ~isempty(outDir)
            if ~isfolder(outDir), mkdir(outDir); end
            name = sprintf('%s_zero_split_angles.csv',mode);
            writetable(series,fullfile(outDir,name));
        end
    end
    % 人工降低 ADC 限幅阈值。机械/CV 参考仍可观察，闭环不发布。
    c = three_mode_split_config(mode,.05,.05,22.5,.006,16);
    c.adcMin = -2*c.adcStep;
    c.adcMax = 2*c.adcStep;
    [~,~,frames,~,cand] = five_reference(c);
    [series,metrics] = three_angle_series(c,cand);
    assert(isempty(frames) && any(series.mechanical_usable) && any(series.clean_cv_usable));
    assert(~any(series.closed_usable) && metrics.common_scored_candidates==0 && ...
        isnan(metrics.total_rms_rad));
    result.overload = [result.overload;metrics]; %#ok<AGROW>
end
if ~isempty(outDir)
    fid = fopen(fullfile(outDir,'matlab_verification.json'),'w','n','UTF-8');
    assert(fid>=0,'无法写入 MATLAB 三角观测回执。');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid,'%s\n',jsonencode(result,'PrettyPrint',true));
end
end
