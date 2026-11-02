function c=pcn_calibration(path)
% 读取合成独立参考标定，复数2×2矩阵描述幅相及串扰。
% detect将运动电荷映射到ADC电压；drive含驱动器和DAC零阶保持。
% 控制时用矩阵左除解嵌，不能只校正通道标量增益。
% 改变Ts必须重新标定，否则保持器的幅相校正失效。
% File contains estimates from separate known-input calibration fixtures.
if nargin==0,path=fullfile(fileparts(mfilename('fullpath')),'evidence','calibration_profile.json');end
x=jsondecode(fileread(path));c.detect=x.detect_real+1i*x.detect_imag;
c.sample_period_s=x.sample_period_s;
c.drive=x.drive_real+1i*x.drive_imag;c.nominal_detect=x.nominal_detect_real+1i*x.nominal_detect_imag;
assert(all(isfinite([c.detect(:);c.drive(:)]))&&cond(c.detect)<100&&cond(c.drive)<100);
end
