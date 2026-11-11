function models = five_build(outDir, inspect)
% 生成两种五电极原生模型；inspect=true 生成带记分板的独立副本。
arguments
    outDir (1,:) char = fullfile(fileparts(mfilename('fullpath')),'models')
    inspect (1,1) logical = false
end
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here,'..','head6800_20261109'));
names = {'hrg_5e_continuous','hrg_5e_tdm_shared'};
configs = {five_config('continuous'),five_config('tdm_shared')};
if inspect
    % 独立模型名让已打开的基线工程和本轮诊断副本可以并存。
    names = {'hrg_5e_continuous_inspect','hrg_5e_tdm_shared_inspect'};
end
models = h68_build(outDir,names,configs,inspect);
end
