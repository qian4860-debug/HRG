function root=stress_setup()
root=fileparts(mfilename('fullpath'));addpath(fullfile(fileparts(root),'quality_dashboard'));quality_setup;addpath(root);
end
