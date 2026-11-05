function r=a4_reference(p,c,z,integer)
N=numel(z.segment);s=sn_state('unpack',sn_state('init',p));x=z.x0;r.t=(0:N-1)'*p.Ts;
r.x=zeros(N,14);r.u=zeros(N,2);r.d=zeros(N,23);r.adc=zeros(N,4);r.interface=zeros(N,32);psi=0;
for k=1:N
 j=z.segment(k);r.x(k,:)=[x;z.omega(j);psi]';
 [y,~,clip]=pcn_quantize(x(11:12)+z.noise(k,:)',p.adc_span,p.adc_bits);adc=[y;clip];
 if integer
  [~,~,r.interface(k,:)]=a4_drive(s,p,c);[s,u,d]=a4_control_tick(s,adc,p,c);
 else,[s,u,d]=sn_tick(s,adc,p,c);end
 r.u(k,:)=u';r.d(k,:)=d';r.adc(k,:)=adc';x=z.Ad(:,:,j)*x+z.Bd(:,:,j)*u;psi=psi+z.omega(j)*p.Ts;
end
end
