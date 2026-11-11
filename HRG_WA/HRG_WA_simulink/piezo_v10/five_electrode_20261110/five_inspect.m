function [report, data] = five_inspect(mode, engine, omega, overrides, opts)
% 运行五电极 MATLAB 或原生 Simulink，打开计分板、关键节点和闭环趋势。
% 示例：five_inspect('continuous','simulink')；无窗口回归请用 Plots=false。
arguments
    mode (1,:) char {mustBeMember(mode,{'continuous','tdm_shared'})} = 'continuous'
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
if ~isfield(overrides,'duration'), overrides.duration = 0.18; end
if ~isfield(overrides,'log_decimation'), overrides.log_decimation = 1; end
c = five_config(mode,omega,overrides);
settle = opts.SettleTime_s;
if isnan(settle)
    settle = 0.06;
    if c.p.seed_enabled && c.p.initial_fraction==0, settle = 0.35; end
end

% 五电极入口保留原有工况，并复用 6800 Hz 的显示和计分逻辑。
opts.SettleTime_s = settle;
name = ['hrg_5e_' mode '_inspect.slx'];
modelPath = fullfile(fileparts(mfilename('fullpath')),'models',name);
[report,data] = h68_inspect_run(c,engine,modelPath,@five_reference,'五电极',opts, ...
    opts.Plots || nargout>1);
end
