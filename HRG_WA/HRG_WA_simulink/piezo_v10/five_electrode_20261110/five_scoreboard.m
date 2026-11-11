function report = five_scoreboard(c, t, trace, frames, opts)
% 五电极计分板入口，沿用 26 列 trace、27 列 frames 和原评分默认值。
arguments
    c (1,1) struct
    t (:,1) double
    trace (:,26) double
    frames (:,27) double
    opts.SettleTime_s (1,1) double {mustBeNonnegative} = 0.06
    opts.MinimumFrames (1,1) double {mustBeInteger,mustBePositive} = 101
    opts.AngleRmsLimit_rad (1,1) double {mustBePositive} = 0.015
    opts.AmplitudeBounds (1,2) double {mustBePositive} = [0.8 1.2]
end
% 通用判据同时检查 6800 Hz 基线和五电极的数据。
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here,'..','head6800_20261109'));
report = h68_scoreboard(c,t,trace,frames, ...
    SettleTime_s=opts.SettleTime_s,MinimumFrames=opts.MinimumFrames, ...
    AngleRmsLimit_rad=opts.AngleRmsLimit_rad,AmplitudeBounds=opts.AmplitudeBounds);
end
