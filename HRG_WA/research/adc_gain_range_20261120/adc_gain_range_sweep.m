function result=adc_gain_range_sweep(profile,root,folder)
% 第54号配阻复用前端逐拍试验。profile 为下列表格行号，可分进程独立运行。
% 每个数值工况先检查接通段/有效采样段的模拟输入，再独立评分量化闭环。
arguments
    profile (1,1) double {mustBeInteger,mustBePositive}
    root (1,:) char = fileparts(fileparts(fileparts(mfilename('fullpath'))))
    folder (1,:) char = fileparts(mfilename('fullpath'))
end
% 各列为 ADC 位数、双通道共同前置增益、ADC 跨正负量程 Vpp、初始驻波角 deg。
% 第2/3行输入折算LSB相同。第7/8行LSB相同但输入限幅不同，能检验余量。
settings=[12 8 2 28.125;12 16 2 28.125;12 8 1 28.125;12 32 2 28.125; ...
          12 48 2 28.125;12 64 2 28.125;12 128 2 28.125;16 8 2 28.125; ...
          12 10 2 28.125;12 12 2 28.125;12 14 2 28.125;12 7 1 28.125;12 14 2 61.875;12 10 2 5.625];
assert(profile<=size(settings,1)); s=settings(profile,:); bits=s(1); gain=s(2); span=s(3); beta=s(4);
obsDir=fullfile(root,'research','three_angle_observation_20261115');
addpath(obsDir,fullfile(root,'research','three_mode_split_20261113'));
frozen=jsondecode(fileread(fullfile(obsDir,'split_bias_verification.json')));
W=frozen.modes(strcmp({frozen.modes.mode},'tdm_shared')).calibration_rad_s;
windows=[.02 .06;.16 .24]; rates=[-1 -.3 0 .3 1]; rows={};
for rate=rates
    extra=struct('Cs',720e-12,'bleed_R',1/(720e-12/2e-6-1e-10),'dac_bits',14,'adc_span',span);
    c=three_mode_split_config('tdm_shared',rate/1000,.05,beta,.24,bits,extra);
    % 基线在 THX C/V 的模拟电压之后已有 8 倍投影及对应数字逆增益。
    % 同时调整两路的输出投影和逆增益，维持检测器标度；DAC 力增益不动。
    oldMap=c.detect*blkdiag(c.pickoff,c.pickoff); relative=gain/8;
    c.portSenseMap=c.portSenseMap*relative;
    c.pickoff=c.portSenseMap*c.portCV;
    c.detect=c.detect/relative;
    c.gain_check.detector_V_per_normalized_charge=c.gain_check.detector_V_per_normalized_charge*relative;
    assert(norm(c.detect*blkdiag(c.pickoff,c.pickoff)-oldMap,'fro')<=1e-12*max(norm(oldMap,'fro'),1));
    c.periodicCarrier=true; c.logDecimation=1;
    [~,trace,~,mon,obs]=five_reference(c,true);
    % ADC 流水线之前取模拟电压。监视器包含预热接通段和参与解调的有效段。
    active=mon(:,2)==1; volts=mon(:,5:6); validV=volts(active,:);
    margin=@(v) min(min(v,[],'all')-c.adcMin,c.adcMax-max(v,[],'all'));
    peak=[max(abs(volts),[],'all'),max(abs(validV),[],'all')];
    headroom=[margin(volts),margin(validV)];
    nADC=nnz(mon(:,9)); nDAC=nnz(trace(:,22)); clear mon trace volts validV
    t=obs(:,1)-obs(1,1); valid=all(obs(:,5:8)==1,2); err=nan(2,1);
    if all(valid) && nADC==0 && nDAC==0
        angle=split_bias_angle(obs(:,4),obs(:,9),c.frame*c.Ts,W,.05);
        for w=1:2
            ix=t>=windows(w,1) & t<windows(w,2); x=t(ix)-mean(t(ix));
            err(w)=1000*(x'*angle(ix))/(x'*x)-rate;
        end
    end
    rows{end+1}=struct('rate_mrad_s',rate,'frame_count',numel(t),'valid_frames',nnz(valid), ...
        'connected_valid_peak_V',peak,'connected_valid_margin_V',headroom, ...
        'adc_clipped_ticks',nADC,'dac_clipped_ticks',nDAC,'corrected_error_mrad_s',err, ...
        'corrected_rate_mrad_s',err+rate,'individual_pass',abs(err)<=.25); %#ok<AGROW>
    fprintf('profile %d, speed %g: peak %.5g V, valid margin %.5g V, ADC clips %d, late error %g\n', ...
        profile,rate,peak(1),headroom(2),nADC,err(2));
end
result=struct('profile',profile,'mode','tdm_shared','adc_bits',bits,'gain',gain, ...
    'span_Vpp',span,'input_lsb_uV',1e6*span/2^bits/gain,'beta_deg',beta, ...
    'split_Hz',.05,'dac_bits',14,'fs_Hz',1/c.Ts,'noise_V_rms',0,'rate_windows_s',windows,'cases',[rows{:}]);
fid=fopen(fullfile(folder,sprintf('profile_%02d.json',profile)),'w','n','UTF-8'); assert(fid>=0);
cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',jsonencode(result,'PrettyPrint',true));
end
