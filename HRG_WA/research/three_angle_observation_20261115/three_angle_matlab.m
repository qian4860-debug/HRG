function [series,metrics,candidates] = three_angle_matlab(c,scoreStart)
% 五端三架构 MATLAB 观察入口。默认观察发布候选全段，可指定评分起点（秒）。
arguments
    c (1,1) struct
    scoreStart (1,1) double {mustBeFinite,mustBeNonnegative} = 0
end
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here,'..','..','HRG_WA_simulink','piezo_v10','five_electrode_20261110'));
[~,~,~,~,candidates] = five_reference(c,false);
[series,metrics] = three_angle_series(c,candidates,scoreStart);
end
