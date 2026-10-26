function w9_write_bias_evidence(t,q,velocity,label,e)
% Keep deterministic state probes and ALL raw frequency-event brackets in Git;
% archive the full generated trajectory locally for inspection/regeneration.
assert(~isempty(regexp(label,'^bias_[a-z_]+_V[0-9]+_[01]$','once')));
index=unique(round(linspace(1,numel(t),2049)));
writematrix([t(index) q(index,:) velocity(index,:)],fullfile(e,[label '_probes.csv']));
events=[];
for j=1:2
 ind=find(q(1:end-1,j)>0&q(2:end,j)<=0);
 events=[events;[j*ones(numel(ind),1),(0:numel(ind)-1)',t(ind),t(ind+1),q(ind,j),q(ind+1,j)]]; %#ok<AGROW>
end
writematrix(events,fullfile(e,[label '_crossings.csv']));
r=fileparts(mfilename('fullpath'));archive=fullfile(fileparts(r),'layered','_work','v9_raw');
if ~isfolder(archive),mkdir(archive);end
save(fullfile(archive,[label '.mat']),'t','q','velocity');
end
