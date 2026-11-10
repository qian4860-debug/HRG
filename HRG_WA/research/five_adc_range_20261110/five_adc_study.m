function result = five_adc_study(outputPath)
% Fixed-frame ADC and guard-window study on the five-electrode TDM model.
arguments
    outputPath (1,:) char = fullfile(fileparts(mfilename('fullpath')),'adc_window_study.json')
end
here = fileparts(mfilename('fullpath'));
root = fileparts(fileparts(here));
modelDir = fullfile(root,'HRG_WA_simulink','piezo_v10','five_electrode_20261110');
addpath(modelDir,here);

% Frame indices are zero-based and fixed across all configurations.
% The anchor and score use distinct frame sets on a 1700 Hz frame grid.
anchorFrame = 68;
scoreFrames = (102:305)';
baselineSlots = [.5 1];
result = struct('matlab_release',version('-release'),'frame_Hz',1700, ...
    'score_anchor_frame',anchorFrame,'score_first_frame',scoreFrames(1), ...
    'score_last_frame',scoreFrames(end),'duration_s',.18, ...
    'adc_range_sweep',[],'operating_cases',[],'gain_screen',[], ...
    'noise_sensitivity',[],'window_sweep',[],'window_residual_screen',[], ...
    'baseline_window_sweep',[],'baseline_window_residual_screen',[], ...
    'native_parity',[]);

range = [2 1 10; 1 1 10; 2 2 10; 2 4 10; 2 6 10; 2 8 10; ...
    2 10 10; 2 12 10; 2 16 10; 2 1 20];
for k = 1:size(range,1)
    result.adc_range_sweep = [result.adc_range_sweep; ...
        runCase('range',.5,.4,false,range(k,:),baselineSlots,0,52)]; %#ok<AGROW>
end
assert(result.adc_range_sweep(1).complete_score && result.adc_range_sweep(end).complete_score);
% For an ideal quantizer, halving span or doubling post-combiner gain
% gives the same input-referred code step and angle trajectory.
assert(abs(result.adc_range_sweep(2).angle_rms_rad-result.adc_range_sweep(3).angle_rms_rad)<1e-11);
assert(result.adc_range_sweep(9).valid_clipped_samples>0, 'Missing overload control.');

% Predeclared holdout cases, independent of the initial nominal sweep.
% These are simulations with assumed geometry and electronics.
scenarios = {'zero',0,.4,false; 'positive_near_x',.5,.05,false; ...
    'negative_near_y',-4,1.52,false; 'positive_diagonal',4,pi/4,false; ...
    'seeded_start',.5,.4,true};
gains = [1 2 4 6 8 10];
for gain = gains
    for k = 1:size(scenarios,1)
        row = scenarios(k,:);
        result.operating_cases = [result.operating_cases; runCase(row{1}, ...
            row{2},row{3},row{4},[2 gain 10],baselineSlots,0,52)]; %#ok<AGROW>
    end
end

% Reserve a provisional 20% ADC headroom throughout the connected sensing
% window, including settle. The seed case is a headroom and availability
% test: the initial forced acquisition interval is not angle tracking.
screenHeadroom = .20;
for gain = gains
    holdout = result.operating_cases([result.operating_cases.gain]==gain);
    nominal = result.adc_range_sweep([result.adc_range_sweep.span_Vpp]==2 ...
        & [result.adc_range_sweep.gain]==gain & [result.adc_range_sweep.adc_bits]==10);
    allCases = [holdout;nominal];
    worstPeak = max([allCases.sense_peak_fraction_FS]);
    complete = all([allCases.complete_score]) && ~any([allCases.lost]);
    noClipping = all([allCases.valid_clipped_samples]==0);
    eligible = complete && noClipping && worstPeak<=1-screenHeadroom;
    tracked = allCases(~[allCases.seeded_start]);
    result.gain_screen = [result.gain_screen;struct('gain',gain, ...
        'worst_angle_rms_rad',max([tracked.angle_rms_rad]), ...
        'peak_fraction_FS',worstPeak,'complete',complete, ...
        'no_valid_clipping',noClipping,'eligible',eligible)]; %#ok<AGROW>
