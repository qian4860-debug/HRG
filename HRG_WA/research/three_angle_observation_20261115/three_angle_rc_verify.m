function result=three_angle_rc_verify(outDir)
% 第46号：只用独立电气尾波估计配阻，冻结后做闭环角度评分与原生对拍。
% 合成尾波是理想单极点假负载，不冒充已采集数据；未知机械回馈/COM需另测。
arguments
    outDir (1,:) char = fileparts(mfilename('fullpath'))
end
here=fileparts(mfilename('fullpath'));
addpath(here,fullfile(here,'..','three_mode_split_20261113'), ...
    fullfile(here,'..','..','HRG_WA_simulink','piezo_v10','head6800_20261109'));
base=three_mode_split_config('tdm_shared',0,.05,22.5,.012,16);
G=base.p.G0; R0=15000; rng(4617,'twister');
% 所有估计/拒绝门限先于闭环评分冻结。改变极性、偏置不会改变 tau 的定义。
t=(0:50e-9:60e-6)';
cases={ 'nominal',600e-12,2e-6,22.5,0,16; ...
    'cap480',480e-12,2e-6,22.5,0,16; ...
    'cap720',720e-12,2e-6,22.5,0,16; ...
    'driver_fast',600e-12,1.6e-6,22.5,0,16; ...
    'driver_slow',600e-12,2.4e-6,22.5,0,16; ...
    'cap720_mirror',720e-12,2e-6,67.5,0,16; ...
    'cap720_negative',720e-12,2e-6,22.5,-.05,16; ...
    'cap720_adc10',720e-12,2e-6,22.5,0,10};
estimates=cell(size(cases,1),1); configs=cell(size(cases,1),4);
for i=1:size(cases,1)
    [name,C,tau,beta,rate,bits]=deal(cases{i,:});
    % 独立驱动参考量极点，已知 R0 的端口尾波量 C。仅无机械负载假设成立时适用。
    fD=three_angle_tail_fit(t,.1*exp(-t/tau)+.004+50e-6*randn(size(t)),false(size(t)));
    fB=three_angle_tail_fit(t,-.08*exp(-t/(C/(1/R0+G)))-.003+50e-6*randn(size(t)),false(size(t)));
    assert(fD.quality_pass && fB.quality_pass);
    Cest=fB.tau_s*(1/R0+G);
    Rest=1/(Cest/fD.tau_s-G); Rideal=1/(C/tau-G);
    assert(Rest>0 && isfinite(Rest));
    estimates{i}=struct('scenario',name,'drive_fit',fD,'bleed_fit',fB, ...
        'true_C_F',C,'estimated_C_F',Cest,'true_driver_tau_s',tau, ...
        'ideal_R_ohm',Rideal,'estimated_R_ohm',Rest);
    extra=struct('Cs',C,'driver_tau',[tau;tau]);
    configs{i,1}=three_mode_split_config('tdm_separate',rate,.05,beta,.06,bits,extra);
    values=[3333.333333333333,Rideal,Rest];
    for j=2:4
        extra.bleed_R=values(j-1);
        configs{i,j}=three_mode_split_config('tdm_shared',rate,.05,beta,.06,bits,extra);
    end
end
% 对抗样本冻结后再评分，拒绝判据不利用已知 tau 误差。
invalids=tailChecks(t);
labels={'dedicated','fixed_3333','ideal_matched','estimated_matched'};
rows={}; nativeRows={};
models={'hrg_rc_continuous','hrg_rc_separate','hrg_rc_shared'};
modelDir=fullfile(outDir,'rc_models');
defaultConfigs={three_mode_split_config('continuous',0,.05,22.5,.006,16), ...
    configs{3,1},configs{3,4}};
h68_build(modelDir,models,defaultConfigs,false,false,true);
clean=onCleanup(@() closeModels(models)); %#ok<NASGU>
for i=1:numel(models)
    load_system(fullfile(modelDir,[models{i} '.slx']));
    blocks=find_system(models{i},'LookUnderMasks','all','FollowLinks','on','Type','Block');
    types=get_param(blocks,'BlockType');
    assert(~any(ismember(types,{'MATLABFcn','InterpretedMATLABFcn','S-Function','MATLABSystem','FromWorkspace'})));
    assert(isempty(find_system(models{i},'SFBlockType','MATLAB Function')));
