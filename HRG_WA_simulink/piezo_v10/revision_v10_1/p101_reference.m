function r=p101_reference(p,c)
% Scheduling replay shares tick; independent physics is tested separately.
[Ad,Bd,x]=p101_plant(p);N=round(p.duration/p.Ts)+1;r.t=(0:N-1)'*p.Ts;
r.x=zeros(N,12);r.u=zeros(N,2);r.d=zeros(N,18);r.adc=zeros(N,4);s=[];
stream=RandStream('mt19937ar','Seed',p.noise_seed);
for k=1:N
 y=x(11:12)+p.noise_rms_V*randn(stream,2,1);
 [y,~,clip]=p101_quantize(y,p.adc_span,p.adc_bits);adc=[y;clip];
 [s,u,d]=p101_tick(s,adc,p,c);r.x(k,:)=x';r.u(k,:)=u';r.d(k,:)=d';r.adc(k,:)=adc';x=Ad*x+Bd*u;
end
end
