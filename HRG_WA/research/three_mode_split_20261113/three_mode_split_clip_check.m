function result = three_mode_split_clip_check()
% 对主矩阵中连续版 β=0° 的 DAC 限幅核对最后发生时刻。
% 只运行评分起点前后短段，和完整记录限幅计数相等时可定位全部事件。
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here,'..','tdm_gain_20261113'));
long = jsondecode(fileread(fullfile(here,'continuous_main.json')));
clipCases = long.cases([long.cases.dac_clip_ticks]>0);
rows = struct([]);
for entry = clipCases.'
    c = three_mode_split_config(entry.mode,entry.rate_rad_s,entry.split_mHz/1000, ...
        entry.initial_beta_deg,.08);
    [~,info] = tdm_gain_fast(c);
    assert(info.dac_clip_ticks==entry.dac_clip_ticks && info.last_dac_clip_s<entry.score_s(1));
    rows = [rows;struct('split_mHz',entry.split_mHz,'rate_rad_s',entry.rate_rad_s, ...
        'initial_beta_deg',entry.initial_beta_deg,'dac_clip_ticks',info.dac_clip_ticks, ...
        'last_dac_clip_s',info.last_dac_clip_s)]; %#ok<AGROW>
end
result = struct('release',version('-release'),'clip_cases',rows);
end