end
for i=1:size(cases,1)
    reference=[];
    for j=1:4
        c=configs{i,j}; c.logDecimation=1;
        [~,trace,frames,analog,angles]=five_reference(c,true);
        [series,metrics]=three_angle_series(c,angles,.02);
        assert(metrics.expected_candidates==metrics.observed_candidates);
        if j==1, reference=series; end
        joint=reference.common_scored & series.common_scored;
        assert(nnz(joint)>10);
        d=series.published_body_rel_rad(joint)-reference.published_body_rel_rad(joint);
        time=series.t_center_s(joint); d=d-d(1);
        p=polyfit(time-time(1),d,1);
        full=metrics.common_scored_candidates==metrics.score_candidates && ...
            metrics.accepted_candidates==metrics.expected_candidates;
        noClip=~any(trace(:,20)) && ~any(trace(:,22));
        peak=max(abs(analog(:,5:6)),[],'all');
        alignment=full && noClip && peak<.8 && abs(p(1))<=.05e-3 && sqrt(mean(d.^2))<=.01e-3;
        row=struct('scenario',cases{i,1},'mode',labels{j},'adc_bits',c.p.adc_bits, ...
            'R_ohm',c.p.bleed_R,'total_slope_mrad_s',1000*metrics.total_slope_error_rad_s, ...
            'topology_delta_mrad_s',1000*p(1),'topology_rms_mrad',1000*sqrt(mean(d.^2)), ...
            'peak_adc_V',peak,'full_publication',full,'no_clipping',noClip, ...
            'alignment_screen_pass',alignment, ...
            'absolute_rate_screen_pass',full && noClip && abs(metrics.total_slope_error_rad_s)<=.25e-3, ...
            'angles',metrics);
        rows{end+1}=row; %#ok<AGROW>
        fprintf('%s / %s: R %.3f, topology %.6f, absolute %.6f mrad/s\n', ...
            row.scenario,row.mode,row.R_ohm,row.topology_delta_mrad_s,row.total_slope_mrad_s);
        % 完整 720 pF 四组原生仿真检验；其他角点只作 MATLAB 参数扫描。
        if i==3
            model=models{3}; if j==1, model=models{2}; end
            nativeRows{end+1}=parity(model,c,trace,frames,angles,cases{i,1},labels{j},false); %#ok<AGROW>
        end
    end
end
% 三个传统模式短回归：逐码、事件、三路角度均核对，不改默认模式实现。
legacyModes={'continuous','tdm_separate','tdm_shared'};
for i=1:3
    c=three_mode_split_config(legacyModes{i},0,.05,22.5,.006,16);
    c.logDecimation=1;
    [~,trace,frames,~,angles]=five_reference(c,false);
    nativeRows{end+1}=parity(models{i},c,trace,frames,angles,'legacy_smoke',models{i},true); %#ok<AGROW>
end
% 不同轴极点无法被一个公共电阻同时配对；仅输出拒绝，不暗中平均后放行。
requiredR=[1.6e-6,2.4e-6]/600e-12;
singleRSpread=(max(requiredR)-min(requiredR))/mean(requiredR);
assert(singleRSpread>.05);
result=struct('status','completed','source','synthetic independent single-pole dummy load', ...
    'release',version('-release'),'reference_R_ohm',R0,'assumed_leakage_S',G, ...
    'noise_rms_V',50e-6,'tail_sample_interval_s',50e-9,'seed',4617, ...
    'estimates',[estimates{:}],'tail_tests',invalids,'cases',[rows{:}], ...
    'native_parity',[nativeRows{:}], ...
    'unequal_axis_required_R_ohm',requiredR,'unequal_axis_spread_fraction',singleRSpread, ...
    'unequal_axis_single_R_rejected',true, ...
    'note','Fit gate is not navigation certification; no physical capture or thermal recovery measured.');
fid=fopen(fullfile(outDir,'rc_verification.json'),'w','n','UTF-8'); assert(fid>=0);
cleanupFile=onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',jsonencode(result,'PrettyPrint',true));
end

function tests=tailChecks(t)
% 低幅、缺拍、削顶、过短观测及双极点干扰必须拒绝；正负极性应等价。
v=.1*exp(-t/2e-6)+.003;
p=three_angle_tail_fit(t,v,false(size(t))); n=three_angle_tail_fit(t,-v,false(size(t)));
assert(p.quality_pass && n.quality_pass && abs(p.tau_s/n.tau_s-1)<1e-6);
fits={three_angle_tail_fit(t,zeros(size(t)),false(size(t))), ...
    three_angle_tail_fit(t([1:20 22:end]),v([1:20 22:end]),false(numel(t)-1,1)), ...
    three_angle_tail_fit(t,v,t==t(8)), ...
    three_angle_tail_fit(t(1:40),v(1:40),false(40,1)), ...
    three_angle_tail_fit(t,.05*exp(-t/1e-6)+.05*exp(-t/8e-6),false(size(t)))};
assert(all(cellfun(@(x) ~x.quality_pass,fits)));
tests=struct('positive_negative_equal',true,'labels',{{'zero','missing','clipped','short','two_poles'}}, ...
    'rejected_fits',[fits{:}]);
end

function score=parity(model,c,trace,frames,angles,scenario,label,exact)
% 验收事件逐拍相等；长仿真允许量化阈值附近少量码差，但角度残差要有界。
input=Simulink.SimulationInput(model); input=input.setVariable('c',c,'Workspace',model);
input=input.setModelParameter('SaveTime','off'); out=sim(input);
assert(isequal(size(trace),size(out.trace)) && isequal(size(frames),size(out.frames)));
events=[1:4 9 15 20:22];
assert(isequal(trace(:,events),out.trace(:,events)));
assert(isequal(angles(:,[5:8 10]),out.angleCandidates(:,[5:8 10])));
d=out.angleCandidates(:,2:4)-angles(:,2:4);
err=max(abs(atan2(sin(d),cos(d))),[],'all');
codes=nnz(trace(:,5:8)~=out.trace(:,5:8));
assert(err<1e-7);
if exact, assert(codes==0 && max(abs(trace-out.trace),[],'all')<1e-8); end
score=struct('scenario',scenario,'mode',label,'event_flags_equal',true, ...
    'converter_mismatches',codes,'max_angle_delta_rad',err,'exact_codes_required',exact, ...
    'max_frame_delta',max(abs(frames-out.frames),[],'all'));
end

function closeModels(models)
for i=1:numel(models), if bdIsLoaded(models{i}), close_system(models{i},0); end, end
end
