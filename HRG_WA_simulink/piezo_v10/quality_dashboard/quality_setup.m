function root=quality_setup()
% 只增加只读观察路径，不修改已验收中文模型。
root=fileparts(mfilename('fullpath'));addpath(root);
addpath(fullfile(fileparts(root),'revision_v10_2_cn'));p103_setup;
folder=fullfile(root,'models');if exist(folder,'dir'),addpath(folder);end
end