end
passed = result.gain_screen([result.gain_screen.eligible]);
assert(~isempty(passed),'No configuration passed the provisional headroom screen.');
[~,index] = min([passed.worst_angle_rms_rad]);
selectedGain = passed(index).gain;
result.provisional_gain = selectedGain;
result.provisional_headroom_fraction = screenHeadroom;
fprintf('Headroom screen picked %.0fx at 2 Vpp (simulation candidate)\n',selectedGain);

c = five_adc_study_config(.5,2,selectedGain,baselineSlots,struct( ...
    'duration',.5,'seed_enabled',true,'initial_fraction',0,'log_decimation',200));
[~,trace,frames,monitor] = five_reference(c);
late = measure(c,trace,frames,monitor,594,(595:849)');
assert(late.complete_score && all(late.amplitude_range >= .8 & late.amplitude_range <= 1.2));
late.first_valid_frame_s = frames(1,1);
late.score_anchor_frame = 594;
late.score_first_frame = 595;
late.score_last_frame = 849;
result.candidate_startup = late;
fprintf('Candidate startup: first valid %.6g s, RMS after 0.35 s %.6g rad\n', ...
    late.first_valid_frame_s,late.angle_rms_rad);

% The additive uniform-noise sensitivity level matches the datasheet's
% typical transition-noise RMS scale in volts. This is not a device model.
noiseRms = .4*2/2^10;
noiseCases = unique([2 1 10; 1 1 10; 2 2 10; 2 selectedGain 10],'rows','stable');
for k = 1:size(noiseCases,1)
    for seed = [52 109]
        result.noise_sensitivity = [result.noise_sensitivity; ...
            runCase('noise',.5,.4,false,noiseCases(k,:),baselineSlots,noiseRms,seed)]; %#ok<AGROW>
    end
end

[result.window_sweep,result.window_residual_screen] = sweepWindows(selectedGain);
if selectedGain~=1
    [result.baseline_window_sweep,result.baseline_window_residual_screen] = sweepWindows(1);
end

% Also prove the gain and window knobs run in the already delivered native
% model. A modified setup is passed as a workspace override.
if license('test','Simulink')
    result.native_parity = checkNative(modelDir,selectedGain);
else
    error('five_adc_study:MissingSimulink','Native verification requires Simulink.');
end
result.status = 'passed';
[fid,msg] = fopen(outputPath,'w','n','UTF-8');
assert(fid>=0,msg);
cleanup = onCleanup(@() fclose(fid));
fprintf(fid,'%s\n',jsonencode(result,'PrettyPrint',true));

    function r = runCase(label,omega,angle,seeded,setting,slots,noise,noiseSeed)
        c = five_adc_study_config(omega,setting(1),setting(2),slots, ...
            struct('adc_bits',setting(3),'theta0',angle,'duration',result.duration_s, ...
            'seed_enabled',seeded,'initial_fraction',double(~seeded), ...
            'adc_noise_rms',noise,'noise_seed',noiseSeed,'log_decimation',200));
        [~,trace,frames,monitor] = five_reference(c);
        assert(abs((1/c.Ts)/c.frame-result.frame_Hz)<1e-9);
        r = measure(c,trace,frames,monitor,anchorFrame,scoreFrames);
        r.case_id = label;
        r.rate_rad_s = omega;
        r.initial_modal_angle_rad = angle;
        r.seeded_start = seeded;
        r.span_Vpp = setting(1);
        r.gain = setting(2);
        r.adc_bits = setting(3);
        r.bleed_cycles = slots(1);
        r.settle_cycles = slots(2);
        r.noise_rms_V = noise;
        r.noise_seed = noiseSeed;
        fprintf('%s %gVpp x%g %db, bleed/settle %.2f/%.2f: peak %5.1f%%, RMS %.6g, valid %d/%d\n', ...
            label,setting(1),setting(2),setting(3),slots,100*r.sense_peak_fraction_FS, ...
            r.angle_rms_rad,r.scored_frames,numel(scoreFrames));
    end

    function [cases,bounds] = sweepWindows(gain)
        % First four rows trade bleed against settle at a fixed sample
        % phase. Last three move the start of the full-cycle window.
        windowSlots = [.25 1.25; .5 1; .75 .75; 1 .5; .5 .5; .5 .75; .5 1.25];
        cases = [];
        bounds = [];
        for row = 1:size(windowSlots,1)
            slots = windowSlots(row,:);
            cases = [cases; runCase('positive_nominal',.5,.4,false,[2 gain 10],slots,0,52); ...
                runCase('negative_near_y',-4,1.52,false,[2 gain 10],slots,0,52)]; %#ok<AGROW>
            bounds = [bounds;residualBound(five_adc_study_config(0,2,gain,slots))]; %#ok<AGROW>
        end
    end
end

function m = measure(c,trace,frames,mon,anchorFrame,scoreFrames)
valid = mon(:,2)>0;
sampleFrame = floor(mon(:,1)/c.frame);
scoreSample = valid & sampleFrame>=scoreFrames(1) & sampleFrame<=scoreFrames(end);
assert(nnz(scoreSample)==c.n*numel(scoreFrames),'Unexpected valid sample count in fixed window.');
adc = mon(:,5:6);
over = any(adc<c.adcMin | adc>c.adcMax,2);
assert(isequal(mon(:,9)>0,over & valid));
m = struct('sense_peak_fraction_FS',max(abs(adc),[],'all')/(c.p.adc_span/2), ...
    'valid_peak_fraction_FS',max(abs(adc(valid,:)),[],'all')/(c.p.adc_span/2), ...
    'score_clean_peak_by_axis_V',max(abs(mon(scoreSample,3:4)),[],1), ...
    'score_clean_peak_by_axis_codes',max(abs(mon(scoreSample,3:4)),[],1)/c.adcStep, ...
    'sense_peak_group_CV_V',max(abs(mon(:,10:13)),[],1), ...
    'valid_clipped_samples',nnz(over & valid), ...
    'prevalid_overrange_samples',nnz(over & ~valid), ...
    'adc_step_V',c.adcStep,'postcombiner_input_referred_step_V',c.adcStep/c.adcStudyGain, ...
    'lost',any(trace(:,21)),'scored_frames',0,'complete_score',false, ...
    'angle_rms_rad',NaN,'angle_mean_rad',NaN,'angle_std_rad',NaN, ...
    'angle_peak_rad',NaN,'amplitude_range',[NaN NaN], ...
    'score_quantization_rms_V',[NaN NaN], ...
    'score_calibrated_quantization_iq_rms',nan(1,4));

% Quantizer error against its actual noisy input, before angle computation.
% A clipped window has no meaningful unsaturated quantization metric.
if ~any(over(scoreSample))
    qerr = mon(scoreSample,7:8)-adc(scoreSample,:);
    phase = c.w*c.Ts*mon(scoreSample,1);
    ix = sampleFrame(scoreSample)-scoreFrames(1)+1;
    iq = zeros(numel(scoreFrames),4);
    for ch = 1:2
        iq(:,ch) = accumarray(ix,qerr(:,ch).*cos(phase));
        iq(:,ch+2) = accumarray(ix,qerr(:,ch).*sin(phase));
    end
    iq = (2/c.n)*(iq*c.detect');
    m.score_quantization_rms_V = sqrt(mean(qerr.^2,1));
    m.score_calibrated_quantization_iq_rms = sqrt(mean(iq.^2,1));
end
publishSlot = c.validEnd+c.adcLatency;
ids = floor(round(frames(:,1)/c.Ts)/c.frame);
assert(all(mod(round(frames(:,1)/c.Ts),c.frame)==publishSlot));
anchor = find(ids==anchorFrame,1);
[found,where] = ismember(scoreFrames,ids);
m.scored_frames = nnz(found);
m.complete_score = ~isempty(anchor) && all(found) && ~m.lost;
if ~m.complete_score, return; end

% Same anchor frame and evaluation frame IDs in every case. Convert
% publication to center to record the intended reference plane.
centerDelay = (publishSlot-(c.validStart+c.validEnd-1)/2)*c.Ts;
center = frames(:,1)-centerDelay;
y = frames(where,:);
err = y(:,15)-frames(anchor,15)-c.omega*(center(where)-center(anchor));
amp = sqrt(sum(y(:,11:14).^2,2));
m.angle_rms_rad = sqrt(mean(err.^2));
m.angle_mean_rad = mean(err);
m.angle_std_rad = std(err,1);
m.angle_peak_rad = max(abs(err));
m.amplitude_range = [min(amp),max(amp)];
end

function r = residualBound(c)
% Single additive event: independently signed ±10 V per group at drive
% release and ±1 fC per group at sense closure. Start all other states at
% zero. No AFE saturation, repeated-event memory or nonideal COM here.
release_V = 10;
inject_C = 1e-15;
voltageState = c.groupVoltage(:,7:10);
release = zeros(c.stateCount,4);
release(7:10,:) = voltageState\(release_V*eye(4));
injection = zeros(c.stateCount,4);
injection(7:10,:) = voltageState\(c.portCapacitance_F\(inject_C*eye(4)));
bleedTicks = c.senseStart-c.driveEnd;
settleTicks = c.validStart-c.senseStart;
state = [(c.Af^bleedTicks)*release,injection];
adcBound = zeros(settleTicks+c.n,2);
cvBound = zeros(settleTicks+c.n,4);
for k = 1:size(adcBound,1)
    adcBound(k,:) = sum(abs(c.pickoff*state),2)';
    cvBound(k,:) = sum(abs(c.portCV*state),2)';
    state = c.As*state;
end
r = struct('bleed_us',1e6*c.Ts*bleedTicks,'settle_us',1e6*c.Ts*settleTicks, ...
    'release_V_per_group',release_V,'injection_fC_per_group',1, ...
    'adc_residual_peak_sense_V',max(adcBound,[],'all'), ...
    'adc_residual_peak_valid_V',max(adcBound(settleTicks+1:end,:),[],'all'), ...
    'group_CV_residual_peak_sense_V',max(cvBound,[],'all'), ...
    'group_CV_residual_peak_valid_V',max(cvBound(settleTicks+1:end,:),[],'all'));
end

function cases = checkNative(modelDir,gain)
model = 'hrg_5e_tdm_shared';
assert(~bdIsLoaded(model),'Close the TDM model before running this study.');
load_system(fullfile(modelDir,'models',[model '.slx']));
cleanup = onCleanup(@() close_system(model,0));
cases = [];
for slots = [.5 1; .5 .75]'
    c = five_adc_study_config(.5,2,gain,slots',struct('duration',.006,'log_decimation',1));
    [t,ref,refFrames,mon] = five_reference(c);
    [t2,ref2,refFrames2] = five_reference(c);
    assert(isequal(t,t2) && isequal(ref,ref2) && isequal(refFrames,refFrames2), ...
        'Monitor collection must leave the three existing outputs identical.');
    assert(size(mon,2)==13 && any(mon(:,2)) && any(~mon(:,2)));
    in = Simulink.SimulationInput(model);
    in = in.setVariable('c',c,'Workspace',model);
    in = in.setModelParameter('SaveTime','off');
    out = sim(in);
    assert(isequal(size(ref),size(out.trace)) && isequal(size(refFrames),size(out.frames)));
    flags = [1:4 9 15 20:22];
    assert(isequal(ref(:,flags),out.trace(:,flags)));
    maxDelta = max(abs(ref-out.trace),[],'all');
    assert(maxDelta<1e-4 && max(abs(refFrames-out.frames),[],'all')<1e-4);
    cases = [cases;struct('gain',gain,'bleed_cycles',slots(1), ...
        'settle_cycles',slots(2),'samples',size(ref,1),'frames',size(refFrames,1), ...
        'max_trace_delta',maxDelta)]; %#ok<AGROW>
end
end
