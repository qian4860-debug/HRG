function [corrected, biasRate, weights] = split_bias_angle(az4, rawAngle, dt, calibration, measuredSplit)
% 用观测四倍驻波角估计零速漂移，再从已发布的累计机体角减去漂移积分。
% 标定表单位 rad/s，频差元数据单位 Hz；第 k 帧只扣至 k-1 帧为止的积分。
arguments
    az4 (:,1) double {mustBeFinite}
    rawAngle (:,1) double {mustBeFinite}
    dt (1,1) double {mustBePositive,mustBeFinite}
    calibration (5,2) double {mustBeFinite}
    measuredSplit (1,1) double
end
assert(~isempty(az4) && numel(rawAngle)==numel(az4));
if ~isfinite(measuredSplit) || abs(measuredSplit)>.05
    error('gyro:SplitOutsideCalibration','频差缺测或超出标定范围，禁止发布此补偿输出。');
end
fraction=(measuredSplit/.05)^2;
weights=calibration(:,1)+fraction*(calibration(:,2)-calibration(:,1));
basis=[ones(size(az4)),cos(az4),sin(az4),cos(2*az4),sin(2*az4)];
biasRate=basis*weights;
corrected=rawAngle-[0;cumsum(biasRate(1:end-1))*dt];
end
