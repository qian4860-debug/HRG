function models = h68_build_inspect(outDir)
% 生成连续、分时复用、分时不复用三份原生 Simulink 检查模型。
% 独立文件名让检查版与已打开的基线模型并存。
arguments
    outDir (1,:) char = fullfile(fileparts(mfilename('fullpath')),'models')
end
names = {'hrg_6800_continuous_inspect', ...
    'hrg_6800_tdm_shared_inspect','hrg_6800_tdm_separate_inspect'};
models = h68_build(outDir,names,{},true);
end
