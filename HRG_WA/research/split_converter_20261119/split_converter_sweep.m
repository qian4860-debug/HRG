function result = split_converter_sweep(root, outputFolder, bits, phases)
% 用第49号配阻复用逐拍模型检查量化后的低速方向、斜率误差及覆盖。
% 默认逐位输出JSON，便于并行或单独复算。相位仅改载波调制解调相对时隙的初相。
arguments
    root (1,:) char = fileparts(fileparts(fileparts(mfilename('fullpath'))))
    outputFolder (1,:) char = fileparts(mfilename('fullpath'))
    bits (1,1) double {mustBeMember(bits,[10,12,16])} = 12
    phases (1,:) double {mustBeFinite} = 0
end
source=fullfile(root,'research','three_angle_observation_20261115');
addpath(source,fullfile(root,'research','three_mode_split_20261113'));
cal=jsondecode(fileread(fullfile(source,'split_bias_verification.json')));
prior=jsondecode(fileread(fullfile(source,'split_bias_converter.json')));
weights=cal.modes(strcmp({cal.modes.mode},'tdm_shared')).calibration_rad_s;
windows=prior.windows_s;
rates=[-1 -.3 0 .3 1];  % 机体角速率，mrad/s
assert(~isempty(phases) && numel(unique(phases))==numel(phases),'初相必须互异。');
rows={}; pairs={};
for phase=phases
    for rate=rates
        extra=struct('Cs',720e-12,'bleed_R',1/(720e-12/2e-6-1e-10), ...
            'dac_bits',14,'diagnostic_carrier_phase_rad',deg2rad(phase));
        c=three_mode_split_config('tdm_shared',rate/1000,.05,28.125,.24,bits,extra);
        c.periodicCarrier=true; c.logDecimation=1;
        [~,trace,~,~,obs]=five_reference(c,false);
        t=obs(:,1)-obs(1,1); valid=all(obs(:,5:8)==1,2);
        nADC=sum(trace(:,20)~=0); nDAC=sum(trace(:,22)~=0); clear trace
        % 与第49号相同的全帧运行才可按原算法累计补偿，出现缺帧时标为未评分。
        err=NaN(2); sampleCounts=zeros(2,1);
        if all(valid) && nADC==0 && nDAC==0
            corrected=split_bias_angle(obs(:,4),obs(:,9),c.frame*c.Ts,weights,.05);
            for w=1:size(windows,1)
                in=t>=windows(w,1) & t<windows(w,2);
                sampleCounts(w)=nnz(in);
                x=t(in)-mean(t(in));
                err(w,:)=1000*(x'*[obs(in,9),corrected(in)]/(x'*x)-rate/1000);
            end
        end
        match=find([prior.cases.bits]==bits & abs(1000*[prior.cases.rate_rad_s]-rate)<1e-12);
        delta=NaN;
        if phase==0 && ~isempty(match)
            delta=max(abs(err-prior.cases(match).error_raw_corrected_mrad_s),[],'all');
            assert(delta<=1e-7,'历史子集回归偏差超过 1e-7 mrad/s。');
        end
        row=struct('phase_deg',phase,'truth_mrad_s',rate,'frames',numel(t), ...
            'valid_frames',nnz(valid),'adc_clip_ticks',nADC,'dac_clip_ticks',nDAC, ...
            'window_frames',sampleCounts,'raw_corrected_error_mrad_s',err, ...
            'corrected_output_mrad_s',err(:,2)+rate,'absolute_pass',abs(err(:,2))<=.25, ...
            'max_history_delta_mrad_s',delta);
        rows{end+1}=row; %#ok<AGROW>
        fprintf('ADC %2d, phase %5.1f, rate %+4.1f: corrected error %+8.4f mrad/s\n',bits,phase,rate,err(2,2));
    end
    cases=[rows{:}];
    for amplitude=[.3 1]
        pos=cases([cases.phase_deg]==phase & [cases.truth_mrad_s]==amplitude);
        neg=cases([cases.phase_deg]==phase & [cases.truth_mrad_s]==-amplitude);
        % 斜率增益消去相同常量偏置，因此正负方向与单点误差仍须独立检查。
        gain=(pos.corrected_output_mrad_s-neg.corrected_output_mrad_s)/(2*amplitude);
        directions=pos.corrected_output_mrad_s>0 & neg.corrected_output_mrad_s<0;
        pair=struct('phase_deg',phase,'amplitude_mrad_s',amplitude,'gain',gain, ...
            'directions_correct',directions,'pass',directions & abs(gain-1)<=.05 & pos.absolute_pass & neg.absolute_pass);
        pairs{end+1}=pair; %#ok<AGROW>
    end
end
result=struct('mode','tdm_shared','adc_bits',bits,'dac_bits',14,'fs_Hz',1/c.Ts, ...
    'adc_span_V',2,'gain',8,'beta_deg',28.125,'split_Hz',.05,'noise_rms_V',0, ...
    'dither_lsb_rms',0,'windows_s',windows,'absolute_limit_mrad_s',.25, ...
    'gain_tolerance',.05,'cases',[rows{:}],'pairs',[pairs{:}]);
filename=fullfile(outputFolder,sprintf('adc%d_comparison.json',bits));
fid=fopen(filename,'w','n','UTF-8'); assert(fid>=0);
cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',jsonencode(result,'PrettyPrint',true));
end
