function s = split_ringdown_fixture(f,name,seed,fs,duration_s,burst_s,options)
% 双模态生成器以 6800 Hz、Q≈30000 为中心，允许两个衰减时常不同。
% 两路复基带共享公共 LO 漂移，每次激励具有独立相位与幅度。
% 可选工况仅进入发生器；估计与门控接口不接收 options 或频差真值。
if nargin < 7, options = struct(); end
r = RandStream('mt19937ar','Seed',seed);
t = (0:1/fs:duration_s-1/fs)';
truth = repmat(f,size(t));
if name == "split_step"
    truth(t>=10.25) = 25;
end
if isfield(options,'event_s')
    truth(:) = f;
    truth(t>=options.event_s) = options.after_mHz;
end
snr_db = 46;
if name == "low_snr"
    snr_db = 22;
end
strength = 0.8;
if name == "weak_mode"
    strength = 0.015;
end
mix_deg = 0;
if name == "axis_error"
    mix_deg = 12;               % 留出盲点，估计器始终假设模态轴校准正确
end
if isfield(options,'rotation_deg'), mix_deg = options.rotation_deg; end
trigger = mod((0:numel(t)-1)',round(burst_s*fs)) == 0;
if name == "single_burst"
    trigger(2:end) = false;
end
starts = [find(trigger);numel(t)+1];
q = 30000*(0.93+0.14*rand(r,1,2));
tau = q/(pi*6800);
common_phase = 2*pi*(0.10*t + 0.03*sin(1.1*t));
signal = complex(zeros(numel(t),2));
for k = 1:numel(starts)-1
    ix = starts(k):starts(k+1)-1;
    age = t(ix)-t(ix(1));
    % 模态相位差积分产生真实频差。输入阶跃时保持相位连续。
    half_phase = pi/fs*[0;cumsum(truth(ix(1:end-1))*1e-3)];
    phase0 = 2*pi*rand(r,1,2);
    amplitude = (0.85+0.3*rand(r,1,2)).*[1,strength];
    signal(ix,:) = amplitude.*exp(-age./tau).* ...
        exp(1i*(common_phase(ix)+[-half_phase,half_phase]+phase0));
end
rotation = [cosd(mix_deg),-sind(mix_deg);sind(mix_deg),cosd(mix_deg)];
noise_scale = 10^(-snr_db/20)/sqrt(2);  % 参考单位模态初始幅度，为每一实部的标准差
iq = signal*rotation + noise_scale*(randn(r,size(signal))+1i*randn(r,size(signal)));
s = struct('time_s',t,'iq',iq,'trigger',trigger,'truth',truth,'snr_db',snr_db);
end
