function wl_save_evidence(out,c,label)
root=fileparts(mfilename('fullpath'));folder=fullfile(root,'evidence',label);
if ~isfolder(folder),mkdir(folder);end
m=wl_metrics(out,c);wl_write_json(fullfile(folder,'metrics.json'),m);
cfg=c;if isfield(cfg,'legacyP'),cfg=rmfield(cfg,'legacyP');end
wl_write_json(fullfile(folder,'configuration.json'),cfg);
names=who(out);nodes={};
for k=1:numel(names)
 n=names{k};if ~startsWith(n,'tap_'),continue;end
 data=out.(n);t=data.Time;x=data.Data;
 if ndims(x)>2,x=squeeze(x);end
 if size(x,1)~=numel(t),x=x.';end
 if numel(t)<4,continue;end
 ts=median(diff(t));fs=1/ts;
 x=x(:,1);tail=t>=max(t(1),t(end)-min(.2,c.duration/2));xx=x(tail);tt=t(tail);
 N=min(1024,2^floor(log2(numel(xx))));
 if N<8,continue;end
 window=.5-.5*cos(2*pi*(0:N-1)'/N);segment=xx(end-N+1:end);segment=segment-mean(segment);
 X=fft(segment.*window);P=abs(X(1:N/2+1)).^2/(fs*sum(window.^2));P(2:end-1)=2*P(2:end-1);
 freq=(0:N/2)'*fs/N;
 writematrix([freq P],fullfile(folder,[n '_psd.csv']));
 % Preserve native-rate samples over a useful carrier window. Arbitrary
 % thinning would alias the carrier and misrepresent waveform quality.
 if fs>4*c.head.f0,selWave=t>=t(end)-8/c.head.f0;else,selWave=true(size(t));end
 writematrix([t(selWave) data.Data(selWave,:)],fullfile(folder,[n '_wave.csv']));
 nodes{end+1}=struct('name',n,'sampleRateHz',fs,'psdUnit','signal-unit squared / Hz', ...
  'psdSource','last single-channel Hann window, one-sided; mean removed','channelsLogged',size(data.Data,2), ...
  'waveformStartS',t(find(selWave,1)),'waveformEndS',t(end),'waveformDecimation',1); %#ok<AGROW>
end
wl_write_json(fullfile(folder,'observation_nodes.json'),nodes);
fig=figure('Visible','off','Position',[20 20 1100 780]);
zoom=[max(0,c.duration-4/c.head.f0) c.duration];
subplot(3,2,1);plot(out.tap_head_displacement.Time,out.tap_head_displacement.Data);xlim(zoom);title('Mechanical modes, last 4 cycles');xlabel('s');grid on;
subplot(3,2,2);plot(out.tap_cv_actual.Time,out.tap_cv_actual.Data);xlim(zoom);title('C/V output (V), last 4 cycles');xlabel('s');grid on;
subplot(3,2,3);plot(out.tap_adc.Time,out.tap_adc.Data,'.-');xlim(zoom);title('ADC stream (V), native samples');xlabel('s');grid on;
subplot(3,2,4);plot(out.tap_iq.Time,out.tap_iq.Data);title('Filtered control I/Q');xlabel('s');grid on;
subplot(3,2,5);plot(out.tap_navigation.Time,out.tap_navigation.Data(:,2)*180/pi);title('Navigation rate (deg/s)');xlabel('s');grid on;
subplot(3,2,6);plot(out.tap_driver.Time,out.tap_driver.Data);xlim(zoom);title('Actual driver (V), last 4 cycles');xlabel('s');grid on;
exportgraphics(fig,fullfile(folder,'signal_flow.png'));close(fig);
end
