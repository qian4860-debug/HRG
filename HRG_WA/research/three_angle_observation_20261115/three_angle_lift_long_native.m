function result=three_angle_lift_long_native(folder)
% 长时原生提升模型与 MATLAB 提升模型对拍；另验证只读数值探针不改变轨迹。
arguments
    folder (1,:) char=fileparts(mfilename('fullpath'))
end
addpath(fullfile(folder,'..','three_mode_split_20261113'));
modes={'tdm_separate','tdm_shared'}; rows={};
for k=1:2
    model=['hrg_lift_' modes{k}];load_system(fullfile(folder,'lift_models',[model '.slx']));
    cleanup=onCleanup(@() close_system(model,0));
    workspace=get_param(model,'ModelWorkspace');c=workspace.getVariable('c');L=workspace.getVariable('L');
    c.duration=20;expected=three_angle_lift_run(c,L);
    input=Simulink.SimulationInput(model);input=input.setVariable('c',c,'Workspace',model);
    tic;actual=sim(input);elapsed=toc;
    delta=max(abs(expected.trace-actual.liftTrace),[],'all');
    assert(delta<1e-7 && all(expected.angleCandidates(:,5:8)==1,'all') && expected.rail_free);
    blocks=find_system(model,'LookUnderMasks','all','FollowLinks','on','Type','Block');
    assert(~any(ismember(get_param(blocks,'BlockType'),{'MATLABFcn','InterpretedMATLABFcn','S-Function','MATLABSystem','FromWorkspace'})));
    assert(isempty(find_system(model,'SFBlockType','MATLAB Function')));
    rows{end+1}=struct('mode',modes{k},'duration_s',20,'native_runtime_s',elapsed, ...
        'frames',size(expected.trace,1),'max_trace_delta',delta,'rail_free',expected.rail_free); %#ok<AGROW>
    fprintf('%s 20s native: %.3g trace delta, %.3f s runtime\n',modes{k},delta,elapsed);
    clear cleanup
end
% 与默认调用逐元素比较，不要求因读取探针而改变任何状态或舍入行为。
probeRows={}; modes={'continuous','tdm_separate','tdm_shared'};
for k=1:3
    for periodic=[false true]
        c=three_mode_split_config(modes{k},0,.05,22.5,.006,16);c.periodicCarrier=periodic;
        [~,a,b,~,d]=five_reference(c,false);
        [~,a2,b2,~,d2,p]=five_reference(c,false);
        assert(isequal(a,a2) && isequal(b,b2) && isequal(d,d2) && size(p,2)==6+c.stateCount);
        probeRows{end+1}=struct('mode',modes{k},'periodic_carrier',periodic,'probe_read_is_exact_noop',true); %#ok<AGROW>
    end
end
result=struct('status','passed','long_native',[rows{:}],'probe_regression',[probeRows{:}]);
fid=fopen(fullfile(folder,'lift_long_native.json'),'w','n','UTF-8');assert(fid>=0);
cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',jsonencode(result,'PrettyPrint',true));
end
