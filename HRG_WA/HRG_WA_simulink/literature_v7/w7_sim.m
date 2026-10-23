function [out,c]=w7_sim(c,saveArtifacts)
if nargin<1,c=w7_config();end
if nargin<2,saveArtifacts=false;end
c.maxLogPoints=ceil(c.duration*c.fsPlant)+1;
name=w7_build(c,saveArtifacts);c=w7_setup(c);
out=sim(name,'StopTime',num2str(c.duration,17));
end
