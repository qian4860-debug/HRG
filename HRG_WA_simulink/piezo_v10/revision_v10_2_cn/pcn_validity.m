function q=pcn_validity(I,Q,p,clipped,condition)
% 角度有效性：能量足够且驻波接近直线时才可观。
% E=Ix²+Iy²+Qx²+Qy²；N=Ix²+Qx²-Iy²-Qy²；M=2(IxIy+QxQy)。
% linearity=sqrt(N²+M²)/E：理想直线约1，圆振动约0。
% pattern_angle=atan2(M,N)/4为物理驻波角β，模态方向θ=2β。
% 零信号、圆振动、截幅、非有限值或病态标定都不能输出有效零角。
% No epsilon in SI charge units; use declared charge scale and geometry.
q.energy=sum(I.^2+Q.^2);N=I(1)^2+Q(1)^2-I(2)^2-Q(2)^2;
M=2*(I(1)*I(2)+Q(1)*Q(2));q.linearity=hypot(N,M)/max(q.energy,realmin);
q.valid=all(isfinite([I(:);Q(:);condition])) && ~clipped && ...
 q.energy>=(p.charge_target*p.min_amplitude_fraction)^2 && ...
 q.linearity>=p.min_linearity && condition<=p.max_calibration_condition;
q.pattern_angle=NaN;if q.valid,q.pattern_angle=atan2(M,N)/4;end
end
