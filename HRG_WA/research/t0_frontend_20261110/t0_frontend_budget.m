function report = t0_frontend_budget(outputPath,cvMode)
% T0 pre-bench estimates from the published 6800 Hz linear circuit model.
% Run with the head6800_20261109 folder on the MATLAB path.
arguments
    outputPath (1,:) char
    cvMode (1,:) char = 'thx2024'
end
tdm = h68_config('tdm_shared',0,struct('cv_mode',cvMode));
continuous = h68_config('continuous',0,struct('cv_mode',cvMode));
p = tdm.p;
phase = (0:tdm.n-1)' * tdm.Ts * tdm.w;
quadrature = (2/tdm.n) * [cos(phase), sin(phase)];
limit = min(tdm.adcStep/2, .001*tdm.gain_check.detector_V_per_normalized_charge);
report = struct('baseline','hrg-wa-6800-native-20261109', ...
    'scope','Linear model pre-bench estimate','cv_mode',cvMode, ...
    'nominal_carrier_adc_peak_V',tdm.gain_check.detector_V_per_normalized_charge, ...
    'tdm_half_adc_lsb_V',tdm.adcStep/2,'tdm_screen_limit_V',limit, ...
    'nominal_bleed_us',(tdm.senseStart-tdm.driveEnd)*tdm.Ts*1e6, ...
    'nominal_settle_us',(tdm.validStart-tdm.senseStart)*tdm.Ts*1e6, ...
    'nominal_frame_rate_Hz',1/(tdm.frame*tdm.Ts));

% Three separate uncertainty sources per channel. Set their magnitudes at
% drive release (electrode voltage and CV memory) or at sense closure (Qinj).
electrodeScale = tdm.electrode(1,7);
cvScale = p.charge_target/p.Cf;
release = zeros(tdm.stateCount,3);
release(7,1) = tdm.gain_check.electrode_limit_V/electrodeScale;
if strcmp(cvMode,'thx2024')
    % Static C/V has no feedback-capacitor state. Stress the downstream
    % AAF memory with 1 V at its output instead.
    release(17,2) = 1/tdm.pickoff(1,17);
else
    release(9,2) = 1/cvScale;
end
injection = zeros(size(release));
injection(7,3) = 1e-15/p.Cs/electrodeScale;
report.tdm_inputs = struct('release_electrode_V',tdm.gain_check.electrode_limit_V, ...
    'release_CV_memory_V',1,'sense_closure_injection_fC',1);

nominalSettle = tdm.validStart-tdm.senseStart;
maxSettle = ceil(350e-6/tdm.Ts);
report.tdm = [];
for bleed = [round([20 40 60]*1e-6/tdm.Ts),tdm.senseStart-tdm.driveEnd,round([100 120 140]*1e-6/tdm.Ts)]
    state = (tdm.Af^bleed)*release + injection;
    data = zeros(maxSettle+tdm.n,3);
    for sample = 1:size(data,1)
        data(sample,:) = tdm.pickoff(1,:)*state;
        state = tdm.As*state;
    end
    % At each instant the three disturbances may add with either polarity.
    envelope = sum(abs(data),2);
    peakByStart = movmax(envelope,[0 tdm.n-1],'Endpoints','discard');
    % Require all subsequent tested windows to meet the criterion as well.
    lastFailure = find(peakByStart>limit,1,'last');
    if isempty(lastFailure), lastFailure=0; end
    settle = lastFailure;
    if settle > maxSettle, settle=NaN; end
    nominalData = data(nominalSettle+(1:tdm.n),:);
    fit = quadrature'*nominalData;
    report.tdm = [report.tdm; struct('bleed_us',bleed*tdm.Ts*1e6, ...
        'settle_us_for_peak_limit',settle*tdm.Ts*1e6, ...
        'peak_at_nominal_settle_V',peakByStart(nominalSettle+1), ...
        'iq_bound_at_nominal_settle_V',sum(vecnorm(fit,2,1)), ...
        'peak_by_source_at_nominal_settle_V',max(abs(nominalData),[],1))]; %#ok<AGROW>
end
for row = report.tdm'
    contributions = row.peak_by_source_at_nominal_settle_V;
    assert(row.peak_at_nominal_settle_V >= max(contributions));
    assert(row.peak_at_nominal_settle_V <= sum(contributions)+eps);
end

% Direct electrical feedthrough only. The reference plane is the physical
% drive electrode, so the driver gain is already included in Vdrive.
p = continuous.p;
s = 1i*continuous.w;
h = (s/(s*p.Cs+1/p.Rs+p.G0)) / (p.Rs*p.Cf*(s+1/(p.Rf*p.Cf))) ...
    * p.pre_gain * (1/(1+s/(2*pi*p.afe_bw(1))))^p.aaf_order;
if strcmp(cvMode,'thx2024')
    h = (1-p.Cs*s/(s*p.Cs+1/p.Rs+p.G0)) ...
        * continuous.cvOutputGain/p.thx_charge_per_input ...
        * (1/(1+s/(2*pi*p.afe_bw(1))))^p.aaf_order;
end
report.continuous_direct_gain_V_per_V_per_pF = abs(h)*1e-12;
report.continuous = [];
for drive = [1 5 10]
    perPF = abs(h)*drive*1e-12;
    report.continuous = [report.continuous; struct('electrode_peak_V',drive, ...
        'coupling_pF',[.01 .1 1 10],'adc_feedthrough_peak_V',perPF*[.01 .1 1 10], ...
        'max_coupling_pF_for_point1_percent_nominal_signal', ...
        .001*continuous.gain_check.detector_V_per_normalized_charge/perPF, ...
        'max_coupling_pF_for_half_adc_lsb',continuous.adcStep/(2*perPF))]; %#ok<AGROW>
end
assert(abs(report.continuous(3).adc_feedthrough_peak_V(3) ...
    /report.continuous(1).adc_feedthrough_peak_V(2)-100)<1e-10);
[fid,msg] = fopen(outputPath,'w','n','UTF-8');
assert(fid>=0,msg);
cleanup = onCleanup(@() fclose(fid));
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));
end
