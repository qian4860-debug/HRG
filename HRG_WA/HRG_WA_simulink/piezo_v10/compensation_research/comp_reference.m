function r=comp_reference(p,c,plant_p)
% MATLAB逐拍参考：用于核对Simulink接线和执行顺序。
% plant_p可与控制器p不同，以测试辨识或温漂失配。
% 每拍：取AFE输出、加已声明噪声、ADC量化、调用控制状态机、更新机电状态。
% 随机流固定种子用于复现；该参考与Simulink共用tick，不构成独立算法正确性证明。
% Scheduling replay shares tick; independent physics is tested separately.
if nargin<3,plant_p=p;end;pcn_validate(p,c);pcn_validate(plant_p);
assert(plant_p.Ts==p.Ts);[Ad,Bd,x]=pcn_plant(plant_p);N=round(p.duration/p.Ts)+1;r.t=(0:N-1)'*p.Ts;
r.x=zeros(N,12);r.u=zeros(N,2);r.d=zeros(N,18);r.adc=zeros(N,4);s=[];
stream=RandStream('mt19937ar','Seed',p.noise_seed);
for k=1:N
 y=x(11:12)+p.noise_rms_V*randn(stream,2,1);
 [y,~,clip]=pcn_quantize(y,p.adc_span,p.adc_bits);adc=[y;clip];
 [s,u,d]=comp_tick(s,adc,p,c);r.x(k,:)=x';r.u(k,:)=u';r.d(k,:)=d';r.adc(k,:)=adc';x=Ad*x+Bd*u;
end
end
