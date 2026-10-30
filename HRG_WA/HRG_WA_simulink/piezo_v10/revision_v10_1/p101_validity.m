function q=p101_validity(I,Q,p,clipped,condition)
% No epsilon in SI charge units; use declared charge scale and geometry.
q.energy=sum(I.^2+Q.^2);N=I(1)^2+Q(1)^2-I(2)^2-Q(2)^2;
M=2*(I(1)*I(2)+Q(1)*Q(2));q.linearity=hypot(N,M)/max(q.energy,realmin);
q.valid=all(isfinite([I(:);Q(:);condition])) && ~clipped && ...
 q.energy>=(p.charge_target*p.min_amplitude_fraction)^2 && ...
 q.linearity>=p.min_linearity && condition<=p.max_calibration_condition;
q.pattern_angle=NaN;if q.valid,q.pattern_angle=atan2(M,N)/4;end
end
