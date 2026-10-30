function c=p101_calibration(path)
% File contains estimates from separate known-input calibration fixtures.
if nargin==0,path=fullfile(fileparts(mfilename('fullpath')),'evidence','calibration_profile.json');end
x=jsondecode(fileread(path));c.detect=x.detect_real+1i*x.detect_imag;
c.sample_period_s=x.sample_period_s;
c.drive=x.drive_real+1i*x.drive_imag;c.nominal_detect=x.nominal_detect_real+1i*x.nominal_detect_imag;
assert(all(isfinite([c.detect(:);c.drive(:)]))&&cond(c.detect)<100&&cond(c.drive)<100);
end
