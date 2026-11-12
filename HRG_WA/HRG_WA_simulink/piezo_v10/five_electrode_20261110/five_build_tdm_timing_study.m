function models = five_build_tdm_timing_study(outDir)
% 生成原生分时诊断模型，记录每帧检测窗中心和原有发布时刻。
% 载波初相可从模型工作区配置，原驱检时序和闭环控制不变。
arguments
    outDir (1,:) char = fullfile(fileparts(mfilename('fullpath')),'models')
end
c = five_config('tdm_shared',0.5,struct('diagnostic_carrier_phase_rad',0,'log_decimation',200));
models = h68_build(outDir,{'hrg_5e_tdm_timing_study'},{c},true);
end
