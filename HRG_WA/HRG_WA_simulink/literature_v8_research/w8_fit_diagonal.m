function fit=w8_fit_diagonal(reference,measured)
% Offline fixture data: mechanical reference must be independently established.
% No mechanical truth is available to the running controller.
assert(size(reference,2)==2&&isequal(size(reference),size(measured)));
gain=zeros(2,1);beta=gain;condition=gain;residual=gain;
for k=1:2
 x=reference(:,k);y=measured(:,k);X=[x abs(x).^2.*x];
 condition(k)=cond(X);assert(condition(k)<1e5,'Fixture lacks amplitude diversity');
 p=X\y;gain(k)=p(1);b=p(2)/p(1);
 assert(abs(imag(b))<1e-6&&real(b)>=0,'Not the supported real cubic model');
 beta(k)=real(b);residual(k)=norm(X*p-y)/max(norm(y),eps);
end
fit=struct('senseInverse',diag(1./gain),'cubicCoefficient',beta, ...
 'condition',condition,'relativeFitResidual',residual, ...
 'scope','diagonal complex gain and positive fundamental cubic; synthetic fixture is not in-device identification');
end
