function [f,P,info]=wl_native_psd(t,x)
% One-sided mean-removed Hann PSD. A trend is signal, not isolated noise.
t=t(:);assert(size(x,1)==numel(t)&&numel(t)>=8,'At least eight aligned samples required');
dt=diff(t);Ts=median(dt);
assert(Ts>0&&all(isfinite(dt))&&max(abs(dt-Ts))<=Ts*1e-5,'Uniform native-rate samples required');
fs=1/Ts;N=min(8192,2^floor(log2(numel(t))));
w=.5-.5*cos(2*pi*(0:N-1)'/N);segment=x(end-N+1:end,:);segment=segment-mean(segment,1);
X=fft(segment.*w);P=abs(X(1:N/2+1,:)).^2/(fs*sum(w.^2));P(2:end-1,:)=2*P(2:end-1,:);
f=(0:N/2)'*fs/N;
info=struct('sampleRateHz',fs,'samples',N,'binSpacingHz',fs/N,'windowDurationS',N/fs, ...
 'meanRemoved',true,'trendRemoved',false,'noiseIsolated',false,'method','one-sided periodic Hann');
end
