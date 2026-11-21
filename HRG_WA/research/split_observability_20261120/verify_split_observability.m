function verify_split_observability(project,folder)
% 同一批主通道 I/Q 对拍后，增加独立种子、相反方向阶跃和轴检定故障的整次留出。
% 目录内生成 estimates_guarded.json（兼容闭环回放）和 observability_scoreboard.json。
if nargin<2, folder=fileparts(mfilename('fullpath')); end
if nargin<1, project=fileparts(fileparts(folder)); end
legacy=fullfile(project,'research','split_estimation_20261119'); addpath(legacy);
old=jsondecode(fileread(fullfile(legacy,'estimates.json')));
names=["nominal","low_snr","weak_mode","axis_error","single_burst","split_step"];
setA={}; setB={};
for c=1:numel(names)
    name=names(c); fsplits=50; if name=="nominal", fsplits=[0 25 50]; end
    for f=fsplits
        for rep=1:4
            seed=246810+10000*c+100*f+rep;
            id=sprintf('%s_f%03d_r%02d',name,f,rep);
            angle=0; if name=="axis_error", angle=12; end
            event=Inf; after=f; if name=="split_step", event=10.25; after=25; end
            cfg=scenario(name,f,after,event,angle,"honest",rep,id,seed);
            setA{end+1}=trial(cfg); %#ok<AGROW>
        end
    end
end
matched=vertcat(setA{:});
assert(numel(matched)==numel(old.rows) && isequal({matched.run_id},{old.rows.run_id}));
assert(isequal([matched.t_s],[old.rows.t_s]) && isequal([matched.baseline_valid],[old.rows.valid]));
for key=["split_est_mHz","uncertainty_mHz"]
    a=[matched.(key)]; b=nan(size(a));
    for k=1:numel(b)
        value=old.rows(k).(key); if ~isempty(value), b(k)=value; end
    end
    delta=max(abs(a-b),[],'omitnan');
    assert(isequal(isnan(a),isnan(b)) && delta<1e-10,'%s baseline differs, max delta %.12g',key,delta);
end
% 冻结全部阈值，再用互异整次种子测试。正常25 mHz与未见的偏转、上/下阶跃、
% 旧见证以及随传感轴一起转动的见证列入同一记分板。驱动源误对准是显式反例。
holdnames=["stationary","axis_minus5","axis_plus18","step_up","step_down", ...
    "small_step","stale_probe","co_rotating_probe"];
f0=[25 50 50 18 42 32 25 50]; f1=[25 50 50 42 18 29 25 50];
event=[Inf Inf Inf 7.13 13.41 9.07 Inf Inf];
angle=[0 -5 18 0 0 0 0 12];
for c=1:numel(holdnames)
    fault="honest"; if c==7, fault="stale"; elseif c==8, fault="co_rotating"; end
    for rep=1:4
        id=sprintf('held_%s_r%02d',holdnames(c),rep);
        cfg=scenario(holdnames(c),f0(c),f1(c),event(c),angle(c),fault,rep,id,910000+100*c+rep);
        setB{end+1}=trial(cfg); %#ok<AGROW>
    end
end
held=vertcat(setB{:});
assert(isempty(intersect(string({held.run_id}),string({matched.run_id}))));
r=old; r.scope="paired causal I/Q change test plus independent single-mode probe proxy";
r.rows=matched; r.summary=summary(matched);
save_json(fullfile(folder,'estimates_guarded.json'),r);
stats=struct('scope',"synthetic auxiliary readout and independent probe; thresholds fixed before held runs", ...
    'change_z_limit',4.5,'axis_limit_deg',0.30,'axis_expiry_s',4.25,'matched',summary(matched), ...
    'held',summary(held),'held_rows',held,'matched_step_alarm',alarms(matched), ...
    'held_step_alarm',alarms(held));
save_json(fullfile(folder,'observability_scoreboard.json'),stats);
fprintf('Verified %d original estimates and %d held estimates.\n',numel(matched),numel(held));
end

function cfg=scenario(name,start,after,event,angle,fault,rep,id,seed)
cfg=struct('name',name,'start',start,'after',after,'event',event,'angle',angle, ...
    'fault',fault,'rep',rep,'id',id,'seed',seed);
end

