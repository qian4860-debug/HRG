function c=w9_setup(c)
r=fileparts(mfilename('fullpath'));
addpath(r,fullfile(fileparts(r),'literature_zotero_research'),fullfile(fileparts(r),'literature_v8_research'), ...
 fullfile(fileparts(r),'literature_v7'),fullfile(fileparts(r),'layered'));
if nargin>0,c=wz_setup(c);else,c=jsondecode(fileread(fullfile(r,'profile.json')));end
end
