function cases = tdm_residual_verify_native_frames(path,design,limit,values,clipped,names,expectedMode,opts)
% 回放统一的 ADC 帧矩阵，逐帧核对原生门禁、I/Q 和留出误差。
% values 的尺寸是样本数 × X/Y × 帧数。clipped 是逐样本、逐帧的合并过载标志。
arguments
    path (1,:) char
    design (1,1) struct
    limit (1,1) double {mustBePositive}
    values (:,2,:) double {mustBeFinite}
    clipped (:,:) logical
    names (:,1) string
    expectedMode (:,:) double = []
    opts.Verbose (1,1) logical = false
end
assert(size(values,3)>0 && size(values,1)==numel(design.lateMask) && ...
    isequal(size(clipped),[size(values,1),size(values,3)]) && numel(names)==size(values,3), ...
    '观测器回放的采样矩阵、过载标志和帧名长度不匹配。');
% 通过根输入端回放帧向量。检查版内部不包含回放源或 MATLAB 运行块。
[~,model] = fileparts(path);
load_system(path);
cleanup = onCleanup(@() close_system(model,0));
types = get_param(find_system(model,'Type','Block'),'BlockType');
assert(~any(ismember(types,{'MATLABFcn','S-Function','MATLABSystem','FromWorkspace'})) && ...
    isempty(find_system(model,'SFBlockType','MATLAB Function')));
frames = size(values,3);
tick = (0:frames-1)';
% 二维帧数据的末维是时刻，剪裁标志是时间在首维的标量向量序列。
if frames == 1
    % 根输入矩阵的单帧数据仍显式保留时间维度。
    frameSignal = timeseries(cat(3,values,values),[0;1]);
    clipSignal = timeseries(repmat(clipped.',2,1),[0;1]);
else
    frameSignal = timeseries(values,tick);
    clipSignal = timeseries(clipped.',tick);
end
inputs = Simulink.SimulationData.Dataset;
inputs = inputs.addElement(frameSignal,'Frame samples V');
inputs = inputs.addElement(clipSignal,'Clipped samples');
simInput = Simulink.SimulationInput(model);
simInput = simInput.setExternalInput(inputs);
simInput = simInput.setModelParameter('StopTime',num2str(tick(end)));
out = sim(simInput);
iqLog = out.yout.getElement('IQ').Values;
mode = out.yout.getElement('Mode').Values.Data;
jointOK = out.yout.getElement('JointOK').Values.Data;
lateOK = out.yout.getElement('LateOK').Values.Data;
assert(isequal(logical(jointOK(:)),mode(:)==2));
expectedLateOK = design.lateDesignOK & ~any(clipped(design.lateMask,:),1);
assert(isequal(logical(lateOK(:)),expectedLateOK(:)));
rmsLog = out.yout.getElement('HoldoutRMS_V').Values;
if ~isempty(expectedMode)
    assert(isequal(double(mode(:)),expectedMode(:)));
end
assert(all(ismember({'joint_iq','late_iq','holdout_rms_V','observer_mode'}, ...
    out.logsout.getElementNames())));
cases = repmat(struct('name',"",'mode',0,'status',"",'reason',"",'iq',nan(2), ...
    'holdout_rms_V',nan(1,2),'max_iq_difference_V',0,'max_holdout_difference_V',0),frames,1);
labels = ["invalid","late_fallback","joint"];
for k = 1:frames
    [expected,info] = tdm_residual_iq(values(:,:,k),design, ...
        Clipped=clipped(:,k),HoldoutLimit_V=limit);
    assert(mode(k)>=0 && mode(k)<=2 && labels(mode(k)+1)==info.status);
    actual = squeeze(iqLog.getdatasamples(k));
    actualRms = reshape(rmsLog.getdatasamples(k),1,[]);
    iqError = verifyValue(actual,expected);
    rmsError = verifyValue(actualRms,info.holdout_rms_V);
    cases(k) = struct('name',names(k),'mode',mode(k),'status',info.status, ...
        'reason',info.reason,'iq',actual,'holdout_rms_V',actualRms, ...
        'max_iq_difference_V',iqError, ...
        'max_holdout_difference_V',rmsError);
    if opts.Verbose
        fprintf('%s -> %s, IQ 差 %.3g V，留出 RMS 差 %.3g V\n', ...
            names(k),info.status,iqError,rmsError);
    end
end
end

function error_V = verifyValue(actual,expected)
% 无效帧先核对 NaN 掩码，再核对剩余有效数值。
assert(isequal(size(actual),size(expected)) && isequal(isnan(actual),isnan(expected)));
valid = isfinite(expected);
delta = abs(actual(valid)-expected(valid));
error_V = max([0;delta(:)]);
assert(error_V<1e-12,'原生观测器数值与 MATLAB 不一致。');
end
