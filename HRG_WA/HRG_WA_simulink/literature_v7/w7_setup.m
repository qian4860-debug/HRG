function c=w7_setup(c)
r=fileparts(mfilename('fullpath'));addpath(r,fullfile(fileparts(r),'layered'));
w7_validate(c);c=wl_setup(c);
% Full Rf/Cf noise gain matters in the low-wRC transimpedance regime.
b=w7_budget(c);c.cvEquivalentNoiseVrtHz=b.readoutNoiseVrtHz;
on=double(c.noiseEnable);
if isfield(c,'noiseSourceEnable'),on=on*double(c.noiseSourceEnable.cv);end
assignin('base','wl_cvNoiseVariance',(on*c.cvEquivalentNoiseVrtHz)^2*c.fsPlant/2);
assignin('base','wl_c',c);
end
