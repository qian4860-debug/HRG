function receipt = three_angle_native_verify(outDir)
% Compare all candidate angles as well as the original closed-loop trace.
arguments
    outDir (1,:) char = fullfile(fileparts(mfilename('fullpath')),'models')
end
models = three_angle_native_build(outDir);
modes = {'continuous','tdm_separate','tdm_shared'};
cases = {
    'zero_split',          0,      0,   16
    'positive_low_rate',   .005,   .05, 16
    'negative_low_rate',   -.005,  .05, 16
    'ten_bit',              .5,    .05, 10
    'adc_overload',        0,      .05, 16
    'dac_startup_clip',    0,      .05, 16
    };
checks = [];
for k = 1:numel(models)
    model = models{k};
    load_system(fullfile(outDir,[model '.slx']));
    cleanup = onCleanup(@() close_system(model,0));
    blocks = find_system(model,'LookUnderMasks','all','FollowLinks','on','Type','Block');
    blockTypes = get_param(blocks,'BlockType');
    assert(~any(ismember(blockTypes, ...
        {'MATLABFcn','InterpretedMATLABFcn','S-Function','MATLABSystem','FromWorkspace'})));
    assert(isempty(find_system(model,'SFBlockType','MATLAB Function')));
    assert(getSimulinkBlockHandle([model '/Three angle observations'])>0);
    for row = 1:size(cases,1)
        [scenario,rate,split,bits] = deal(cases{row,:});
        c = three_mode_split_config(modes{k},rate,split,22.5,.006,bits);
        c.logDecimation = 1;
        switch scenario
            case 'adc_overload'
                clipCode = floor(.02/c.adcStep);
                c.adcMin = -clipCode*c.adcStep;
                c.adcMax = (clipCode-1)*c.adcStep;
            case 'dac_startup_clip'
                c.p.seed_enabled = true;
                c.p.seed_seconds = 3*c.Ts*c.n;
                c.seedCommand = [2*c.dacMax;0;0;0];
        end
        result = verifyCase(model,c);
        result.mode = modes{k};
        result.scenario = scenario;
        result.rate_rad_s = rate;
        result.split_Hz = split;
        result.adc_bits = bits;
        if strcmp(scenario,'adc_overload')
            assert(result.adc_clipped_samples>0 && result.published_frames==0);
        else
            assert(result.published_frames>0);
        end
        if strcmp(scenario,'dac_startup_clip')
            assert(result.dac_clipped_samples>0);
        end
        checks = [checks;result]; %#ok<AGROW>
        fprintf('%s %s: candidates %d, published %d, azimuth delta %.3g\n', ...
            modes{k},scenario,result.candidate_rows,result.published_frames,result.azimuth_delta_rad);
    end
    clear cleanup
end
receipt = struct('status','passed','release',version('-release'),'checks',checks);
[fid,message] = fopen(fullfile(fileparts(mfilename('fullpath')), ...
    'three_angle_native_verification.json'),'w','n','UTF-8');
assert(fid>=0,'Could not write verification receipt: %s',message);
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',jsonencode(receipt,'PrettyPrint',true));
end

function result = verifyCase(model,c)
[~,trace,frames,~,expected] = five_reference(c);
input = Simulink.SimulationInput(model);
input = input.setVariable('c',c,'Workspace',model);
input = input.setModelParameter('SaveTime','off');
out = sim(input);
actual = out.angleCandidates;
assert(size(expected,2)==10 && isequal(size(actual),size(expected)));
assert(isequal(actual(:,5:8),expected(:,5:8)) && isequal(actual(:,10),expected(:,10)));
assert(isequal(out.trace(:,5:8),trace(:,5:8)),'ADC or DAC code changed.');
events = [1:4 9 15 20:22];
assert(isequal(out.trace(:,events),trace(:,events)),'Control or navigation event changed.');
traceDelta = maxDifference(out.trace,trace);
framesDelta = maxDifference(out.frames,frames);
assert(traceDelta<1e-8 && framesDelta<1e-8);
captureTimes = (c.validEnd+c.adcLatency+(0:size(actual,1)-1)'*c.frame)*c.Ts;
assert(maxDifference(actual(:,1),captureTimes)<1e-12);
assert(maxDifference(actual(logical(actual(:,8)),1),frames(:,1))<1e-12);
azDiff = actual(:,2:4)-expected(:,2:4);
azDelta = max(abs(atan2(sin(azDiff),cos(azDiff))),[],'all');
bodyDelta = maxDifference(actual(:,9),expected(:,9));
assert(azDelta<1e-8 && bodyDelta<1e-8);
result = struct('candidate_rows',size(actual,1),'published_frames',size(frames,1), ...
    'adc_clipped_samples',nnz(trace(:,20)),'dac_clipped_samples',nnz(trace(:,22)), ...
    'azimuth_delta_rad',azDelta,'held_body_delta_rad',bodyDelta, ...
    'trace_max_delta',traceDelta,'frames_max_delta',framesDelta);
end

function difference = maxDifference(actual,expected)
assert(isequal(size(actual),size(expected)));
difference = max([0;abs(actual(:)-expected(:))]);
end
