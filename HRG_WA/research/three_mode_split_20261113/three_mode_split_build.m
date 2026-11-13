function models = three_mode_split_build(outDir)
% 构建三份同转换器配置的五端原生检查模型。
% 观察 50 mHz 频差与 22.5 度初始驻波角，研究矩阵由验证脚本覆盖。
arguments
    outDir (1,:) char = fullfile(fileparts(mfilename('fullpath')),'models')
end
here = fileparts(mfilename('fullpath'));
piezo = fullfile(here,'..','..','HRG_WA_simulink','piezo_v10');
addpath(fullfile(piezo,'five_electrode_20261110'),fullfile(piezo,'head6800_20261109'));
modes = {'continuous','tdm_separate','tdm_shared'};
names = strcat('hrg_5e_',modes,'_matched_split');
configs = cellfun(@(mode) three_mode_split_config(mode,.5,.05,22.5,.012,16), ...
    modes,'UniformOutput',false);
models = h68_build(outDir,names,configs,true);
end
