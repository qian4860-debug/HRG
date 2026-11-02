function [p,c]=pcn_temperature_apply(p,c,T,path)
% 离线温漂补偿：仅在辨识温区内插值，禁止外推。
% 标量物理参数与复数双通道标定矩阵按已验证阶数拟合。
% 参数来自合成留出数据；不代表真实温箱、温度梯度或滞回已验证。
if nargin<4,path=fullfile(fileparts(mfilename('fullpath')),'evidence','temperature_profile.json');end
r=jsondecode(fileread(path));assert(T>=r.T_range_C(1)&&T<=r.T_range_C(2),'p101:temperature','Outside identified range');
v=[1 T-r.Tref_C (T-r.Tref_C)^2]*r.coefficients;p.f0=v(1);p.gamma_intrinsic=v(2);p.Cs=v(3);
c.detect=reshape(v(4:7),2,2).'+1i*reshape(v(8:11),2,2).';
c.drive=reshape(v(12:15),2,2).'+1i*reshape(v(16:19),2,2).';
p.temperature_C=T;
end
