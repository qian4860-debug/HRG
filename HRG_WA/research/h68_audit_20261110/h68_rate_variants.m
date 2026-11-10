function out = h68_rate_variants()
% Reference-model check of candidate lower converter rates. MATLAB only;
% native-model parity at the default rates is covered by h68_verify.
here = fileparts(mfilename('fullpath'));
root = fileparts(fileparts(here));
modelDir = fullfile(root,'HRG_WA_simulink','piezo_v10','head6800_20261109');
addpath(modelDir);
cases = {
    'continuous', 1088000;
    'continuous',  544000;
    'tdm_shared', 5440000;
    'tdm_shared', 5004800;
    'tdm_separate',5440000;
    'tdm_separate',5004800};
out = struct('generated',datestr(now,31),'cases',[]);
for k = 1:size(cases,1)
    mode = cases{k,1}; fs = cases{k,2};
    c = h68_config(mode,0.5,struct('fs',fs,'duration',0.08,'log_decimation',200));
    [~,~,frames] = h68_reference(c);
    assert(~isempty(frames),'no accepted frames for %s at %.0f',mode,fs);
    t = frames(:,1); y = frames(:,2:end);
    settle = 0.04; f = frames(t>=settle,:);
    tt = f(:,1); yy = f(:,2:end);
    amp = sqrt(sum(yy(:,10:13).^2,2));
    err = yy(:,14) - f(1,15) - c.omega*(tt-tt(1));
    rec = struct('mode',mode,'fs_Hz',fs,'samples_per_carrier',c.n, ...
        'frame_samples',c.frame,'frame_rate_Hz',fs/c.frame, ...
        'adc_bits',c.p.adc_bits,'dac_bits',c.p.dac_bits, ...
        'frames',size(f,1),'body_rms_rad',sqrt(mean(err.^2)), ...
        'body_peak_rad',max(abs(err)),'amp_min',min(amp),'amp_max',max(amp));
    out.cases = [out.cases;rec];
    fprintf('VARIANT %-12s fs=%8.0f n=%4d frame=%5d rate=%7.1f RMS=%g amp=%g..%g\n', ...
        mode,fs,c.n,c.frame,fs/c.frame,rec.body_rms_rad,min(amp),max(amp));
end
fid = fopen(fullfile(here,'rate_variants.json'),'w','n','UTF-8');
assert(fid>=0);
fprintf(fid,'%s\n',jsonencode(out,'PrettyPrint',true));
fclose(fid);
end
