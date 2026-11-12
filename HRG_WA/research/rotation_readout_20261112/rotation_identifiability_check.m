function result = rotation_identifiability_check()
% 复核 DSH26 的轮转图案秩、两种平均顺序和角度敏感度。
% 代数观测假定四电极各自可测、路由增益已知、相位间机械状态一致。
identity = [1 2 3 4];
pairSwap = [2 1 4 3];
cycle = [2 3 4 1];
a = design(identity);
b = design([identity;pairSwap]);
c = design([identity;cycle]);
ranks = [rank(a),rank(b),rank(c)];
assert(isequal(ranks,[4 6 7]) && all(c*[ones(4,1);-ones(4,1)]==0));
beta = (0:4095)'*pi/(2*4096);
m = 0.02;
d = m/2;
z = @(d) (1+d^2)*cos(4*beta)+2*d+1i*(1-d^2)*sin(4*beta);
phaseError = @(v) angle(v.*exp(-4i*beta))/4;
first = phaseError(z(d));
swapped = phaseError(z(-d));
angleMean = (first+swapped)/2;
phasorMean = phaseError((z(d)+z(-d))/2);
basis = [sin(4*beta),cos(4*beta),sin(8*beta),cos(8*beta)];
fit = basis\[first,swapped,angleMean,phasorMean];
assert(abs(fit(1,3))<1e-12 && abs(fit(1,4))<1e-12);
assert(abs(fit(3,3)-d^2/4)<1e-8 && abs(fit(3,4)+d^2/4)<1e-8);
result = struct('rank_single_pair_cycle',ranks,'relative_mismatch_m',m, ...
    'harmonic_rows',{{'sin4beta','cos4beta','sin8beta','cos8beta'}}, ...
    'case_columns',{{'normal','swapped','angle_then_mean','phasor_mean_then_angle'}}, ...
    'fit_rad',fit,'angle_mean_residual_rms_rad',sqrt(mean(angleMean.^2)), ...
    'phasor_mean_residual_rms_rad',sqrt(mean(phasorMean.^2)));
disp(result)
end

function a = design(routes)
% 一行代表一个连接边。电子链与电极各有一个对数增益节点。
a = zeros(numel(routes),8);
for k=1:size(routes,1)
    rows=(k-1)*4+(1:4);
    a(rows,:)=[eyeAt(routes(k,:)),eye(4)];
end
end

function m = eyeAt(permutation)
m = eye(4);
m = m(permutation,:);
end
