function result=three_angle_bias_converter_check(folder)
% 将已冻结的无量化标定表直接用于已有逐拍发布通路，观察 ADC/DAC 量化后的短窗迁移。
arguments
    folder (1,:) char=fileparts(mfilename('fullpath'))
end
addpath(fullfile(folder,'..','three_mode_split_20261113'));
previous=jsondecode(fileread(fullfile(folder,'split_bias_verification.json')));
shared=previous.modes(strcmp({previous.modes.mode},'tdm_shared'));
windows=[.02 .06;.16 .24]; rows={};
for bits=[10 16]
    for speed=[-.001 0 .001]
        c=three_mode_split_config('tdm_shared',speed,.05,28.125,.24,bits, ...
            struct('Cs',720e-12,'bleed_R',1/(720e-12/2e-6-1e-10),'dac_bits',14));
        c.periodicCarrier=true;c.logDecimation=1;
        [~,tr,~,~,obs]=five_reference(c,false);
        assert(all(obs(:,5:8)==1,'all') && ~any(tr(:,20)) && ~any(tr(:,22)));
        t=obs(:,1)-obs(1,1); dt=c.frame*c.Ts;
        % 第4列是量化后解调四倍角，第9列是现有原始发布角。
        comp=split_bias_angle(obs(:,4),obs(:,9),dt,shared.calibration_rad_s,.05);
        errorRate=zeros(2,2);
        for j=1:2
            used=t>=windows(j,1) & t<windows(j,2); x=t(used)-mean(t(used));
            errorRate(j,:)=1000*(x'*[obs(used,9),comp(used)]/(x'*x)-speed);
        end
        rows{end+1}=struct('bits',bits,'rate_rad_s',speed,'error_raw_corrected_mrad_s',errorRate, ...
            'full_and_unclipped',true); %#ok<AGROW>
        fprintf('%d bit %+.4g rad/s: final window raw %.4g corrected %.4g mrad/s\n', ...
            bits,speed,errorRate(2,1),errorRate(2,2));
    end
end
result=struct('windows_s',windows,'cases',[rows{:}],'source_mode','tdm_shared','dac_bits',14, ...
    'duration_s',.24,'full_scale_V',2,'beta_deg',28.125,'split_Hz',.05);
fid=fopen(fullfile(folder,'split_bias_converter.json'),'w','n','UTF-8');assert(fid>=0);
cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',jsonencode(result,'PrettyPrint',true));
end
