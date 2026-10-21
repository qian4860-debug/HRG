function wl_write_json(path,value)
folder=fileparts(path);if ~isfolder(folder),mkdir(folder);end
f=fopen(path,'wb');assert(f>0);cleanup=onCleanup(@()fclose(f));
fwrite(f,unicode2native(jsonencode(value,PrettyPrint=true),'UTF-8'),'uint8');
end
