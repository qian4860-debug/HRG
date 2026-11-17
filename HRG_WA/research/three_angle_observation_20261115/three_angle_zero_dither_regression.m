function result=three_angle_zero_dither_regression(folder)
% 长时失败归属核查：旧原生模型与新增零幅抖动支路的模型使用完全相同的配置。
% 区分本轮建模改动引入的回归与既有 MATLAB/原生浮点轨迹分歧。
arguments
    folder (1,:) char = fileparts(mfilename('fullpath'))
end
addpath(fullfile(folder,'..','three_mode_split_20261113'));
modes={'continuous','tdm_separate'};
old={'hrg_rc_continuous','hrg_rc_separate'};
new={'hrg_dq_continuous','hrg_dq_separate'};
rows={};
for k=1:2
    c=three_mode_split_config(modes{k},0,.05,22.5,.12,16,struct('Cs',720e-12));
    c.logDecimation=1; c.p.bleed_R=1/(720e-12/2e-6-c.p.G0);
    % 此两版不复用，泄放矩阵不参与；仍将两份输入参数逐字段设为一致。
    load_system(fullfile(folder,'rc_models',[old{k} '.slx']));
    load_system(fullfile(folder,'drift_quant_models',[new{k} '.slx']));
    a=runOne(old{k},c); b=runOne(new{k},c);
    delta=b.angleCandidates(:,2:4)-a.angleCandidates(:,2:4);
    err=max(abs(atan2(sin(delta),cos(delta))),[],'all');
    codes=nnz(a.trace(:,5:8)~=b.trace(:,5:8));
    events=isequal(a.trace(:,[1:4 9 15 20:22]),b.trace(:,[1:4 9 15 20:22]));
    assert(codes==0 && events && err<1e-12);
    rows{end+1}=struct('mode',modes{k},'duration_s',.12,'converter_mismatches',codes, ...
        'event_flags_equal',events,'max_angle_delta_rad',err, ...
        'whole_trace_exact',isequal(a.trace,b.trace), ...
        'whole_frames_exact',isequal(a.frames,b.frames), ...
        'whole_candidates_exact',isequal(a.angleCandidates,b.angleCandidates)); %#ok<AGROW>
    close_system(old{k},0); close_system(new{k},0);
    fprintf('%s zero-dither old/new exact trace=%d, angle %.3g\n',modes{k},rows{end}.whole_trace_exact,err);
end
result=struct('status','passed','cases',[rows{:}]);
fid=fopen(fullfile(folder,'zero_dither_regression.json'),'w','n','UTF-8'); assert(fid>=0);
cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',jsonencode(result,'PrettyPrint',true));
end

function out=runOne(model,c)
input=Simulink.SimulationInput(model); input=input.setVariable('c',c,'Workspace',model);
input=input.setModelParameter('SaveTime','off'); out=sim(input);
end
