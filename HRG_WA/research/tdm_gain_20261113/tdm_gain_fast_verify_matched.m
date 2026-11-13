function evidence = tdm_gain_fast_verify_matched()
% 三模式在同一 ADC/DAC 时钟、增益和转换精度下比较逐拍 MATLAB 参考。
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here,'..','..','HRG_WA_simulink','piezo_v10','five_electrode_20261110'));
modes = {'continuous','tdm_separate','tdm_shared'};
evidence = [];
for mode = modes
    for point = [10 .05;10 -.5;16 .05]'
        bits = point(1);
        rate = point(2);
        opts = struct('fs',5440000,'adc_bits',bits,'dac_bits',14,'adc_latency',5, ...
            'theta0',deg2rad(45),'log_decimation',1);
        c = five_config(mode{1},rate,opts);
        c.portSenseMap = 8*c.portSenseMap;
        c.pickoff = c.portSenseMap*c.portCV;
        c.detect = c.detect/8;
        % 结束时刻恰好等于第 10 帧发布拍，用于覆盖端点计数。
        c.duration = (9*c.frame+c.validEnd+c.adcLatency)*c.Ts;
        [actual,info,debug] = tdm_gain_fast(c);
        [~,trace,frames,monitor] = five_reference(c);
        assert(size(actual,1)==10 && actual(end,1)==c.duration);
        for f = 0:info.expected_frames-1
            tick = f*c.frame;
            adc = monitor(monitor(:,1)>=tick+c.validStart & monitor(:,1)<tick+c.validEnd,7:8);
            dac = trace(tick+(1:c.driveEnd),7:8);
            assert(isequal(adc,debug.adc(:,:,f+1)) && isequal(dac,debug.dac(:,:,f+1)), ...
                '三模式快速评估 ADC/DAC 码不一致。');
        end
        delta = max(abs(frames(:,[1 15 11:14])-actual),[],'all');
        assert(delta<1e-9);
        fullFrames = trace(1:info.expected_frames*c.driveEnd,:);
        if c.continuous
            assert(nnz(fullFrames(:,22))==info.dac_clip_ticks);
        end
        evidence = [evidence;struct('mode',mode{1},'rate_rad_s',rate,'adc_bits',bits, ...
            'checked_frames',info.expected_frames,'exact_adc_dac_codes',true, ...
            'exact_end_tick',true,'max_published_delta',delta)]; %#ok<AGROW>
    end
end
end
