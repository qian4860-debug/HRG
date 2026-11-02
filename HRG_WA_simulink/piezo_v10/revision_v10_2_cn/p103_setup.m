function root=p103_setup()
% 中文注释版路径入口：仅加入本目录及其模型库，避免调用旧版同名函数。
root=fileparts(mfilename('fullpath'));addpath(root);
folder=fullfile(root,'models');if exist(folder,'dir'),addpath(folder);end
end
