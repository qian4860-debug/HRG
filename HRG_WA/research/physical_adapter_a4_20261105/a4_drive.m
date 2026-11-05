function [u,clip,record]=a4_drive(s,p,c)
% 独立MATLAB整数D0内核；矩阵运算写法与RTL展开不同。
% 每个完整控制帧形成快照，frame_end是源时间，不是available。
a=c.adapter;
if norm(s.I)>p.charge_target*1e-6,e=s.I/norm(s.I);else,e=[1;0];end
n=[-e(2);e(1)];f=[-e'*s.Fs;n'*s.Fc;-n'*s.Fs]/a.F0;
assert(abs(e'*s.Fc)<max(1e-20,1e-10*norm(s.Fc)),'A4:Projection','Fc存在未支持的径向分量');
force=round(f*65536);direction=round(e*65536);
assert(all(force>=-524288&force<=524287),'A4:ForceRange','力系数超界，禁止静默截断');
carrier=round([cos(s.phase);sin(s.phase)]*65536);
if isfinite(s.frame_end),source=round(s.frame_end/p.Ts);else,source=0;end
age=mod(s.k-source,2^32);active=age<=80;
ni=[-direction(2);direction(1)];fc=round(force(2)*ni/65536);
fs=round((-force(1)*direction-force(3)*ni)/65536);
mr=reshape(a.matrix_codes(1:4),2,2)';mi=reshape(a.matrix_codes(5:8),2,2)';
voltage=(mr+1i*mi)*complex(fc,-fs)/65536;
vr=round(real(voltage));vi=round(imag(voltage));
raw=round((vr*carrier(1)-vi*carrier(2))/32768);
code=max(-131072,min(131071,raw));clip=raw>131071|raw< -131072;
if ~active,code(:)=0;clip(:)=0;end
u=code/131072*a.VFS;
% 与D0公开向量字段完全一致；cmd_update/sample_en由RTL回放包装器提供。
inputs=[0 1 1 1 s.id+1 source force' direction' 1 s.k carrier' a.matrix_codes];
outputs=[1 double(active) code' double(clip)' s.id+1 s.k age];
record=[inputs outputs];
end
