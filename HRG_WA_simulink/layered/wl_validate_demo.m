function report=wl_validate_demo()
% Regression: original zero-delay graph vs wire bypass; persistent UI lifetime.
root=fileparts(mfilename('fullpath'));addpath(root);
folder=fullfile(root,'evidence','demo_window_fix');if ~isfolder(folder),mkdir(folder);end
c=wl_config(5);c.duration=.08;
load_system(fullfile(root,'models','hrg_wa_v5.slx'));wl_setup(c);
baseline=sim('hrg_wa_v5','StopTime','.08');close_system('hrg_wa_v5',0);
paths={fullfile(root,'models','hrg_wa_v5_demo.slx'),fullfile(root,'models','hrg_wa_v5_demo.png')};
before=cellfun(@bytes,paths,'UniformOutput',false);
lastwarn('');out=wl_demo(5,.08);[message,~]=lastwarn;
assert(~contains(message,'transport delay','IgnoreCase',true),'Demo still contains zero-delay warning');
c=evalin('base','wl_demo_configuration');fig=evalin('base','hrg_wa_viewer');
checks=struct('name',{},'value',{},'limit',{},'pass',{});
after=cellfun(@bytes,paths,'UniformOutput',false);
check('demo_does_not_save_model_files',double(~isequal(before,after)),0);
check('zero_skew_IQ_equivalence',max(abs(out.tap_iq.Data(:)-baseline.tap_iq.Data(:))),1e-10);
check('zero_skew_navigation_equivalence',max(abs(out.tap_navigation.Data(:)-baseline.tap_navigation.Data(:))),1e-10);
check('zero_skew_uses_wires',double(~strcmp(get_param([c.name '/ADC_Clock_Conversion/Skew_X'],'BlockType'),'Gain') ...
 || ~strcmp(get_param([c.name '/ADC_Clock_Conversion/Skew_Y'],'BlockType'),'Gain')),0);
check('nineteen_replay_tabs',abs(numel(findall(fig,'Type','uitab'))-19),0);
drawnow;pause(2);
check('viewer_alive_after_return',double(~isgraphics(fig)),0);
nav=findall(fig,'Type','uitab','Tag','tap_navigation');axesList=findall(nav,'Type','axes');
for i=1:numel(axesList)
 if strcmp(axesList(i).Title.String,'Rate output (deg/s)')
  exportgraphics(axesList(i),fullfile(folder,'navigation_replay.png'));
 end
end
close_system(c.name,0);drawnow;pause(.2);
check('viewer_survives_model_close',double(~isgraphics(fig)),0);
other=wl_view_results(out,c);
check('replay_reuses_existing_figure',double(other~=fig),0);
check('replay_no_duplicate_tabs',abs(numel(findall(fig,'Type','uitab'))-19),0);
close(fig);
% Crossing zero requires a different graph, but no added memory or zero delay.
c.name='hrg_wa_v5_demo_skew_test';c.duration=.02;c.observers=false;c.spectra=false;
for skew=[0 .5e-6 -.5e-6 0]
 c.channelSkewS=skew;[out,~]=wl_sim(c,false);
 x=get_param([c.name '/ADC_Clock_Conversion/Skew_X'],'BlockType');
 y=get_param([c.name '/ADC_Clock_Conversion/Skew_Y'],'BlockType');
 ok=strcmp(x,choose(skew<0))&&strcmp(y,choose(skew>0));
 check(sprintf('skew_sign_structure_%g',skew),double(~ok),0);
 check(sprintf('skew_sign_finite_%g',skew),double(any(~isfinite(out.tap_navigation.Data(:)))),0);
end
close_system(c.name,0);
report=struct('checks',checks,'pass',all([checks.pass]),'simulationDurationS',.08, ...
 'note','UI handles tested inside a running MATLAB session after simulation return and after model close. Batch MATLAB itself exits at command end.');
wl_write_json(fullfile(folder,'scoreboards.json'),report);
assert(report.pass,'Demo window regression failed');
fprintf('PASS %d demo lifecycle, waveform-equivalence and skew-structure checks.\n',numel(checks));
    function check(name,value,limit)
     ok=isfinite(value)&&value<=limit;checks(end+1)=struct('name',name,'value',value,'limit',limit,'pass',ok);
     fprintf('%s %.9g <= %.9g : %d\n',name,value,limit,ok);
    end
end
function type=choose(delayed)
if delayed,type='TransportDelay';else,type='Gain';end
end
function data=bytes(path)
if ~isfile(path),data=[];return;end
f=fopen(path,'rb');cleanup=onCleanup(@()fclose(f));data=fread(f,inf,'*uint8');
end
