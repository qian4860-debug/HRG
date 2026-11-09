function h68_export_parameters
here=fileparts(mfilename('fullpath'));data=[];
for mode={'continuous','tdm_shared','tdm_separate'}
 c=h68_config(mode{1});
 record=struct('mode',c.mode,'head',c.head,'parameters',c.p,'gain_check',c.gain_check, ...
  'thx_comparison',c.thx_comparison,'timing_samples',struct('drive_end',c.driveEnd, ...
  'sense_start',c.senseStart,'valid_start',c.validStart,'valid_end',c.validEnd,'frame',c.frame));
 data=[data;record];
end
fid=fopen(fullfile(here,'parameter_summary.json'),'w','n','UTF-8');fprintf(fid,'%s\n',jsonencode(data,'PrettyPrint',true));fclose(fid);
end
