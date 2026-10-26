function fit=w9_fit_detection(reference,measured)
% Only independent-reference data; no access to plant configuration or truth.
assert(size(reference,1)==2&&isequal(size(reference),size(measured)));
assert(all(isfinite(reference(:)))&&all(isfinite(measured(:))));
sigma=svd(reference);assert(sigma(end)>.05*sigma(1),'Fixture reference lacks directional diversity');
D=measured/reference;assert(rcond(D)>.1,'Poorly conditioned sensing calibration');
fit=struct('matrix',D,'inverse',inv(D),'condition',sigma(1)/sigma(end), ...
 'relativeResidual',norm(measured-D*reference,'fro')/norm(measured,'fro'));
end
