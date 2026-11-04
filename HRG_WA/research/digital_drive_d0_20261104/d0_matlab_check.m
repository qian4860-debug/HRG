function result=d0_matlab_check()
% 独立MATLAB矩阵/复数参考：不调用Python或RTL算术实现。
% 输入是已量化的公开接口值，期望值只参与离线scoreboard。
root=fileparts(mfilename('fullpath'));d=jsondecode(fileread(fullfile(root,'data','matlab_vectors.json')));
x=d.inputs;expected=d.expected;state=zeros(1,size(x,2));have=false;out=zeros(1,9);actual=zeros(size(expected));
for k=1:size(x,1)
 a=x(k,:);
 if a(1)
  state(:)=0;have=false;out(:)=0;
 else
  out(1)=a(12);
  if a(12)
   age=mod(a(13)-state(6),2^32);
   active=have&&state(3)&&state(4)&&age<=80;
   out=[1 double(active) 0 0 0 0 state(5) a(13) age];
   if active
    e=state(10:11)';normal=[-e(2);e(1)];
    fc=round(state(8)*normal/65536);
    fs=round((-state(7)*e-state(9)*normal)/65536);
    mr=reshape(state(16:19),2,2)';mi=reshape(state(20:23),2,2)';
    voltage=(mr+1i*mi)*complex(fc,-fs)/65536;
    vr=round(real(voltage));vi=round(imag(voltage));
    raw=round((vr*a(14)-vi*a(15))/32768);
    out(3:4)=max(-131072,min(131071,raw))';
    out(5:6)=(raw>131071|raw< -131072)';
   end
  end
  if a(2),state=a;have=true;end
 end
 actual(k,:)=out;
end
assert(isequal(actual,expected),'D0:MATLABMismatch','独立MATLAB与整数golden不一致');
result=struct('rows',size(x,1),'fields',size(expected,2),'maximum_absolute_difference',max(abs(actual-expected),[],'all'),...
 'passed',true,'scope','独立MATLAB复数矩阵实现与公开接口golden逐拍核对；非机械闭环','matlab',version);
f=fopen(fullfile(root,'evidence','matlab_scoreboard.json'),'w','n','UTF-8');fprintf(f,'%s\n',jsonencode(result,PrettyPrint=true));fclose(f);
disp(result);
end
