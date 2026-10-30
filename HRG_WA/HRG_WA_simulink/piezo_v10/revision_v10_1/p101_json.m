function p101_json(path,value)
fid=fopen(path,'w','n','UTF-8');assert(fid>=0);cleanup=onCleanup(@()fclose(fid));
fwrite(fid,[jsonencode(value,PrettyPrint=true) newline],'char');
end
