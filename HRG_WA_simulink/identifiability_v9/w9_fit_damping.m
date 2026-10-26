function fit=w9_fit_damping(t,iq)
% Integral power balance, no mechanical truth. Real, zero-quadrature envelope.
assert(size(iq,2)==2&&size(iq,1)==numel(t));
E=sum(iq.^2,2);assert(all(E>.01),'Below valid energy window');
theta=unwrap(atan2(2*iq(:,1).*iq(:,2),iq(:,1).^2-iq(:,2).^2))/4;
X=[t-t(1),cumtrapz(t,cos(4*theta)),cumtrapz(t,sin(4*theta))];
y=-.5*log(E/E(1));X=X(2:end,:);y=y(2:end);
scale=vecnorm(X);assert(all(scale>1e-10),'Damping fixture has no excitation');
Z=X./scale;s=svd(Z);assert(s(end)>1e-5*s(1),'Damping fixture does not identify all directions');
p=(Z\y)./scale';
fit=struct('gamma',p(1),'dc',p(2),'ds',p(3),'condition',s(1)/s(end), ...
 'residualRms',sqrt(mean((X*p-y).^2)),'samples',numel(t));
end
