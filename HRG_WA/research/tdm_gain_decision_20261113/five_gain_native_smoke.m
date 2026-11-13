function result = five_gain_native_smoke()
% 对低速及近轴工况独立核对原生模型与 MATLAB。ADC 量化及失锁等标志须逐拍一致。
here = fileparts(mfilename('fullpath'));
v10 = fullfile(here,'..','..','HRG_WA_simulink','piezo_v10');
addpath(fullfile(v10,'five_electrode_20261110'));
addpath(fullfile(here,'..','five_adc_range_20261110'));
name = 'hrg_5e_tdm_shared';
model = fullfile(v10,'five_electrode_20261110','models',[name '.slx']);
assert(~bdIsLoaded(name),'运行前请关闭已加载的同名模型。');
load_system(model);
cleanup = onCleanup(@() close_system(name,0));
rows = [];
for caseData = [6 .05 0 10;8 -.05 22.5 10;8 .01 67.5 16].'
    gain = caseData(1);
    rate = caseData(2);
    beta = caseData(3);
    bits = caseData(4);
    opts = struct('duration',.012,'log_decimation',1,'adc_bits',bits,'theta0',deg2rad(2*beta));
    c = five_adc_study_config(rate,2,gain,[.5 1],opts);
    [~,trace,frames] = five_reference(c);
    in = Simulink.SimulationInput(name);
    in = in.setVariable('c',c,'Workspace',name);
    out = sim(in.setModelParameter('SaveTime','off','SignalLogging','off'));
    flags = [1:6,9,15,20:22];
    assert(isequal(trace(:,flags),out.trace(:,flags)) && ...
        isequal(frames(:,flags+1),out.frames(:,flags+1)));
    delta = max([abs(trace-out.trace);abs(frames(:,2:end)-out.frames(:,2:end))],[],'all');
    assert(delta<1e-9 && max(abs(frames(:,1)-out.frames(:,1)))<c.Ts/100);
    rows = [rows;struct('gain',gain,'rate_rad_s',rate,'beta_deg',beta,'adc_bits',bits, ...
        'samples',size(trace,1),'frames',size(frames,1),'max_numeric_difference',delta)]; %#ok<AGROW>
end
result = struct('release',version('-release'),'scope','R2025a short-window native parity', ...
    'cases',rows);
end
