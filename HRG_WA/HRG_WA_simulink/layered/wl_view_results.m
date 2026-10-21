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
   rows=2+strcmp(label,'iq');
   a=panel(tab,t(sel),x(sel,:),1,rows,[label ' - native samples'],'none');
   if ismember(label,{'adc','dac','sample_hold'})
    delete(a.Children);set(a,'NextPlot','add');stairs(a,t(sel),x(sel,:));set(a,'NextPlot','replace');
   end
   ylabel(a,units(label));
   count=size(x,2);channelNames=arrayfun(@(n)sprintf('Ch%d',n),1:count,'UniformOutput',false);
   if ismember(label,{'mixer','cic','fir','iq'}),channelNames={'Cx','Cy','Sx','Sy'};end
   legend(a,channelNames,'Location','best');
   if strcmp(label,'iq')
    E=sum(x.^2,2);Q=2*(x(:,1).*x(:,4)-x(:,2).*x(:,3));ratio=Q./max(E,eps);ratio(E<c.head.energyThreshold)=NaN;
    a=panel(tab,t,[E ratio],2,rows,sprintf('Loop quality: E target %.5g, Q/E target 0',c.head.energyTarget));legend(a,{'E','Q/E'},'Location','best');
   end
   a=subplot(rows,1,rows,'Parent',tab);
   if numel(t)>=8
    [f,P,info]=wl_native_psd(t,x);plot(a,f,10*log10(max(P,1e-30)));grid(a,'on');
    xlim(a,[0 min(fs/2,2*c.head.f0)]);xlabel(a,'Hz');ylabel(a,['PSD [dB(' units(label) '^2/Hz)]'],'Interpreter','none');
    title(a,sprintf('Hann PSD: mean removed, trend retained; df=%.4g Hz, window=%.4g s',info.binSpacingHz,info.windowDurationS));
    if strcmp(label,'iq')
     title(a,sprintf('Slow IQ signal, NOT isolated noise; df=%.4g Hz; rotation about %.4g Hz',info.binSpacingHz,abs(c.head.bryan*c.inputRate)/pi));
    end
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
