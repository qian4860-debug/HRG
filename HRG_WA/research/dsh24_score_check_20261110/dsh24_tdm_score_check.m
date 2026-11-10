function result = dsh24_tdm_score_check(outputPath)
% Isolate timestamp, window/anchor and ADC quantization in the nominal TDM case.
starts = [.04 .06 .08 .10 .15];
result = struct('scope','MATLAB reference only, nominal TDM at 0.5 rad/s', ...
    'duration_s',.35,'starts_s',starts,'cases',[]);
for bits = [10 20]
    c = five_config('tdm_shared',.5,struct('duration',.35,'adc_bits',bits,'log_decimation',200));
    [~,trace,frames] = five_reference(c);
    assert(~any(trace(:,21)) && size(frames,1)>550);
    t = frames(:,1);
    angle = frames(:,15);
    delay = (c.validEnd+c.adcLatency-(c.validStart+c.validEnd-1)/2)*c.Ts;
    center = t-delay;
    r = struct('adc_bits',bits,'center_to_publication_s',delay, ...
        'rms_reanchored_rad',zeros(size(starts)), ...
        'rms_fixed_anchor_rad',zeros(size(starts)), ...
        'rms_same_samples_reanchored_rad',zeros(size(starts)), ...
        'max_timestamp_effect_rad',0);
    anchor = find(t>=starts(1),1);
    sameSamples = t>=starts(end);
    for i = 1:numel(starts)
        k = find(t>=starts(i),1);
        mask = t>=starts(i);
        e = angle-angle(k)-c.omega*(t-t(k));
        eCenter = angle-angle(k)-c.omega*(center-center(k));
        fixed = angle-angle(anchor)-c.omega*(t-t(anchor));
        r.rms_reanchored_rad(i) = sqrt(mean(e(mask).^2));
        r.rms_fixed_anchor_rad(i) = sqrt(mean(fixed(mask).^2));
        r.rms_same_samples_reanchored_rad(i) = sqrt(mean(e(sameSamples).^2));
        r.max_timestamp_effect_rad = max(r.max_timestamp_effect_rad,max(abs(e-eCenter)));
    end
    assert(r.max_timestamp_effect_rad<1e-12);
    result.cases = [result.cases;r]; %#ok<AGROW>
    fprintf('%d-bit anchor sweep: %s\n',bits,mat2str(r.rms_reanchored_rad,6));
end
[fid,msg] = fopen(outputPath,'w','n','UTF-8');
assert(fid>=0,msg);
cleanup = onCleanup(@() fclose(fid));
fprintf(fid,'%s\n',jsonencode(result,'PrettyPrint',true));
end
