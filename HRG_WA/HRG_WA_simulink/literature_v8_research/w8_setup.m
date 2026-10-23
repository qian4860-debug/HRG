function c=w8_setup(c)
r=fileparts(mfilename('fullpath'));addpath(r,fullfile(fileparts(r),'literature_v7'));
assert(rcond(c.v8.senseInverse)>.1&&rcond(c.v8.driveInverse)>.1,'Ill-conditioned calibration');
assert(all(c.v8.cubicCoefficient>=0)&&c.v8.maximumCalibratedAmplitude>0);
c=w7_setup(c);assignin('base','wl_c',c);
end