function rows=trial(c)
% 发生器产生频差和轴方向，两者仅用于驱动模型。门控不接收工况名或真实角度。
fs=200; tick=0.5; burst=4;
opts=struct('event_s',c.event,'after_mHz',c.after,'rotation_deg',c.angle);
s=split_ringdown_fixture(c.start,c.name,c.seed,fs,20,burst,opts);
probes=make_probes(c.angle,c.fault,c.seed+7000000);
rows=cell(40,1); prev=0; latched=false;
for k=1:40
    last=k*100; first=find(s.trigger(1:last),1,'last'); t=last/fs;
    if first~=prev, latched=false; prev=first; end
    [reading,fit]=estimate_ringdown_split(s.time_s(first:last),s.iq(first:last,:));
    stop=s.time_s(first);
    if reading.samples_used>0, stop=s.time_s(first+reading.samples_used-1)+1/fs; end
    expiry=stop+tick;
    if t>=expiry, reading.valid=false; reading.reason="stale_support"; end
    % 探头观测在相应激励段开始时才可见。末样本恰在下次激励前，当下仍使用本段见证。
    probe=probes(1+floor((last-1)/(burst*fs)));
    g=split_observation_guard(reading,fit,probe,t,latched); latched=g.latched;
    rows{k}=struct('run_id',c.id,'case_name',c.name,'split_true_mHz',s.truth(last), ...
        't_s',t,'split_est_mHz',reading.split_est_mHz,'uncertainty_mHz',reading.uncertainty_mHz, ...
        'valid',g.valid,'valid_until_s',min(expiry,probe.at_s+4.25),'observed_from_s',s.time_s(first), ...
        'support_end_s',stop,'reason',g.reason,'snr_db',s.snr_db,'baseline_valid',reading.valid, ...
        'iq_only_valid',g.iq_valid,'hinge_z',g.hinge_z,'phase_latched',g.latched, ...
        'axis_ok',g.axis_ok,'axis_bound_deg',g.axis_bound_deg,'event_s',c.event);
end
rows=vertcat(rows{:});
end

function p=make_probes(axis_deg,fault,seed)
% 独立观测模型：以已获独立模态标定的执行器选择本征模 X、Y，各取得32次复基带读数。
% 输出幅相与主测频随机序列独立。若执行器跟随误轴旋转，两条参考路径可一起失明。
r=RandStream('mt19937ar','Seed',seed);
theta=axis_deg; if fault=="co_rotating", theta=0; end
rot=[cosd(theta) -sind(theta);sind(theta) cosd(theta)];
p=repmat(struct('at_s',0,'iq',[]),1,5);
for i=1:5
    if i>1 && fault=="stale", p(i)=p(1); continue, end
    z=complex(zeros(32,2,2));
    for j=1:2
        a=(0.85+0.3*rand(r,32,1)).*exp(2i*pi*rand(r,32,1));
        z(:,:,j)=a*rot(j,:)+0.004*(randn(r,32,2)+1i*randn(r,32,2));
    end
    p(i)=struct('at_s',(i-1)*4,'iq',z);
end
end

function stats=summary(rows)
names=unique(string({rows.case_name}),'stable'); flags={'baseline_valid','iq_only_valid','valid'};
parts={};
for name=names
    s=rows(string({rows.case_name})==name); err=abs([s.split_true_mHz]-[s.split_est_mHz]);
    for j=1:3
        pub=logical([s.(flags{j})]); inrange=pub & abs([s.split_est_mHz])<=50;
        peak=NaN; if any(pub), peak=max(err(pub)); end
        parts{end+1}=struct('case_name',name,'method',flags{j},'runs',numel(unique({s.run_id})), ...
            'ticks',numel(s),'published',sum(pub),'over_0p71mHz',sum(pub & err>0.71), ...
            'worst_published_mHz',peak,'within_range_published',sum(inrange), ...
            'within_range_over_0p71mHz',sum(inrange & err>0.71)); %#ok<AGROW>
    end
end
stats=vertcat(parts{:});
end

function result=alarms(rows)
% 报告事件发生后新触发的相位告警；先前误触发的锁存不能算成发现这次阶跃。
ids=unique(string({rows.run_id}),'stable'); parts={};
for id=ids
    s=rows(string({rows.run_id})==id);
    event=s(1).event_s; if ~isfinite(event), continue,end
    t=[s.t_s]; alarm=[s.hinge_z]>4.5; old=[false [s(1:end-1).phase_latched]];
    same=[false diff([s.observed_from_s])==0];
    new=alarm & ~(old & same);
    hit=find(t>event & new,1); lag=NaN; if ~isempty(hit),lag=t(hit)-event;end
    parts{end+1}=struct('run_id',id,'event_s',event,'first_alarm_delay_s',lag, ...
        'pre_event_alarms',sum(t<=event & new)); %#ok<AGROW>
end
result=vertcat(parts{:});
end

function save_json(file,data)
fid=fopen(file,'w','n','UTF-8'); assert(fid>=0); c=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',jsonencode(data));
end
