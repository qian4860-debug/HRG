function [m,theta]=p101_low_metrics(r,p)
I=r.y(:,1:2);Q=r.y(:,3:4);N=I(:,1).^2+Q(:,1).^2-I(:,2).^2-Q(:,2).^2;
M=2*(I(:,1).*I(:,2)+Q(:,1).*Q(:,2));theta=unwrap(atan2(M,N))/2;
j=r.t>.6*p.envDuration;fit=polyfit(r.t(j)-mean(r.t(j)),theta(j),1);
estimate=(p.virtual_rate-fit(1))/(2*p.B);
m=struct('input_rate_rad_s',p.Omega,'estimated_rate_rad_s',estimate,...
 'absolute_rate_error',abs(estimate-p.Omega),'theta_slope',fit(1),'max_required_voltage_V',max(r.y(:,6)),...
 'deadzone_threshold_rad_s',abs(p.damping_half_difference)/(2*p.B),...
 'scope','First-order envelope, ideal calibrated force command; not a measured low-speed rating');
end
