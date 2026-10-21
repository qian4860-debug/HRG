function fig=wl_view_results(out,c)
% Persistent, ordinary MATLAB figure: replay does not depend on Scope buffers.
if nargin<2,c=wl_config(5);end
tag=['HRG_WA_Replay_' c.name];fig=findall(groot,'Type','figure','Tag',tag);
if isempty(fig)
 fig=figure('Name',sprintf('HRG WA V%d - logged signal replay',c.stage), ...
  'NumberTitle','off','Tag',tag,'Position',[80 80 1200 760],'Visible','on');
else
 fig=fig(1);clf(fig);set(fig,'Visible','on');
end
group=uitabgroup(fig);
% Start with the navigation result, then follow the physical signal chain.
order={'navigation','head_displacement','head_velocity','cv_ideal','cv_actual', ...
 'pga','anti_alias','sample_hold','adc','mixer','cic','fir','iq', ...
 'control_commands','dac_requested','dac','driver','force','algorithm_diagnostics'};
names=cellfun(@(n)['tap_' n],order,'UniformOutput',false);
names=names(ismember(names,who(out)));
for k=1:numel(names)
 label=erase(names{k},'tap_');tab=uitab(group,'Title',label,'Tag',names{k});
 ts=out.(names{k});t=ts.Time;x=ts.Data;
 if size(x,1)~=numel(t),x=x.';end
 switch label
  case 'navigation'
   panel(tab,t,x(:,1)*180/pi,1,3,'Angle output (deg)');
   panel(tab,t,x(:,2)*180/pi,2,3,'Rate output (deg/s)');
   panel(tab,t,x(:,3),3,3,'Measurement valid');
  case 'control_commands'
   labels={'Energy command (1/s)','Quadrature command (1/s)','NCO correction (Hz)'};
   for j=1:3,panel(tab,t,x(:,j),j,3,labels{j});end
  case 'algorithm_diagnostics'
   a=panel(tab,t,x(:,[3 5 6]),1,3,'Algorithm update counts');legend(a,{'Kalman','Online','FRP'},'Location','best');
   a=panel(tab,t,x(:,[7 8 9 12]),2,3,'Coverage, confidence and application weights');legend(a,{'Coverage','Confidence','FRP alpha','Online alpha'},'Location','best');
   a=panel(tab,t,x(:,1:2)*180/pi,3,3,'Raw rate / correction (deg/s)');legend(a,{'Raw rate','Correction'},'Location','best');
  otherwise
   fs=1/median(diff(t));sel=true(size(t));
   if fs>4*c.head.f0,sel=t>=t(end)-6/c.head.f0;end
   a=panel(tab,t(sel),x(sel,:),1,2,[label ' - native samples'],'none');
   if ismember(label,{'adc','dac','sample_hold'})
    delete(a.Children);set(a,'NextPlot','add');stairs(a,t(sel),x(sel,:));set(a,'NextPlot','replace');
   end
   ylabel(a,units(label));
   count=size(x,2);legend(a,arrayfun(@(n)sprintf('Ch%d',n),1:count,'UniformOutput',false),'Location','best');
   a=subplot(2,1,2,'Parent',tab);
   N=min(8192,2^floor(log2(numel(t))));
   if N>=8
    w=.5-.5*cos(2*pi*(0:N-1)'/N);segment=x(end-N+1:end,:);segment=segment-mean(segment,1);
    X=fft(segment.*w);P=abs(X(1:N/2+1,:)).^2/(fs*sum(w.^2));P(2:end-1,:)=2*P(2:end-1,:);
    f=(0:N/2)'*fs/N;plot(a,f,10*log10(max(P,1e-30)));grid(a,'on');
    xlim(a,[0 min(fs/2,2*c.head.f0)]);xlabel(a,'Hz');ylabel(a,'PSD (dB unit^2/Hz)');
    title(a,sprintf('One-sided Hann PSD, last %d native samples, Fs = %.9g Hz',N,fs));
   end
 end
end
setappdata(fig,'Configuration',c);setappdata(fig,'SignalCount',numel(names));drawnow;
end
function a=panel(parent,t,x,index,total,label,interpreter)
if nargin<7,interpreter='none';end
a=subplot(total,1,index,'Parent',parent);plot(a,t,x);grid(a,'on');xlabel(a,'s');title(a,label,'Interpreter',interpreter);
end
function u=units(label)
if ismember(label,{'head_displacement','mixer','cic','fir','iq'}),u='Normalized';
elseif strcmp(label,'head_velocity'),u='Normalized / s';
elseif strcmp(label,'force'),u='Normalized / s^2';else,u='V';end
end
