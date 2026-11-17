function result=three_angle_numeric_lift_verify(folder,rebuild)
% 第48号：公共周期载波修复验证 + 无量化帧级提升模型的逐拍、原生及长时对照。
arguments
    folder (1,:) char = fileparts(mfilename('fullpath'))
    rebuild (1,1) logical = true
end
addpath(fullfile(folder,'..','three_mode_split_20261113'));
modes={'continuous','tdm_separate','tdm_shared'};
models={'hrg_periodic_continuous','hrg_periodic_separate','hrg_periodic_shared'};
cfg=cell(1,3);
for k=1:3
    cfg{k}=three_mode_split_config(modes{k},0,.05,22.5,.12,16,struct('Cs',720e-12,'bleed_R',1/(720e-12/2e-6-1e-10)));
    cfg{k}.periodicCarrier=true;cfg{k}.logDecimation=1;
end
modelDir=fullfile(folder,'periodic_models');
if rebuild,h68_build(modelDir,models,cfg,false,true,true);end
rows={};
for k=1:3
    c=cfg{k};m=models{k};load_system(fullfile(modelDir,[m '.slx']));
    cleanup=onCleanup(@() close_system(m,0));
    [~,tr,fr,~,az]=five_reference(c,false);
    in=Simulink.SimulationInput(m);in=in.setVariable('c',c,'Workspace',m);native=sim(in);
    d=az(:,2:4)-native.angleCandidates(:,2:4); angle=max(abs(atan2(sin(d),cos(d))),[],'all');
    codes=nnz(tr(:,5:8)~=native.trace(:,5:8));
    events=isequal(tr(:,[1:4 9 15 20:22]),native.trace(:,[1:4 9 15 20:22]));
    assert(events && angle<1e-7);
    rows{end+1}=struct('mode',c.mode,'converter_mismatches',codes,'events_equal',events, ...
        'max_angle_delta_rad',angle,'max_frames_delta',max(abs(fr-native.frames),[],'all')); %#ok<AGROW>
    fprintf('Periodic %s codes %d angle %.3g rad\n',c.mode,codes,angle);
    clear cleanup
end
shorts={};longs={};
for k=2:3
    % 40位仅作为无量化的数值近似基准，不是硬件位数建议。
    c=three_mode_split_config(modes{k},0,.05,22.5,.12,40, ...
        struct('Cs',720e-12,'bleed_R',cfg{k}.p.bleed_R,'dac_bits',40));
    c.periodicCarrier=true;c.logDecimation=1;
    tic; L=three_angle_frame_lift(c);precompute=toc;
    tic;[~,trace,~,~,angles]=five_reference(c,false);fullTime=toc;
    tic;lift=three_angle_lift_run(c,L);liftTime=toc;
    assert(all(lift.angleCandidates(:,5:8)==1,'all') && lift.rail_free);
    assert(isequal(size(angles),size(lift.angleCandidates)));
    d=angles(:,2:4)-lift.angleCandidates(:,2:4);err=max(abs(atan2(sin(d),cos(d))),[],'all');
    assert(err<1e-7 && ~any(trace(:,20)) && ~any(trace(:,22)));
    source=models{k};load_system(fullfile(modelDir,[source '.slx']));
    m=three_angle_lift_native_build(c,L,fullfile(folder,'lift_models'),source);close_system(source,0);
    load_system(fullfile(folder,'lift_models',[m '.slx']));
    out=sim(m);close_system(m,0);
    delta=max(abs(out.liftTrace-lift.trace),[],'all');assert(delta<1e-7);
    shorts{end+1}=struct('mode',c.mode,'max_candidate_angle_delta_rad',err, ...
        'max_native_lift_trace_delta',delta,'precompute_seconds',precompute, ...
        'full_reference_seconds',fullTime,'lift_reference_seconds',liftTime, ...
        'rail_free',lift.rail_free,'adc_bound_V',lift.adc_conservative_peak_bound_V, ...
        'adc_peak_V',lift.adc_reconstructed_peak_V,'dac_bound_V',lift.dac_peak_bound_V); %#ok<AGROW>
    fprintf('Lift %s angle %.3g, native %.3g, speed %.1fx\n',c.mode,err,delta,fullTime/liftTime);
    % 验证初角镜像和正低速的短时迁移；不从名义误差拟合修正参数。
    for condition=1:2
        rate=0;beta=rad2deg(c.p.stiffness_axis)-22.5;
        if condition==2,rate=.05;beta=22.5;end
        cx=three_mode_split_config(modes{k},rate,.05,beta,.06,40, ...
            struct('Cs',720e-12,'bleed_R',c.p.bleed_R,'dac_bits',40));cx.periodicCarrier=true;
        lx=three_angle_frame_lift(cx);s=three_angle_lift_run(cx,lx);
        [~,~,~,~,a]=five_reference(cx,false);
        d=a(:,2:4)-s.angleCandidates(:,2:4);e=max(abs(atan2(sin(d),cos(d))),[],'all');
        assert(e<1e-7 && all(s.angleCandidates(:,5:8)==1,'all') && s.rail_free);
        shorts{end+1}=struct('mode',sprintf('%s_holdout%d',c.mode,condition), ...
            'max_candidate_angle_delta_rad',e,'max_native_lift_trace_delta',NaN, ...
            'precompute_seconds',NaN,'full_reference_seconds',NaN,'lift_reference_seconds',NaN, ...
            'rail_free',s.rail_free,'adc_bound_V',s.adc_conservative_peak_bound_V, ...
            'adc_peak_V',s.adc_reconstructed_peak_V,'dac_bound_V',s.dac_peak_bound_V); %#ok<AGROW>
    end
    c.duration=20;tic;long=three_angle_lift_run(c,L);elapsed=toc;
    assert(all(long.angleCandidates(:,5:8)==1,'all') && long.rail_free);
    [series,~]=three_angle_series(c,long.angleCandidates,0);
    windows=[.02 .06;.08 .12;1 2;5 6;10 11;19 20];scores=zeros(size(windows,1),3);
    for j=1:size(windows,1)
        use=series.t_center_s>=windows(j,1) & series.t_center_s<windows(j,2);
        t=series.t_center_s(use); cols={'mechanical_minus_truth_rad','clean_cv_minus_mechanical_rad','published_minus_truth_rad'};
        for z=1:3,p=polyfit(t-t(1),series.(cols{z})(use),1);scores(j,z)=p(1)*1000;end
    end
    writetable(series,fullfile(folder,[c.mode '_lift_20s.csv']));
    longs{end+1}=struct('mode',c.mode,'duration_s',20,'runtime_s',elapsed, ...
        'window_edges_s',windows,'slopes_mechanical_readout_total_mrad_s',scores, ...
        'rail_free',long.rail_free,'adc_bound_V',long.adc_conservative_peak_bound_V, ...
        'adc_peak_V',long.adc_reconstructed_peak_V,'dac_bound_V',long.dac_peak_bound_V); %#ok<AGROW>
end
result=struct('status','passed_scoped_checks','periodic_parity',[rows{:}], ...
    'lift_short_checks',[shorts{:}],'lift_long_runs',[longs{:}], ...
    'scope','TDM frame lift is unquantized, noiseless and full-valid only; excludes continuous delayed control and low-bit behavior.');
fid=fopen(fullfile(folder,'numeric_lift_verification.json'),'w','n','UTF-8');assert(fid>=0);
cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',jsonencode(result,'PrettyPrint',true));
end
