function result=h68_rate_sweep
here=fileparts(mfilename('fullpath'));addpath(here);
diary(fullfile(here,'rate_sweep.log'));result=struct('cases',[],'underclock_guard',false);
try,h68_config('tdm_shared',0,struct('fs',1088000));catch,result.underclock_guard=true;end
assert(result.underclock_guard);
m='hrg_6800_tdm_shared'; load_system(fullfile(here,'models',[m '.slx']));
cleanup=onCleanup(@() close_system(m,0));
for divisor=[50 25 10 1]
 c=h68_config('tdm_shared',.5,struct('duration',.004,'dac_divisor',divisor,'log_decimation',1));
 [~,r,rf]=h68_reference(c);assignin(get_param(m,'ModelWorkspace'),'c',c);out=sim(m);
 delta=max(abs(r-out.trace),[],'all');assert(delta<1e-4 && isequal(size(rf),size(out.frames)));
 c=h68_config('tdm_shared',.5,struct('duration',.15,'dac_divisor',divisor,'log_decimation',200));
 assignin(get_param(m,'ModelWorkspace'),'c',c);set_param(m,'SaveTime','off');out=sim(m);
 frames=out.frames; frames=frames(frames(:,1)>.05,:);y=frames(:,2:end);t=frames(:,1);
 amp=sqrt(sum(y(:,10:13).^2,2));err=y(:,14)-y(1,14)-c.omega*(t-t(1));
 v=struct('adc_fs_Hz',1/c.Ts,'dac_fs_Hz',1/(c.Ts*divisor),'parity_delta',delta, ...
  'body_rms_rad',sqrt(mean(err.^2)),'minimum_amplitude',min(amp),'maximum_amplitude',max(amp), ...
  'lost',any(out.trace(:,21)),'electrode_peak_V',max(abs(out.trace(:,18:19)),[],'all'));
 assert(~v.lost && min(amp)>.8 && max(amp)<1.2 && v.body_rms_rad<.015);
 result.cases=[result.cases;v];fprintf('RATES adc=%g dac=%g delta=%g RMS=%g\n',v.adc_fs_Hz,v.dac_fs_Hz,delta,v.body_rms_rad);
end
result.status='passed';fid=fopen(fullfile(here,'rate_sweep.json'),'w','n','UTF-8');fprintf(fid,'%s\n',jsonencode(result,'PrettyPrint',true));fclose(fid);
diary off;
end
