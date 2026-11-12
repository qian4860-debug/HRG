function d = tdm_residual_design(phase, templates, lateMask, opts)
% 从固定采样相位和独立标定模板构建双轴共同的最小二乘矩阵。
% 相位单位 rad，templates 的列可各自缩放，lateMask 以物理采样时刻定义。
% 输出的线性映射可供 MATLAB 和原生 Simulink 按每帧重复使用。
arguments
    phase (:,1) double {mustBeFinite}
    templates (:,:) double {mustBeFinite}
    lateMask (:,1) logical
    opts.Weights (:,1) double {mustBeFinite,mustBePositive} = ones(numel(phase),1)
    opts.Holdout (:,1) logical = mod((1:numel(phase))',4)==0
    opts.MaxCondition (1,1) double {mustBeFinite,mustBePositive} = 40
    opts.MinCarrierInfo (1,1) double {mustBeInRange(opts.MinCarrierInfo,0,1)} = 0.15
end
n = numel(phase);
assert(n>0 && size(templates,1)==n && ~isempty(templates) && ...
    all([numel(lateMask),numel(opts.Weights),numel(opts.Holdout)]==n), ...
    '采样相位、模板和掩码的行数必须一致。');
carrier = [cos(phase),sin(phase)];
design = [carrier,templates];
train = ~opts.Holdout;
test = opts.Holdout;
weights = opts.Weights;
[condition, infoFraction] = designMetrics(design,weights);
[trainCondition, trainInfo] = designMetrics(design(train,:),weights(train));
jointOK = nnz(test)>=2 && max(condition,trainCondition)<=opts.MaxCondition && ...
    min(infoFraction,trainInfo)>=opts.MinCarrierInfo;
lateOK = nnz(lateMask)>=2 && ...
    cond(carrier(lateMask,:).*sqrt(weights(lateMask)))<=opts.MaxCondition;
d = struct('jointCarrierMap',zeros(2,n),'lateCarrierMap',zeros(2,n), ...
    'holdoutErrorMap',zeros(nnz(test),n),'jointDesignOK',jointOK,'lateDesignOK',lateOK, ...
    'lateMask',lateMask,'holdoutMask',test,'condition',condition, ...
    'carrier_info_fraction',infoFraction,'training_condition',trainCondition, ...
    'training_carrier_info_fraction',trainInfo);
if jointOK
    fitMap = weightedMap(design,weights);
    d.jointCarrierMap = fitMap(1:2,:);
    % 留出点不参与校验拟合。每行对测试值减去由训练数据预测的值。
    d.holdoutErrorMap(:,train) = -design(test,:)*weightedMap(design(train,:),weights(train));
    d.holdoutErrorMap(:,test) = eye(nnz(test));
end
if lateOK
    d.lateCarrierMap(:,lateMask) = weightedMap(carrier(lateMask,:),weights(lateMask));
end
end

function [condition, fraction] = designMetrics(a,weights)
% 先归一化列再检查奇异值。fraction 是去除瞬态后最差载波组合的相对信息量。
condition = Inf;
fraction = 0;
if size(a,1)<size(a,2)
    return
end
a = a.*sqrt(weights);
scale = vecnorm(a);
if any(scale==0)
    return
end
a = a./scale;
s = svd(a,'econ');
if s(end)<=max(size(a))*eps(s(1))
    return
end
condition = s(1)/s(end);
[qCarrier,~] = qr(a(:,1:2),0);
[qTransient,~] = qr(a(:,3:end),0);
fraction = min(svd(qCarrier-qTransient*(qTransient'*qCarrier),'econ'))^2;
end

function map = weightedMap(a,weights)
% 通过 QR 求预白化后的线性映射，避免正规方程平方条件数。
sqrtW = sqrt(weights);
a = a.*sqrtW;
scale = vecnorm(a);
[q,r] = qr(a./scale,0);
map = ((r\q')./scale').*sqrtW';
end
