function result=three_angle_drift_quant_verify(outDir,rebuild)
% 第47号：频差/初角消融与量化对照。三个角观测只读，未知真值不进入控制器。
% 保留 THX2024 前置增益；改变 ADC 量程、位数或加性非减法抖动，不改模拟前置链。
arguments
    outDir (1,:) char = fileparts(mfilename('fullpath'))
    rebuild (1,1) logical = true
end
here=fileparts(mfilename('fullpath'));
addpath(here,fullfile(here,'..','three_mode_split_20261113'), ...
    fullfile(here,'..','..','HRG_WA_simulink','piezo_v10','head6800_20261109'));
base=three_mode_split_config('tdm_shared',0,.05,22.5,.12,16);
% 模态坐标 theta=2*beta；镜像 theta'=2*stiffness_axis-theta。
axisBeta=rad2deg(base.p.stiffness_axis)/2;
mirror=2*axisBeta-22.5;
R=1/(720e-12/2e-6-base.p.G0);
common=struct('Cs',720e-12,'bleed_R',R);
modes={'continuous','tdm_separate','tdm_shared'};
jobs={};
for mode=1:3
    for beta=[22.5 mirror]
        for split=[0 .05]
            label=sprintf('%s_beta%.5f_split%.3f',modes{mode},beta,split);
            append(label,modes{mode},0,split,beta,16,struct());
        end
    end
end
append('shared_negative_split','tdm_shared',0,-.05,22.5,16,struct());
append('shared_negative_split_mirror','tdm_shared',0,-.05,mirror,16,struct());
append('shared_on_axis','tdm_shared',0,.05,axisBeta,16,struct());
append('shared_quad_off','tdm_shared',0,.05,22.5,16,struct('quad_bw',0));
append('shared_adc12','tdm_shared',0,.05,22.5,12,struct());
append('shared_adc10','tdm_shared',0,.05,22.5,10,struct());
append('shared_adc10_span1p5','tdm_shared',0,.05,22.5,10,struct('adc_span',1.5));
seeds={[1103515245;2246822519],[12345;987654321],[314159265;271828183]};
for k=1:3
    append(sprintf('shared_adc10_dither_seed%d',k),'tdm_shared',0,.05,22.5,10, ...
        struct('adc_dither_lsb_rms',.5,'adc_dither_seeds',seeds{k}));
end
% 固定 0.5 LSB RMS 候选后评估正负低速，不能挑选表现最好的种子作为结论。
for rate=[-.05 .05]
    append(sprintf('holdout_rate%+.2f_plain',rate),'tdm_shared',rate,.05,22.5,10,struct());
    append(sprintf('holdout_rate%+.2f_dither',rate),'tdm_shared',rate,.05,22.5,10, ...
        struct('adc_dither_lsb_rms',.5,'adc_dither_seeds',seeds{2}));
end
models={'hrg_dq_continuous','hrg_dq_separate','hrg_dq_shared'};
configs=cell(1,3);
for k=1:3, configs{k}=three_mode_split_config(modes{k},0,.05,22.5,.12,16,common); end
modelDir=fullfile(outDir,'drift_quant_models');
% 显式生成原生抖动支路，零幅度时应仍与既有 MATLAB 参考逐码一致。
if rebuild, h68_build(modelDir,models,configs,false,true,true); end
cleanup=onCleanup(@() closeModels(models)); %#ok<NASGU>
for k=1:3
    load_system(fullfile(modelDir,[models{k} '.slx']));
    blocks=find_system(models{k},'LookUnderMasks','all','FollowLinks','on','Type','Block');
    assert(~any(ismember(get_param(blocks,'BlockType'), ...
        {'MATLABFcn','InterpretedMATLABFcn','S-Function','MATLABSystem','FromWorkspace'})));
    assert(isempty(find_system(models{k},'SFBlockType','MATLAB Function')));
end
rows={}; parityRows={};
for k=1:numel(jobs)
    c=jobs{k}.config; c.logDecimation=1;
    [~,trace,frames,analog,angles]=five_reference(c,true);
    [series,metrics]=three_angle_series(c,angles,.02);
    assert(metrics.expected_candidates==metrics.observed_candidates);
    windows=[.02 .06;.08 .12]; scores=cell(1,2);
    for w=1:2, scores{w}=windowScore(series,windows(w,:),c); end
    peak=max(abs(analog(:,5:6)),[],'all');
    full=metrics.accepted_candidates==metrics.expected_candidates;
    noClip=~any(trace(:,20)) && ~any(trace(:,22));
    row=struct('label',jobs{k}.label,'mode',c.mode,'split_Hz',c.p.split_hz, ...
        'beta_deg',jobs{k}.beta,'omega_rad_s',c.omega,'adc_bits',c.p.adc_bits, ...
        'adc_span_V',c.p.adc_span,'dither_lsb_rms',c.p.adc_dither_lsb_rms, ...
        'dither_seeds',c.p.adc_dither_seeds','quad_bw_Hz',c.p.quad_bw, ...
        'full_publication',full,'no_clipping',noClip,'peak_adc_V',peak, ...
        'peak_fraction_half_span',peak/(c.p.adc_span/2),'windows',[scores{:}]);
    row.offline_absolute_screen_pass=full && noClip && row.peak_fraction_half_span<.8 && ...
        all([row.windows.all_frames_usable]) && all(abs([row.windows.total_mrad_s])<=.25);
    rows{end+1}=row; %#ok<AGROW>
    fprintf('%02d %s: early %.6f late %.6f; mech %.6f quant %.6f mrad/s\n', ...
        k,row.label,scores{1}.total_mrad_s,scores{2}.total_mrad_s, ...
        scores{2}.mechanical_mrad_s,scores{2}.publication_mrad_s);
    % 三模式名义工况 + 10 位基线 + 启用抖动的一个种子做完整原生对拍。
    nativeCase=(k==2 || k==6 || k==10 || k==18 || k==20);
    if nativeCase
        mi=find(strcmp(modes,c.mode));
        parityRows{end+1}=parity(models{mi},c,trace,frames,angles,row.label); %#ok<AGROW>
    end
