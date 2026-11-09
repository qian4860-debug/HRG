function result = tdm_verify(modelDir)
% Execute both native models against an independent MATLAB closed loop.
arguments
    modelDir (1,:) char = fullfile(fileparts(mfilename('fullpath')), 'models')
end
models = {'hrg_tdm_separate','hrg_tdm_shared'};
rates = [0 0.5 -0.5 4];
result = struct('release',version('-release'),'scope','Synthetic closed-loop simulation', ...
    'cases',[],'faults',[],'electrode_comparison',[]);
ports = cell(1,2);
for j = 1:2
    model = models{j};
    assert(~bdIsLoaded(model), 'Close %s before running verification.', model);
    load_system(fullfile(modelDir,[model '.slx']));
    cleanup = onCleanup(@() close_system(model,0));
    blocks = find_system(model,'LookUnderMasks','all','FollowLinks','on','Type','Block');
    types = get_param(blocks,'BlockType');
    assert(~any(ismember(types,{'S-Function','MATLABFcn','InterpretedMATLABFcn','MATLABSystem'})));
    assert(isempty(find_system(model,'LookUnderMasks','all','SFBlockType','MATLAB Function')));
    assert(isempty(find_system(model,'LookUnderMasks','all','BlockType','FromWorkspace')));
    for rate = rates
        c = tdm_config(j==2,rate);
        [t,r,y] = run(model,c);
        m = compare(t,r,y,c);
        m.model = model;
        m.body_rate_rad_s = rate;
        m.native_blocks = numel(blocks);
        result.cases = [result.cases; m]; %#ok<AGROW>
        if rate==0.5, ports{j} = y; end
        fprintf('%s rate=%+.2f RMS=%g rad min_amp=%g parity=%g\n',model,rate,m.body_rms_rad,m.minimum_amplitude,m.max_angle_delta_rad);
    end
    % An over-range AFE must not publish a valid zero angle or arm the drive.
    c = tdm_config(j==2,0.5);
    c.duration = .06;
    c.adcMax = 2*c.adcStep;
    c.adcMin = -2*c.adcStep;
    [~,r,y] = run(model,c);
    assert(isequal(r(:,[1:4 9 15 20 21]),y(:,[1:4 9 15 20 21])));
    assert(any(y(:,20)) && ~any(y(:,[7:9 15]),'all'));
    result.faults = [result.faults; struct('model',model,'clipped_samples',nnz(y(:,20)), ...
        'valid_frames',nnz(y(:,9)),'drive_samples',nnz(any(y(:,7:8),2)))]; %#ok<AGROW>
    clear cleanup
end
a = ports{1}; b = ports{2};
assert(isequal(a(:,1:4),b(:,1:4)), 'Both revisions must use the same timing.');
drive = b(:,2)>0;
vSeparate = max(abs(a(drive,18:19)),[],'all');
vShared = max(abs(b(drive,18:19)),[],'all');
assert(vShared>100*vSeparate && vShared>0.01, 'Shared pickoff did not follow the drive route.');
result.electrode_comparison = struct('separate_pickoff_peak_while_driving_V',vSeparate, ...
    'shared_pickoff_peak_while_driving_V',vShared,'same_timing',true);
fid = fopen(fullfile(fileparts(modelDir),'verification.json'),'w','n','UTF-8');
assert(fid>=0,'Cannot write the verification receipt.');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid,'%s\n',jsonencode(result,'PrettyPrint',true));
end

function [t,r,y] = run(model,c)
[t,r] = tdm_reference(c);
assignin(get_param(model,'ModelWorkspace'),'c',c);
out = sim(model);
y = out.trace;
assert(isequal(size(r),size(y)) && max(abs(t-out.tout))<1e-11);
end

function m = compare(t,r,y,c)
assert(all(isfinite(y),'all'));
flags = [1:4 9 15 20 21];
assert(isequal(r(:,flags),y(:,flags)), 'Timing or frame validity diverged.');
assert(~any(y(:,2)&y(:,3)) && ~any(y(:,4)&~y(:,3)));
assert(~any(y(y(:,4)==0,5:6),'all') && ~any(y(y(:,2)==0,7:8),'all'));
assert(all(y(y(:,9)>0,1)==c.validEnd), 'A fit was published before the window ended.');
assert(~any(y(:,21)), 'Reference should remain tracked in nominal cases.');
ticks = y(:,9)>0 & t>=.6;
assert(nnz(ticks)>100,'Insufficient settled frames.');
source = t(ticks)-(1+(c.n-1)/2)*c.Ts;
angle = y(ticks,14);
error = angle-angle(1)-c.omega*(source-source(1));
amp = sqrt(sum(y(ticks,10:13).^2,2));
deltaAngle = max(abs(r(:,14)-y(:,14)));
deltaIQ = max(abs(r(:,10:13)-y(:,10:13)),[],'all');
deltaDAC = max(abs(r(:,7:8)-y(:,7:8)),[],'all');
m = struct('body_rms_rad',sqrt(mean(error.^2)),'body_peak_rad',max(abs(error)), ...
    'minimum_amplitude',min(amp),'maximum_amplitude',max(amp),'settled_frames',nnz(ticks), ...
    'max_angle_delta_rad',deltaAngle,'max_IQ_delta',deltaIQ,'max_DAC_delta_V',deltaDAC, ...
    'source_to_publication_s',(1+(c.n-1)/2)*c.Ts);
assert(m.body_rms_rad<.01 && min(amp)>.85 && max(amp)<1.15, 'Synthetic body angle or amplitude out of range.');
assert(deltaAngle<1e-4 && deltaIQ<1e-4 && deltaDAC<5e-4, 'MATLAB and Simulink disagree.');
end
