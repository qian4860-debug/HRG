function models = three_angle_native_build(outDir)
% Build the three native matched models with read-only angle observers.
arguments
    outDir (1,:) char = fullfile(fileparts(mfilename('fullpath')),'models')
end
here = fileparts(mfilename('fullpath'));
piezo = fullfile(here,'..','..','HRG_WA_simulink','piezo_v10');
addpath(fullfile(here,'..','three_mode_split_20261113'), ...
    fullfile(piezo,'five_electrode_20261110'),fullfile(piezo,'head6800_20261109'));
modes = {'continuous','tdm_separate','tdm_shared'};
models = strcat('hrg_5e_',modes,'_matched_angles');
configs = cellfun(@(mode) three_mode_split_config(mode,.5,.05,22.5,.012,16), ...
    modes,'UniformOutput',false);
h68_build(outDir,models,configs,true,false,true);
end
