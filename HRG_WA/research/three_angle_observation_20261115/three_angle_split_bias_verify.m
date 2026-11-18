function report=three_angle_split_bias_verify(folder)
% 第49号。零速训练冻结后，只把观察角、原发布角、标定表和独立频差读数交给补偿器。
arguments
    folder (1,:) char=fileparts(mfilename('fullpath'))
end
addpath(fullfile(folder,'..','three_mode_split_20261113'));
modes={'tdm_separate','tdm_shared'};
windows=[.02 .06;.08 .12;1 2;5 6;10 11;19 20];
trainAngles=0:11.25:78.75;
% 训练角与下列留出角分开。±0.0003 rad/s接近评分门限，另检验方向与成对增益。
conditions=[
    5.625  .05   .05    0
    28.125 .05   .05    0
    61.875 .05   .05    0
    28.125 .05   .05   -.0003
    28.125 .05   .05    .0003
    28.125 .05   .05   -.001
    28.125 .05   .05    .001
    28.125 .05   .05   -.05
    28.125 .05   .05    .05
    28.125 .025  .025   0
    28.125 .025  .025  -.001
    28.125 .025  .025   .001
    28.125 -.05 -.05    0
    28.125 0      0     0
    28.125 .025  .05    0
    28.125 0     .05    0
];
byMode=cell(1,2);
for m=1:2
    mode=modes{m};
    % 每个方向给一个独立零速斜率方程。对基函数先积分后按同窗拟合斜率。
    calibration=zeros(5,2); designCond=zeros(1,2); residual=zeros(1,2);
    for col=1:2
        split=(col-1)*.05; design=zeros(numel(trainAngles),5); target=zeros(numel(trainAngles),1);
        for j=1:numel(trainAngles)
            [obs,dt]=trajectory(mode,0,split,trainAngles(j),4);
            t=obs(:,1)-obs(1,1); mask=t>=1 & t<4; az=obs(:,4);
            X=[ones(size(t)),cos(az),sin(az),cos(2*az),sin(2*az)];
            cumulative=[zeros(1,5);cumsum(X(1:end-1,:),1)*dt];
            design(j,:)=slope(t(mask),cumulative(mask,:));
            target(j)=slope(t(mask),obs(mask,9));
        end
        assert(rank(design)==5); designCond(col)=cond(design);
        calibration(:,col)=design\target;
        residual(col)=max(abs(design*calibration(:,col)-target))*1000;
    end
    cases=cell(1,size(conditions,1)); parity={}; pairs={};
    for j=1:size(conditions,1)
        beta=conditions(j,1); split=conditions(j,2); measured=conditions(j,3); rate=conditions(j,4);
        [obs,dt,c,L]=trajectory(mode,rate,split,beta,20);
        t=obs(:,1)-obs(1,1); raw=obs(:,9);
        [corrected,~,weights]=split_bias_angle(obs(:,4),raw,dt,calibration,measured);
        outputs=[raw corrected]; measuredRates=zeros(size(windows,1),2);
        for w=1:size(windows,1)
            mask=t>=windows(w,1) & t<windows(w,2);
            measuredRates(w,:)=slope(t(mask),outputs(mask,:));
        end
        errors=1000*(measuredRates-rate); late=errors(3:end,:);
        cases{j}=struct('beta_deg',beta,'plant_split_Hz',split,'supplied_split_Hz',measured, ...
            'truth_rad_s',rate,'error_raw_corrected_mrad_s',errors, ...
            'end_error_raw_corrected_mrad',1000*(outputs(end,:)-outputs(1,:)-rate*t(end)), ...
            'late_pass',all(abs(late)<=.25,1),'all_window_pass',all(abs(errors)<=.25,1));
        if j==6 || j==12
            parity{end+1}=split_bias_native_check(folder,mode,c,L,weights,raw,corrected,j); %#ok<AGROW>
        end
    end
    pairIndex=[4 5;6 7;8 9;11 12];
    for j=1:size(pairIndex,1)
        a=cases{pairIndex(j,1)}; b=cases{pairIndex(j,2)}; speed=b.truth_rad_s;
        neg=a.error_raw_corrected_mrad_s/1000-speed; pos=b.error_raw_corrected_mrad_s/1000+speed;
        gain=(pos-neg)/(2*speed); signs=neg<0 & pos>0;
        pairs{end+1}=struct('speed_rad_s',speed,'split_Hz',b.plant_split_Hz, ...
            'gain_raw_corrected',gain,'directions_correct_raw_corrected',signs, ...
            'late_gain_and_direction_pass',all(abs(gain(3:end,:)-1)<=.05 & signs(3:end,:),1)); %#ok<AGROW>
    end
    byMode{m}=struct('mode',mode,'calibration_rad_s',calibration,'design_condition',designCond, ...
        'max_training_error_mrad_s',residual,'cases',[cases{:}],'rate_pairs',[pairs{:}],'native_checks',[parity{:}]);
end
for bad=[NaN Inf .051]
    try
        split_bias_angle(0,0,1,calibration,bad);
        error('gyro:UnexpectedPass','超界测试未拒绝');
    catch ex
        assert(strcmp(ex.identifier,'gyro:SplitOutsideCalibration'));
    end
end
report=struct('scope','Synthetic noiseless full-valid TDM frame model, frozen output correction', ...
    'training_beta_deg',trainAngles,'training_window_s',[1 4],'test_windows_s',windows, ...
    'absolute_budget_mrad_s',.25,'pair_gain_tolerance',.05,'rejected_split_inputs',{{'NaN','Inf','0.051 Hz'}},'modes',[byMode{:}]);
fid=fopen(fullfile(folder,'split_bias_verification.json'),'w','n','UTF-8');assert(fid>=0);
cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));
end

function [obs,dt,c,L]=trajectory(mode,rate,split,beta,duration)
% 标定/评分使用机体速率设置仿真工况。补偿器与反馈命令无连接。
c=three_mode_split_config(mode,rate,split,beta,duration,40,struct('Cs',720e-12, ...
    'bleed_R',1/(720e-12/2e-6-1e-10),'dac_bits',40)); c.periodicCarrier=true;
L=three_angle_frame_lift(c); run=three_angle_lift_run(c,L);
obs=run.angleCandidates; dt=L.T;
assert(all(obs(:,5:8)==1,'all') && run.rail_free);
end

function value=slope(t,v)
% 共用一组时间权重，分别得到各列斜率，角度单位rad、时间单位s。
center=t-mean(t);value=(center'*v)/(center'*center);
end
