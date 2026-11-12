function result = five_readout_study(modelDir)
% 比较无附加读出链、冻结标定和已知复频响补偿。所有结果来自行为仿真。
% MATLAB 全闭环跑相同输入，原生模型在短窗比较逐拍量化、标志和角度。
arguments
    modelDir (1,:) char = fullfile(fileparts(mfilename('fullpath')),'models')
end
result = struct('scope','Behavioral simulation; known carrier response is a calibration reference', ...
    'duration_s',0.18,'score_start_s',0.06,'input_rad_s',0.5,'modes',[]);
for mode = ["continuous","tdm_shared"]
    opts = struct('duration',result.duration_s,'log_decimation',200);
    nominal = five_config(char(mode),result.input_rad_s,opts);
    opts.readout_channel_gain = [1.01;0.99];
    opts.readout_channel_pole_Hz = [85e3;110e3];
    frozen = five_config(char(mode),result.input_rad_s,opts);
    % 公共载波响应取复数几何均值，用同一极点形式构造无相对失配的对照。
    common = sqrt(prod(frozen.readoutCarrierResponse));
    matched = opts;
    pole_Hz = frozen.w/(2*pi*tan(-angle(common)));
    matched.readout_channel_pole_Hz = repmat(pole_Hz,2,1);
    matched.readout_channel_gain = repmat(abs(common)/cos(angle(common)),2,1);
    matched = five_config(char(mode),result.input_rad_s,matched);
    assert(max(abs(matched.readoutCarrierResponse-common))<1e-12);
    opts.readout_calibrate = true;
    calibrated = five_config(char(mode),result.input_rad_s,opts);
    assert(nominal.stateCount==26 && frozen.stateCount==28 && isequal(nominal.detect,frozen.detect));
    assert(isequal(frozen.Ad,calibrated.Ad) && isequal(frozen.pickoff,calibrated.pickoff));
    name = char("hrg_5e_"+mode+"_readout_mismatch");
    info = struct('mode',mode);
    ratio = frozen.readoutCarrierResponse(2)/frozen.readoutCarrierResponse(1);
    info.readout_y_x_magnitude = abs(ratio);
    info.readout_y_x_phase_deg = rad2deg(angle(ratio));
    info.nominal = score(nominal,result.score_start_s);
    info.matched_readout = score(matched,result.score_start_s);
    info.frozen = score(frozen,result.score_start_s);
    info.known_response_compensation = score(calibrated,result.score_start_s);
    opts.duration = 0.006;
    opts.log_decimation = 1;
    c = five_config(char(mode),result.input_rad_s,opts);
    info.native_calibrated_max_trace_delta = parity(name,modelDir,c);
    opts.readout_calibrate = false;
    c = five_config(char(mode),result.input_rad_s,opts);
    info.native_frozen_max_trace_delta = parity(name,modelDir,c);
    result.modes = [result.modes; info]; %#ok<AGROW>
end
disp(result)
end

function r = score(c,scoreStart)
% 真值和测量从同一有效帧起算。保留失锁及 DAC 限幅，以免误解角误差。
[~,~,frames] = five_reference(c);
f = frames(frames(:,1)>=scoreStart,:);
assert(size(f,1)>=100 && all(f(:,16)),'评分窗内有效数据不足。');
angle = f(:,15)-f(1,15);
error_rad = angle-c.omega*(f(:,1)-f(1,1));
r = struct('scored_frames',size(f,1),'angle_rms_rad',sqrt(mean(error_rad.^2)), ...
    'last_frame_s',f(end,1),'last_error_rad',error_rad(end));
end

function maxDelta = parity(name,modelDir,c)
% 用原生连续时间离散状态网络与逐拍 MATLAB 参考独立核对同一参数。
assert(~bdIsLoaded(name),'Close the model before running parity.');
load_system(fullfile(modelDir,[name '.slx']));
closeModel = onCleanup(@() close_system(name,0));
in = Simulink.SimulationInput(name);
in = in.setVariable('c',c,'Workspace',name);
out = sim(in.setModelParameter('SignalLogging','off'));
[~,trace,frames] = five_reference(c);
flags = [1:4,9,15,20:22];
assert(isequal(trace(:,flags),out.trace(:,flags)) && ...
    isequal(frames(:,flags+1),out.frames(:,flags+1)),'原生模型事件标志不一致。');
maxDelta = max([abs(trace-out.trace);abs(frames(:,2:end)-out.frames(:,2:end))],[],'all');
assert(maxDelta<1e-9 && max(abs(frames(:,1)-out.frames(:,1)))<c.Ts/10);
blocks = find_system(name,'LookUnderMasks','all','FollowLinks','on','Type','Block');
types = get_param(blocks,'BlockType');
assert(~any(ismember(types,{'MATLABFcn','S-Function','M-S-Function'})));
end
