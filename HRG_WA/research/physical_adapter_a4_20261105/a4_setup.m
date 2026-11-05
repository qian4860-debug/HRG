function root=a4_setup
root=fileparts(mfilename('fullpath'));project=fileparts(fileparts(root));
addpath(fullfile(project,'HRG_WA_simulink','piezo_v10','noise_research'));sn_setup;addpath(root);
end
