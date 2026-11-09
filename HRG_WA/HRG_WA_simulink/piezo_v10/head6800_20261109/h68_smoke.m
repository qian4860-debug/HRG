function h68_smoke
here=fileparts(mfilename('fullpath')); addpath(here);
diary(fullfile(here,'smoke.log'));
h68_build;
for mode={'continuous','tdm_shared','tdm_separate'}
 c=h68_config(mode{1},.5,struct('duration',.005,'log_decimation',1));
 m=['hrg_6800_' mode{1}];load_system(fullfile(here,'models',[m '.slx']));
 assignin(get_param(m,'ModelWorkspace'),'c',c); out=sim(m);
 [~,r,f]=h68_reference(c);
 fprintf('%s trace size %s / %s frames %s / %s delta %g\n',m,mat2str(size(r)),mat2str(size(out.trace)), ...
     mat2str(size(f)),mat2str(size(out.frames)),max(abs(r-out.trace),[],'all'));
 assert(isequal(size(r),size(out.trace)));
 assert(max(abs(r-out.trace),[],'all')<1e-4);
 close_system(m,0);
end
diary off;
end
