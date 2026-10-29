function m=p10_metrics(t,x,u,iq,p)
I=iq(:,1:2);Q=iq(:,3:4);E=sum(I.^2+Q.^2,2);U=I(:,1).^2+Q(:,1).^2-I(:,2).^2-Q(:,2).^2;V=2*(I(:,1).*I(:,2)+Q(:,1).*Q(:,2));
ang=unwrap(atan2(V,U))/4;truth=(p.alpha0-2*p.B*p.Omega*t)/2;
hold=t>.6*p.duration;err=ang-truth;err=err-round(median(err(hold))/(pi/2))*pi/2;
L=I(:,1).*Q(:,2)-I(:,2).*Q(:,1);
m=struct('energy_relative_mean',mean(E(hold))/p.amp^2-1,'quadrature_rms',rms(2*L(hold)./max(E(hold),eps)),...
'pattern_angle_rms_deg',rms(err(hold))*180/pi,'angle_rms_deg',rms(err(hold))/abs(p.B)*180/pi,'angle_drift_deg_s',mean(diff(err(hold)))/p.Ts*180/pi,...
'pll_phase_rms',rms(sum(I(hold,:).*Q(hold,:),2)./max(E(hold),eps)),...
'drive_margin_V',p.vmax-max(abs(u),[],'all'),'max_displacement_m',max(abs(x(:,1:2)),[],'all'));
target=abs(sqrt(E)/p.amp-1)<.05;m.build_time_s=NaN;
for k=find(t>.05,1):numel(t)
 if all(target(k:end)),m.build_time_s=t(k);break;end
end
m.bias_equivalent_deg_s=-m.angle_drift_deg_s/p.B;
m.rate_noise_status='not_estimated: deterministic short fixture, no Allan/ARW claim';
end
