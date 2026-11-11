function five_instrument_model(model)
% 给已加载的五电极原生模型添加共享的观察节点与记分板。
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here,'..','head6800_20261109'));
h68_instrument_model(model);
end
