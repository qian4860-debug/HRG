function [report, data] = h68_inspect(mode, engine, omega, overrides, opts)
% 运行 6800 Hz 连续、分时复用或分时不复用版，打开计分板与波形。
% 示例：h68_inspect('tdm_separate','simulink')；无窗口回归请用 Plots=false。
arguments
    mode (1,:) char {mustBeMember(mode,{'continuous','tdm_shared','tdm_separate'})} = 'continuous'
    engine (1,:) char {mustBeMember(engine,{'matlab','simulink'})} = 'matlab'
    omega (1,1) double {mustBeFinite} = 0.5
    overrides (1,1) struct = struct()
    opts.Plots (1,1) logical = true
    opts.SettleTime_s (1,1) double = NaN
    opts.MinimumFrames (1,1) double {mustBeInteger,mustBePositive} = 101
    opts.AngleRmsLimit_rad (1,1) double {mustBePositive} = 0.015
    opts.AmplitudeBounds (1,2) double {mustBePositive} = [0.8 1.2]
    opts.WaveWindow_s (1,2) double {mustBeFinite,mustBeNonnegative} = [0 .002]
end
if ~isfield(overrides,'duration'), overrides.duration = 0.3; end
if ~isfield(overrides,'log_decimation'), overrides.log_decimation = 1; end
c = h68_config(mode,omega,overrides);
settle = opts.SettleTime_s;
if isnan(settle)
    settle = 0.1;
    if c.p.seed_enabled && c.p.initial_fraction==0, settle = 0.5; end
end

% 观察模型保留相同的 22 列 trace 和 23 列发布帧。
opts.SettleTime_s = settle;
name = ['hrg_6800_' mode '_inspect.slx'];
modelPath = fullfile(fileparts(mfilename('fullpath')),'models',name);
[report,data] = h68_inspect_run(c,engine,modelPath,@h68_reference,'6800 Hz ',opts, ...
    opts.Plots || nargout>1);
end
