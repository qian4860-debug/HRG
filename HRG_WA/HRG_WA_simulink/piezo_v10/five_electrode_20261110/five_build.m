function models = five_build(outDir)
% Build both five-electrode variants with only native Simulink blocks.
arguments
    outDir (1,:) char = fullfile(fileparts(mfilename('fullpath')),'models')
end
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here,'..','head6800_20261109'));
names = {'hrg_5e_continuous','hrg_5e_tdm_shared'};
configs = {five_config('continuous'),five_config('tdm_shared')};
models = h68_build(outDir,names,configs);
end
