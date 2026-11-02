function root=sn_setup()
root=fileparts(mfilename('fullpath'));addpath(fullfile(fileparts(root),'compensation_research'));comp_setup;addpath(root);
end
