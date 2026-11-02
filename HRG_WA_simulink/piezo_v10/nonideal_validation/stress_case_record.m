function record=stress_case_record(v)
% JSON不支持复数；显式记录实部/虚部，避免丢失标定相位。
record=v;fields=fieldnames(v.c);record.c=struct;
for k=1:numel(fields)
 n=fields{k};value=v.c.(n);
 if isreal(value),record.c.(n)=value;else,record.c.([n '_real'])=real(value);record.c.([n '_imag'])=imag(value);end
end
end
