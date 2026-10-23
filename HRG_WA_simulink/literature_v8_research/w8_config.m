function c=w8_config()
% Additive experiments on the immutable V7 implementation, not a signed-off V8.
r=fileparts(mfilename('fullpath'));addpath(r,fullfile(fileparts(r),'literature_v7'));
c=w7_config();c.name='hrg_wa_v8_research';
c.v8=jsondecode(fileread(fullfile(r,'profile.json')));
N=c.fsAdc*c.head.Ts;
support=c.cicStages*(N-1)/c.fsAdc+(numel(c.fir)-1)*c.head.Ts+ ...
 (c.pipelineCtrl+1)*c.head.Ts+c.adcDelay/c.fsAdc;
c.v8.filterWarmupS=(ceil(support/c.head.Ts)+c.v8.extraWarmupControlFrames)*c.head.Ts;
end
