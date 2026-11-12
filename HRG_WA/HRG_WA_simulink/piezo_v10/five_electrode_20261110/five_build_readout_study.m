function models = five_build_readout_study(outDir)
% 生成可观察的连续版和分时复用版，各自含 ADC 前增益和单极点失配。
% 保存的工况冻结检测标定，用于观察失配怎样进入量化、解调与闭环。
arguments
    outDir (1,:) char = fullfile(fileparts(mfilename('fullpath')),'models')
end
modes = {'continuous','tdm_shared'};
names = strcat('hrg_5e_',modes,'_readout_mismatch');
settings = struct('readout_channel_gain',[1.01;0.99], ...
    'readout_channel_pole_Hz',[85e3;110e3],'log_decimation',200);
configs = cellfun(@(mode) five_config(mode,0.5,settings),modes,'UniformOutput',false);
models = h68_build(outDir,names,configs,true);
end
