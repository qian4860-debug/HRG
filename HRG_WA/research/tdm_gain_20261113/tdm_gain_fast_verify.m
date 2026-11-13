function evidence = tdm_gain_fast_verify()
% 用逐拍参考核验压缩推进的 ADC/DAC 码、I/Q、角度及限幅事件。
here = fileparts(mfilename('fullpath'));
root = fileparts(here);
addpath(fullfile(root,'five_adc_range_20261110'));
addpath(fullfile(root,'..','HRG_WA_simulink','piezo_v10','five_electrode_20261110'));
points = [10 1 .5 0;10 6 .01 22.5;10 8 -4 67.5;16 1 .05 45;16 8 .5 0;16 6 -4 67.5];
evidence = [];
for p = points'
    [bits,gain,rate,beta] = deal(p(1),p(2),p(3),p(4));
    opts = struct('adc_bits',bits,'theta0',deg2rad(2*beta), ...
        'duration',20*4/6800,'log_decimation',1);
    c = five_adc_study_config(rate,2,gain,[.5 1],opts);
    [actual,info,debug] = tdm_gain_fast(c);
    [~,trace,frames,monitor] = five_reference(c);
    expect = frames(:,[1 15 11:14]);
    assert(size(expect,1)==size(actual,1),'快速评估发布帧数不一致。');
    for f = 0:info.expected_frames-1
        ticks = f*c.frame;
        adc = monitor(monitor(:,1)>=ticks+c.validStart & monitor(:,1)<ticks+c.validEnd,7:8);
        dac = trace(ticks+(1:c.driveEnd),7:8);
        assert(isequal(adc,debug.adc(:,:,f+1)) && isequal(dac,debug.dac(:,:,f+1)), ...
            '快速评估 ADC/DAC 量化码不一致。');
    end
    delta = max(abs(expect-actual),[],'all');
    assert(delta<1e-9);
    assert(info.adc_clip_ticks==nnz(trace(:,20)) && ...
        info.tracking_lost==any(trace(:,21)) && info.dac_clip_ticks==nnz(trace(:,22)));
    evidence = [evidence;struct('bits',bits,'gain',gain,'rate_rad_s',rate, ...
        'initial_beta_deg',beta,'checked_frames',info.expected_frames, ...
        'exact_adc_dac_codes',true,'max_published_delta',delta)]; %#ok<AGROW>
end
end
