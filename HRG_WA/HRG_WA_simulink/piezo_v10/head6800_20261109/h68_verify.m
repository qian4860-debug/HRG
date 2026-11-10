function result=h68_verify
% Tests use real converter clock rates, not a silently reduced surrogate.
here=fileparts(mfilename('fullpath')); addpath(here);
diary(fullfile(here,'verification.log'));
modes={'continuous','tdm_shared','tdm_separate'};
result=struct('release',version('-release'),'scope','Behavioral closed-loop simulation; not hardware acceptance', ...
    'parity',[],'nominal',[],'sensitivity',[],'faults',[]);
heads=cell(1,3);
for j=1:3
 mode=modes{j}; m=['hrg_6800_' mode];
 load_system(fullfile(here,'models',[m '.slx']));
 cleanup=onCleanup(@() close_system(m,0));
 blocks=find_system(m,'LookUnderMasks','all','FollowLinks','on','Type','block');
 types=get_param(blocks,'BlockType');
 assert(~any(ismember(types,{'S-Function','MATLABFcn','InterpretedMATLABFcn','MATLABSystem','FromWorkspace'})));
 assert(isempty(find_system(m,'LookUnderMasks','all','SFBlockType','MATLAB Function')));
 c=h68_config(mode,.5,struct('duration',.006,'log_decimation',1)); heads{j}=c.head;
 [~,r,fr]=h68_reference(c); out=runmodel(m,c); y=out.trace;
 assert(isequal(size(r),size(y)) && isequal(size(fr),size(out.frames)));
 flags=[1:4 9 15 20:22]; assert(isequal(r(:,flags),y(:,flags)));
 delta=max(abs(r-y),[],'all'); assert(delta<1e-4);
 if ~c.continuous, assert(~any(y(:,2)&y(:,3))); else, assert(all(y(:,2)&y(:,3))); end
 assert(~any(y(y(:,2)==0,7:8),'all'));
 result.parity=[result.parity;struct('mode',mode,'samples',size(y,1),'native_blocks',numel(blocks), ...
     'maximum_all_signal_delta',delta,'frames',size(fr,1),'pipeline_samples',c.adcLatency)];
 fprintf('PARITY %s samples=%d delta=%g\n',mode,size(y,1),delta);
 for rate=[0 .5 -4]
  c=h68_config(mode,rate,struct('duration',.3,'log_decimation',200));
  out=runmodel(m,c); metric=measure(out,c,.1);
  assert(metric.frames>100 && metric.minimum_amplitude>.8 && metric.maximum_amplitude<1.2);
  assert(metric.body_rms_rad<.015 && ~metric.lost);
  result.nominal=[result.nominal;metric];
  fprintf('NOMINAL %s omega=%g RMS=%g amp=%g..%g\n',mode,rate,metric.body_rms_rad,metric.minimum_amplitude,metric.maximum_amplitude);
 end
 % Range faults: invalid ADC data must never arm the feedback drive.
 c=h68_config(mode,.5,struct('duration',.006,'log_decimation',1)); c.adcMax=2*c.adcStep;c.adcMin=-2*c.adcStep;
 out=runmodel(m,c); y=out.trace;
 assert(any(y(:,20)) && ~any(y(:,[7:9 15]),'all'));
 result.faults=[result.faults;struct('mode',mode,'fault','ADC overload','observed',nnz(y(:,20)),'passed',true)];
 % Deliberately insufficient actuator gain must expose a DAC range limit.
 c=h68_config(mode,.5,struct('duration',.02,'power_gain',.05,'log_decimation',1)); out=runmodel(m,c);
 assert(any(out.trace(:,22)));
 result.faults=[result.faults;struct('mode',mode,'fault','DAC headroom','observed',nnz(out.trace(:,22)),'passed',true)];
 % A later overload must withdraw a previously acquired angle and stop drive.
 c=h68_config(mode,.5,struct('duration',.15,'initial_fraction',.3,'log_decimation',1));
 c.adcMin=-.05;c.adcMax=.05;out=runmodel(m,c);y=out.trace;
 assert(any(y(:,15)) && any(y(:,21)) && ~any(y(y(:,21)>0,[7:8 15]),'all'));
 result.faults=[result.faults;struct('mode',mode,'fault','overload after acquisition','observed',nnz(y(:,21)),'passed',true)];
 clear cleanup
 checkpoint(here,result);
end
assert(isequal(heads{1},heads{2},heads{3}),'Control mode must not alter the head.');
for mode={'continuous','tdm_shared'}
 m=['hrg_6800_' mode{1}];load_system(fullfile(here,'models',[m '.slx']));
 cleanup=onCleanup(@() close_system(m,0));
 cases={struct('f0',6800.5,'Q',20000,'Cs',720e-12), ...
        struct('f0',6799.5,'Q',40000,'Cs',480e-12), ...
        struct('adc_noise_rms',.4*(2/2^10)), ...
        struct('initial_fraction',0,'seed_enabled',true,'duration',.7)};
 labels={'high frequency and capacitance low Q','low frequency and capacitance high Q','injected ADC noise','start from rest'};
 for k=1:numel(cases)
  p=cases{k};if ~isfield(p,'duration'),p.duration=.2;end;p.log_decimation=200;
  c=h68_config(mode{1},.5,p);out=runmodel(m,c);settle=.1;if k==4,settle=.5;end
  metric=measure(out,c,settle);metric.test=labels{k};
  assert(metric.frames>50 && ~metric.lost && metric.minimum_amplitude>.7 && metric.maximum_amplitude<1.3);
  result.sensitivity=[result.sensitivity;metric];
  fprintf('SENSITIVITY %s %s RMS=%g amp=%g..%g\n',mode{1},labels{k},metric.body_rms_rad,metric.minimum_amplitude,metric.maximum_amplitude);
  checkpoint(here,result);
 end
 clear cleanup
end
result.head=heads{1};result.cv_mode=c.p.cv_mode;result.status='passed';
checkpoint(here,result);diary off;
end
function out=runmodel(m,c)
assignin(get_param(m,'ModelWorkspace'),'c',c);
set_param(m,'SaveTime','off'); out=sim(m);
assert(all(isfinite(out.trace),'all'));
end
function v=measure(out,c,settle)
f=out.frames; assert(~isempty(f),'No accepted frames.');
f=f(f(:,1)>=settle,:);assert(~isempty(f));
t=f(:,1); y=f(:,2:end); amp=sqrt(sum(y(:,10:13).^2,2));
err=y(:,14)-y(1,14)-c.omega*(t-t(1));
v=struct('mode',c.mode,'rate_rad_s',c.omega,'fs_Hz',1/c.Ts,'adc_bits',c.p.adc_bits,'dac_bits',c.p.dac_bits, ...
    'duration_s',c.duration,'frames',size(f,1),'body_rms_rad',sqrt(mean(err.^2)), ...
    'body_peak_rad',max(abs(err)),'minimum_amplitude',min(amp),'maximum_amplitude',max(amp), ...
    'dac_peak_V',max(abs(out.trace(:,7:8)),[],'all'),'adc_clip_samples_logged',nnz(out.trace(:,20)), ...
    'dac_clip_samples_logged',nnz(out.trace(:,22)),'lost',any(out.trace(:,21)), ...
    'center_to_publication_s',(c.adcLatency+1+(c.n-1)/2)*c.Ts);
end
function checkpoint(here,result)
fid=fopen(fullfile(here,'verification.json'),'w','n','UTF-8'); assert(fid>=0);
fprintf(fid,'%s\n',jsonencode(result,'PrettyPrint',true)); fclose(fid);
end
