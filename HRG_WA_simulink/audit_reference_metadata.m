function audit_reference_metadata()
% Inspect stored array metadata only; never execute the reference scripts/models.
root=fileparts(mfilename('fullpath'));
inventory=jsondecode(fileread(fullfile(root,'_work','reference_audit_full.json')));
items=struct('path',{},'variables',{},'error',{});
for k=1:numel(inventory.files)
    if iscell(inventory.files),item=inventory.files{k};else,item=inventory.files(k);end
    if endsWith(item.path,'.mat')
        try
            variables=whos('-file',fullfile(inventory.source_root,item.path));
            variables=rmfield(variables,intersect(fieldnames(variables),{'global','sparse','complex','nesting','persistent'}));
            items(end+1)=struct('path',item.path,'variables',variables,'error','');
        catch err
            items(end+1)=struct('path',item.path,'variables',[],'error',err.message);
        end
    end
end
dest=fullfile(root,'evidence','reference_mat_metadata.json');
if ~isfolder(fileparts(dest)),mkdir(fileparts(dest));end
fid=fopen(dest,'w');fwrite(fid,jsonencode(items,PrettyPrint=true),'char');fclose(fid);
fprintf('Inspected metadata of %d reference MAT files without loading objects.\n',numel(items));
end
