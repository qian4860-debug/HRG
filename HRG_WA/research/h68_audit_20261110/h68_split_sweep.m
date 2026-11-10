function out = h68_split_sweep()
% Reference-model sensitivity to the modal frequency split, 0..50 mHz.
here = fileparts(mfilename('fullpath'));
root = fileparts(fileparts(here));
modelDir = fullfile(root,'HRG_WA_simulink','piezo_v10','head6800_20261109');
addpath(modelDir);
splits = [0 0.010 0.025 0.050];
modes = {'continuous','tdm_shared'};
out = struct('generated',datestr(now,31),'cases',[]);
for j = 1:numel(modes)
    for k = 1:numel(splits)
        mode = modes{j}; df = splits(k);
        c = h68_config(mode,0.5,struct('split_hz',df,'duration',0.08,'log_decimation',200));
        [~,~,frames] = h68_reference(c);
        assert(~isempty(frames),'no frames %s df=%g',mode,df);
        f = frames(frames(:,1)>=0.04,:);
        t = f(:,1); y = f(:,2:end);
        amp = sqrt(sum(y(:,10:13).^2,2));
        err = y(:,14) - f(1,15) - c.omega*(t-t(1));
        rec = struct('mode',mode,'split_Hz',df,'modes_Hz',c.head.f_modes_Hz, ...
            'frames',size(f,1),'body_rms_rad',sqrt(mean(err.^2)), ...
            'body_peak_rad',max(abs(err)),'amp_min',min(amp),'amp_max',max(amp));
        out.cases = [out.cases;rec];
        fprintf('SPLIT %-12s df=%.3f Hz RMS=%g amp=%g..%g\n',mode,df,rec.body_rms_rad,min(amp),max(amp));
    end
end
fid = fopen(fullfile(here,'split_sweep.json'),'w','n','UTF-8');
assert(fid>=0);
fprintf(fid,'%s\n',jsonencode(out,'PrettyPrint',true));
fclose(fid);
end
