function result = five_tdm_timing_study(modelDir)
% 固定评分窗与锚点，扫载波相对时隙的初相及 ADC 位宽。
% 比较同一批帧的发布时间与有效检测窗中心；高位宽仅作量化消融。
arguments
    modelDir (1,:) char = fullfile(fileparts(mfilename('fullpath')),'models')
end
result = struct('scope','Behavioral model, constant rate and fixed score interval', ...
    'duration_s',0.18,'score_start_s',0.06,'phase_deg',[0 17 45 90 135], ...
    'adc_bits',[10 16],'rate_rad_s',[0 0.5], ...
    'nominal',[],'readout_mismatch_at_phase0',[],'native_parity',[]);
for rate = result.rate_rad_s
    for phase = result.phase_deg
        for bits = result.adc_bits
            opts = settings(result,phase,bits);
            c = five_config('tdm_shared',rate,opts);
            result.nominal = [result.nominal; scoreCase(c,result)]; %#ok<AGROW>
        end
    end
end
for bits = result.adc_bits
    opts = settings(result,0,bits);
    opts.readout_channel_gain = [1.01;0.99];
    opts.readout_channel_pole_Hz = [85e3;110e3];
    for compensate = [false true]
        opts.readout_calibrate = compensate;
        c = five_config('tdm_shared',0.5,opts);
        r = scoreCase(c,result);
        r.known_response_compensated = compensate;
        result.readout_mismatch_at_phase0 = [result.readout_mismatch_at_phase0;r]; %#ok<AGROW>
    end
end
for bits = result.adc_bits
    % 17° 不对应整数采样拍，避免只验证整拍相移。
    opts = settings(result,17,bits);
    opts.duration = 0.006;
    opts.log_decimation = 1;
    c = five_config('tdm_shared',0.5,opts);
    result.native_parity = [result.native_parity;checkNative(modelDir,c)]; %#ok<AGROW>
end
end

function opts = settings(r,phase,bits)
% 保持分时帧率、DAC、初始机械态和评分规则一致。
opts = struct('diagnostic_carrier_phase_rad',deg2rad(phase),'adc_bits',bits, ...
    'duration',r.duration_s,'log_decimation',200);
end

function row = scoreCase(c,r)
% 仅在原始发布时间上选取样本，避免更换标签时误改评分样本。
[~,~,frames] = five_reference(c);
f = frames(frames(:,1)>=r.score_start_s,:);
assert(size(f,1)==204 && all(f(:,16)),'评分帧缺失或无效。');
publish = f(:,1);
center = publish-c.framePublishToCenter_s;
angle = f(:,15);
ep = angle-angle(1)-c.omega*(publish-publish(1));
ec = angle-angle(1)-c.omega*(center-center(1));
difference = max(abs(ep-ec));
assert(difference<1e-13,'固定平移后同帧相对误差不应改变。');
raw = angle-c.omega*center;
line = polyfit(center-center(1),angle,1);
row = struct('omega_rad_s',c.omega,'carrier_phase_deg',rad2deg(c.carrierPhase_rad), ...
    'adc_bits',c.p.adc_bits,'score_frames',size(f,1), ...
    'detector_center_to_publish_us',1e6*c.framePublishToCenter_s, ...
    'angle_rms_rad',sqrt(mean(ep.^2)), 'angle_centered_rms_rad',std(raw,1), ...
    'estimated_rate_rad_s',line(1),'last_error_rad',ep(end), ...
    'max_error_change_from_relabel_rad',difference);
fprintf('%5.1f rad/s, %3.0f deg, %2d bit: %.6g rad\n', ...
    row.omega_rad_s,row.carrier_phase_deg,row.adc_bits,row.angle_rms_rad);
end

function r = checkNative(modelDir,c)
% 独立比较原生状态网络、逐拍事件及新的窗口中心日志。
name = 'hrg_5e_tdm_timing_study';
assert(~bdIsLoaded(name),'请关闭已打开的同名诊断模型再运行验证。');
load_system(fullfile(modelDir,[name '.slx']));
cleanup = onCleanup(@() close_system(name,0));
in = Simulink.SimulationInput(name);
in = in.setVariable('c',c,'Workspace',name);
out = sim(in.setModelParameter('SignalLogging','off'));
[~,trace,frames] = five_reference(c);
flags = [1:4,9,15,20:22];
assert(isequal(trace(:,flags),out.trace(:,flags)) && ...
    isequal(frames(:,flags+1),out.frames(:,flags+1)));
delta = max([abs(trace-out.trace);abs(frames(:,2:end)-out.frames(:,2:end))],[],'all');
expected = frames(:,1)-c.framePublishToCenter_s;
centerDelta = max(abs(expected-out.frame_detection_time_s(:)));
assert(delta<1e-9 && centerDelta<c.Ts/100);
r = struct('adc_bits',c.p.adc_bits,'carrier_phase_deg',rad2deg(c.carrierPhase_rad), ...
    'samples',size(trace,1),'frames',size(frames,1), ...
    'max_trace_and_frame_delta',delta,'max_detection_center_delta_s',centerDelta);
end
