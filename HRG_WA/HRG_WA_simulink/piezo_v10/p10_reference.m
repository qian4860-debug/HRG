function r=p10_reference(p)
% Explicit time-loop scoreboard for Simulink scheduling/wiring; shared tick
% is not an independent verification of controller physics (see analytic checks).
[Ad,Bd,x,H]=p10_plant(p);N=round(p.duration/p.Ts)+1;
r.t=(0:N-1)'*p.Ts;r.x=zeros(N,12);r.u=zeros(N,2);r.iq=zeros(N,7);s=[];
for k=1:N
 y=x(11:12).*[1;p.gain_y];lsb=p.adc_span/2^p.adc_bits;
 y=round(max(-p.adc_span/2,min(p.adc_span/2-lsb,y))/lsb)*lsb;
 [s,u,d]=p10_tick(s,y,p,H);r.x(k,:)=x';r.u(k,:)=u';r.iq(k,:)=d';x=Ad*x+Bd*u;
end
end
