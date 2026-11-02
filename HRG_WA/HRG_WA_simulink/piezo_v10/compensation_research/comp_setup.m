function root=comp_setup()
root=fileparts(mfilename('fullpath'));addpath(fullfile(fileparts(root),'nonideal_validation'));stress_setup;addpath(root);
end
