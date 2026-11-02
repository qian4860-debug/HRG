function pcn_json(path,value)
% 证据写出：UTF-8编码并统一换行，用于复现实验与文件哈希核查。
fid=fopen(path,'w','n','UTF-8');assert(fid>=0);cleanup=onCleanup(@()fclose(fid));
fwrite(fid,[jsonencode(value,PrettyPrint=true) newline],'char');
end
