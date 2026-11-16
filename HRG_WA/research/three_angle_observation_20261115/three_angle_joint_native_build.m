function models = three_angle_joint_native_build(outDir, profile)
% 生成专用电极、共用电极基线和共用电极 DAC 整形的原生模型。
arguments
    outDir (1,:) char = fullfile(fileparts(mfilename('fullpath')),'joint_models')
    profile (1,1) struct = three_angle_joint_profile()
end
here = fileparts(mfilename('fullpath'));
piezo = fullfile(here,'..','..','HRG_WA_simulink','piezo_v10');
addpath(fullfile(here,'..','three_mode_split_20261113'), ...
    fullfile(piezo,'five_electrode_20261110'),fullfile(piezo,'head6800_20261109'));
models = {'hrg_joint_dedicated','hrg_joint_shared_baseline','hrg_joint_shared_shape'};
configs = {
    three_mode_split_config('tdm_separate',0,.05,22.5,.012,16)
    three_mode_split_config('tdm_shared',0,.05,22.5,.012,16)
    three_angle_joint_closed_config(profile,0,.05,22.5,.012,16,struct(),true)
    }';
h68_build(outDir,models,configs,false,false,true);
end
