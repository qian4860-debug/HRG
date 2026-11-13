function models = five_build_dither_study(outDir)
% 生成可观察的连续版与分时复用版，默认以 0.3 LSB RMS 演示 ADC 抖动。
% 独立模型名保留已有验证版。D1 架构结论按独立多工况回执判断。
arguments
    outDir (1,:) char = fullfile(fileparts(mfilename('fullpath')),'models')
end
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here,'..','head6800_20261109'));
modes = {'continuous','tdm_shared'};
names = strcat('hrg_5e_',modes,'_dither_inspect');
settings = struct('duration',.02,'adc_dither_lsb_rms',.3);
configs = cellfun(@(mode) five_config(mode,.5,settings),modes,'UniformOutput',false);
models = h68_build(outDir,names,configs,true,true);
end
