function out = five_error_vs_settle()
% Check whether the TDM angle error at 0.5 rad/s is a start-up transient.
here = fileparts(mfilename('fullpath'));
root = fileparts(fileparts(here));
addpath(fullfile(root,'HRG_WA_simulink','piezo_v10','five_electrode_20261110'));
modes = {'continuous','tdm_shared'};
rates = [0 0.5 -4];
settles = [0.04 0.06 0.08 0.10 0.15];
out = struct('generated',datestr(now,31),'cases',[]);
for j = 1:numel(modes)
    for r = rates
        c = five_config(modes{j},r,struct('duration',0.35,'log_decimation',200));
        [~,~,frames] = five_reference(c);
        for s = settles
            f = frames(frames(:,1)>=s,:);
            if size(f,1) < 10, continue; end
            t = f(:,1); y = f(:,2:end);
            err = y(:,14) - f(1,15) - c.omega*(t-t(1));
            rec = struct('mode',modes{j},'rate_rad_s',r,'settle_s',s, ...
                'frames',size(f,1),'body_rms_rad',sqrt(mean(err.^2)), ...
                'body_peak_rad',max(abs(err)));
            out.cases = [out.cases;rec];
            fprintf('SETTLE %-12s rate=%+g settle=%.2f frames=%d RMS=%.6g peak=%.6g\n', ...
                modes{j},r,s,rec.frames,rec.body_rms_rad,rec.body_peak_rad);
        end
    end
end
fid = fopen(fullfile(here,'error_vs_settle.json'),'w','n','UTF-8');
assert(fid>=0);
fprintf(fid,'%s\n',jsonencode(out,'PrettyPrint',true));
fclose(fid);
end
