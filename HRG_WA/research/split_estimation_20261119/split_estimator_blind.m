function result = split_estimator_blind(output_dir)
% 第一轮独立测频支路代理盲测。运行 split_estimator_blind() 在本目录输出 JSON。
% 此处产生同步双轴 I/Q 自由衰减记录；主闭环受测频激励的干扰须另行验证。
if nargin == 0
    output_dir = fileparts(mfilename('fullpath'));
end
fs = 200;                      % 解调后复基带采样率，非 ADC 载波采样率
duration_s = 20;
burst_s = 4;
tick_s = 0.5;
conditions = ["nominal","low_snr","weak_mode","axis_error","single_burst","split_step"];
all_rows = {};
for c = 1:numel(conditions)
    name = conditions(c);
    frequencies = [0,25,50];
    repeats = 4;
    if name ~= "nominal"
        frequencies = 50;
    end
    for fi = 1:numel(frequencies)
        f = frequencies(fi);
        for rep = 1:repeats
            % 每个工况/频差/整次运行有独立的种子，似然和门限在这些运行之外规定。
            id = sprintf('%s_f%03d_r%02d',char(name),f,rep);
            seed = 246810+10000*c+100*f+rep;
            input = split_ringdown_fixture(f,name,seed,fs,duration_s,burst_s);
            for tick = 1:round(duration_s/tick_s)
                last = round(tick*tick_s*fs);
                % 已知脉冲起点来自采集触发。每次读取最多一个已开始的衰减段。
                first = find(input.trigger(1:last),1,'last');
                t_end = last/fs;
                reading = estimate_ringdown_split(input.time_s(first:last),input.iq(first:last,:));
                % 旧衰减段后半段可能只有噪声。有效时间以实际参与回归的末样本
                % 为锚，硬门控防止旧高 SNR 前缀反复冒充新读数。
                support_end = input.time_s(first);
                if reading.samples_used > 0
                    support_end = input.time_s(first+reading.samples_used-1)+1/fs;
                end
                expiry = support_end+tick_s;
                if t_end >= expiry
                    reading.valid = false;
                    reading.reason = "stale_support";
                end
                % 先完成数据处理，再由离线评分器附上当前频差真值和工况标签。
                row = struct('run_id',id,'case_name',name,'split_true_mHz',input.truth(last), ...
                    't_s',t_end,'split_est_mHz',reading.split_est_mHz, ...
                    'uncertainty_mHz',reading.uncertainty_mHz,'valid',reading.valid, ...
                    'valid_until_s',expiry,'observed_from_s',input.time_s(first), ...
                    'support_end_s',support_end,'reason',reading.reason,'snr_db',input.snr_db);
                all_rows{end+1,1} = row; %#ok<AGROW>
            end
        end
    end
end
rows = vertcat(all_rows{:});
result = struct('scope',"synthetic auxiliary ringdown I/Q; calibrated modal channels; no hardware", ...
    'fs_baseband_Hz',fs,'observation_tick_s',tick_s,'max_age_from_support_s',tick_s, ...
    'budget_mHz',0.71,'rows',rows,'summary',summarize(rows,conditions));
file = fullfile(output_dir,'estimates.json');
fid = fopen(file,'w','n','UTF-8');
assert(fid >= 0, '无法创建测频回执');
closer = onCleanup(@() fclose(fid));
fprintf(fid,'%s\n',jsonencode(result));    % 不可估计字段序列化为 null
end

function summary = summarize(rows,conditions)
% 分别给出精度标志的覆盖、误放和实测区间覆盖。补偿入口还须核验范围和时间戳。
parts = {};
for name = conditions
    sel = rows(string({rows.case_name}) == name);
    published = [sel.valid];
    abs_err = abs([sel.split_est_mHz]-[sel.split_true_mHz]);
    halfwidth = [sel.uncertainty_mHz];
    accepted = abs_err(published);
    if isempty(accepted)
        worst = NaN;
    else
        worst = max(accepted);
    end
    parts{end+1,1} = struct('case_name',name,'ticks',numel(sel), ...
        'run_count',numel(unique(string({sel.run_id}))),'valid_ticks',nnz(published), ...
        'valid_over_budget',nnz(published & abs_err > 0.71), ...
        'valid_outside_interval',nnz(published & abs_err > halfwidth), ...
        'valid_over_50mHz',nnz(published & [sel.split_est_mHz]>50), ...
        'max_valid_error_mHz',worst); %#ok<AGROW>
end
summary = vertcat(parts{:});
end
