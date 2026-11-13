function result = tdm_zero_split_diagnosis()
% 比较零速模型改变频差和初始驻波角的影响。仅用于分辨确定性模型偏移。
here = fileparts(mfilename('fullpath'));
root = fileparts(here);
addpath(fullfile(root,'tdm_gain_20261113'));
addpath(fullfile(root,'five_adc_range_20261110'));
addpath(fullfile(root,'..','HRG_WA_simulink','piezo_v10','five_electrode_20261110'));
rows = [];
for beta = [0 22.5]
    for split = [0 .025 .05]
        opt = struct('duration',30,'theta0',deg2rad(2*beta),'split_hz',split,'adc_bits',16);
        c = five_adc_study_config(0,2,8,[.5 1],opt);
        [frames,info] = tdm_gain_fast(c);
        assert(~info.tracking_lost && info.published_frames==info.expected_frames);
        % 使用首、末有效帧差和中后段拟合，将启动偏移与长期演化分别记录。
        t = frames(:,1);
        a = frames(:,2);
        tail = t>=15;
        fit = polyfit(t(tail)-t(find(tail,1)),a(tail),1);
        row = struct('split_Hz',split,'initial_beta_deg',beta,'frames',info.published_frames, ...
            'mean_rate_mrad_s',1e3*(a(end)-a(1))/(t(end)-t(1)), ...
            'tail_slope_mrad_s',1e3*fit(1),'net_angle_mrad',1e3*(a(end)-a(1)));
        rows = [rows;row]; %#ok<AGROW>
    end
end
result = struct('scope','Deterministic five-electrode TDM zero-rate model only', ...
    'adc_bits',16,'post_cv_gain',8,'duration_s',30,'cases',rows);
end