end
% 长时量化阈值分歧不能靠放宽门限抹掉；三版另做短时逐码回归并分别报告。
for k=1:3
    c=configs{k}; c.duration=.006; c.logDecimation=1;
    [~,trace,frames,~,angles]=five_reference(c,false);
    p=parity(models{k},c,trace,frames,angles,['short_' modes{k}]);
    assert(p.converter_mismatches==0 && p.angle_gate_pass);
    parityRows{end+1}=p; %#ok<AGROW>
end
result=struct('status','completed_with_explicit_parity_gates','release',version('-release'), ...
    'duration_s',.12,'group_capacitance_F',720e-12,'bleed_R_ohm',R, ...
    'stiffness_axis_modal_rad',base.p.stiffness_axis,'physical_axis_beta_deg',axisBeta, ...
    'true_mirror_beta_deg',mirror,'absolute_budget_mrad_s',.25, ...
    'cases',[rows{:}],'native_parity',[parityRows{:}], ...
    'note','Synthetic closed-loop sensitivity; static corners and short windows are not steady-state bias or measured thermal recovery.');
fid=fopen(fullfile(outDir,'drift_quant_verification.json'),'w','n','UTF-8'); assert(fid>=0);
fileCleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',jsonencode(result,'PrettyPrint',true));

    function append(label,mode,rate,split,beta,bits,extra)
        % 相同物理负载和名义配阻，用同一配置入口应用单项或明确组合的覆盖参数。
        option=common; for key=string(fieldnames(extra))', option.(key)=extra.(key); end
        cfg=three_mode_split_config(mode,rate,split,beta,.12,bits,option);
        jobs{end+1}=struct('label',label,'beta',beta,'config',cfg);
    end
end

function score=windowScore(s,window,c)
% 在不重启控制器的同一轨迹上取两个不重叠窗口；角度只为评分重锚。
eligible=s.t_center_s>=window(1) & s.t_center_s<window(2);
use=eligible & s.common_scored;
assert(nnz(use)>=10);
t=s.t_center_s(use); t=t-t(1);
fields={'mechanical_minus_truth_rad','clean_cv_minus_mechanical_rad', ...
    'published_minus_clean_cv_rad','published_minus_truth_rad'};
slopes=zeros(1,4); residual=zeros(1,4); excursions=zeros(1,4);
for k=1:4
    v=s.(fields{k})(use); v=v-v(1); p=polyfit(t,v,1);
    slopes(k)=1000*p(1); residual(k)=1000*sqrt(mean((v-polyval(p,t)).^2));
    excursions(k)=1000*sqrt(mean(v.^2));
end
assert(abs(sum(slopes(1:3))-slopes(4))<1e-7);
score=struct('start_s',window(1),'end_s',window(2),'frames',nnz(use), ...
    'all_frames_usable',nnz(use)==nnz(eligible), ...
    'mechanical_mrad_s',slopes(1),'readout_mrad_s',slopes(2), ...
    'publication_mrad_s',slopes(3),'total_mrad_s',slopes(4), ...
    'detrended_rms_mrad',residual,'anchored_error_rms_mrad',excursions, ...
    'adc_step_V',c.adcStep);
end

function score=parity(model,c,trace,frames,angles,label)
% 独立原生元件执行；同时核对离散事件、转换器码和三路角观测，报告长轨迹码差。
input=Simulink.SimulationInput(model); input=input.setVariable('c',c,'Workspace',model);
input=input.setModelParameter('SaveTime','off'); out=sim(input);
assert(isequal(size(trace),size(out.trace)) && isequal(size(frames),size(out.frames)));
assert(isequal(trace(:,[1:4 9 15 20:22]),out.trace(:,[1:4 9 15 20:22])));
assert(isequal(angles(:,[5:8 10]),out.angleCandidates(:,[5:8 10])));
d=out.angleCandidates(:,2:4)-angles(:,2:4);
err=max(abs(atan2(sin(d),cos(d))),[],'all');
codes=nnz(trace(:,5:8)~=out.trace(:,5:8));
first=find(any(trace(:,5:8)~=out.trace(:,5:8),2),1);
if isempty(first), first=-1; end
score=struct('label',label,'event_flags_equal',true,'converter_mismatches',codes, ...
    'first_code_mismatch_row',first,'angle_gate_rad',1e-7,'angle_gate_pass',err<1e-7, ...
    'max_angle_delta_rad',err,'max_frame_delta',max(abs(frames-out.frames),[],'all'));
% 同一观测与窗口重评分，单列数值分歧是否影响性能结论。
if c.duration>.1
    a=three_angle_series(c,angles,.02); b=three_angle_series(c,out.angleCandidates,.02);
    wa=windowScore(a,[.08 .12],c); wb=windowScore(b,[.08 .12],c);
    score.late_native_minus_matlab_mrad_s=wb.total_mrad_s-wa.total_mrad_s;
else
    score.late_native_minus_matlab_mrad_s=NaN;
end
fprintf('  native: mismatches %d, angle delta %.3g rad\n',codes,err);
end

function closeModels(models)
for k=1:numel(models), if bdIsLoaded(models{k}), close_system(models{k},0); end, end
end
