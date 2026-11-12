function out = rot_calib_algebra()
% 旋转采样（通道轮转）可辨识性的代数验证。
% 只做信号域代数：给定驻波角 beta，理想 I/Q 为 [cos2b; sin2b]。
% 通道增益/相位失配是 I/Q 的线性变换，因此可在信号域精确施加。
% 不替代带开关瞬态和闭环的完整仿真。
here = fileparts(mfilename('fullpath'));
beta = linspace(0,pi,4001).';           % 覆盖 4beta 两个周期
w = [sin(4*beta), cos(4*beta), sin(8*beta), cos(8*beta), ones(size(beta))];
out = struct('generated',datestr(now,31),'cases',[]);

% 情形1：只有通道增益失配（+1%/-1%），无换向、换向平均、换向差分。
d = 0.01;
[e0,~] = chanErr(beta,beta,1,1,0,0);
[e1,~] = chanErr(beta,beta,1+d,1-d,0,0);
[e2,~] = chanErr(beta,beta,1-d,1+d,0,0);
[eavg,~] = chanErrAvg(beta,beta,1+d,1-d,1-d,1+d,0,0,0,0);
[ediff,~] = chanErrDiff(beta,beta,1+d,1-d,1-d,1+d,0,0,0,0);
out.cases = [out.cases; packCase('增益失配',e0,e1,e2,eavg,ediff,w,d)];

% 情形2：通道相位失配（+0.5deg/-0.5deg）。
phi = 0.5*pi/180;
[e1p,~] = chanErr(beta,beta,1,1,phi,-phi);
[e2p,~] = chanErr(beta,beta,1,1,-phi,phi);
[eavgp,~] = chanErrAvg(beta,beta,1,1,1,1,phi,-phi,-phi,phi);
[ediffp,~] = chanErrDiff(beta,beta,1,1,1,1,phi,-phi,-phi,phi);
out.cases = [out.cases; packCase('相位失配',e0,e1p,e2p,eavgp,ediffp,w,phi)];

% 情形3：机械各向异性（等效 4beta 角度误差）+ 通道增益失配。
% 机械误差作用在信号上；真值仍是 beta，因此 e = betaHat - beta 同时含两者。
kmech = 0.002;                           % rad，夸大以便观察
betaMech = beta + kmech*sin(4*beta);
[eM,~] = chanErr(beta,betaMech,1,1,0,0);          % 纯机械
[eCM,~] = chanErr(beta,betaMech,1+d,1-d,0,0);     % 机械+通道
[eSw,~] = chanErr(beta,betaMech,1-d,1+d,0,0);     % 换向
[eAvgCM,~] = chanErrAvg(beta,betaMech,1+d,1-d,1-d,1+d,0,0,0,0);
[eDiffCM,~] = chanErrDiff(beta,betaMech,1+d,1-d,1-d,1+d,0,0,0,0);
c = packCase('机械+通道',e0,eM,eCM,eAvgCM,eCM-eAvgCM,w,d);
c.amp4b = harm(eCM,w); c.amp4b_mech = harm(eM,w); c.amp4b_combined = harm(eCM,w);
c.amp4b_swapped = harm(eSw,w); c.amp4b_avg = harm(eAvgCM,w);
c.amp4b_diff = harm(eDiffCM,w);
c.sin4b = signed(eCM,w); c.sin4b_swapped = signed(eSw,w);
out.cases = [out.cases; c];

% 情形4：4 电极 + 4 通道，轮转能否分离“每电极增益”与“每通道增益”。
out.ident = identifiability();

fid = fopen(fullfile(here,'rot_calib_algebra.json'),'w','n','UTF-8');
assert(fid>=0); fprintf(fid,'%s\n',jsonencode(out,'PrettyPrint',true)); fclose(fid);
fprintf('IDENT rank=%d nullity=%d\n',out.ident.rank,out.ident.nullity);
for k=1:numel(out.cases)
    c = out.cases(k);
    fprintf('%-10s 4b=%.4g 8b=%.4g | swapped=%.4g avg=%.4g diff=%.4g\n', ...
        c.name,c.amp4b,c.amp8b,c.amp4b_swapped,c.amp4b_avg,c.amp4b_diff);
end
end

function c = packCase(name,e0,e1,e2,eavg,ediff,w,d)
c = struct('name',name,'mismatch',d, ...
    'amp4b',harm(e1,w),'amp4b_swapped',harm(e2,w),'amp4b_avg',harm(eavg,w), ...
    'amp4b_diff',harm(ediff,w),'amp8b',harmBand(e1,w,2), ...
    'sin4b',signed(e1,w),'sin4b_swapped',signed(e2,w), ...
    'amp4b_nominal',harm(e0,w),'edge',[max(abs(e1)),max(abs(eavg))], ...
    'amp4b_mech',NaN,'amp4b_combined',NaN);
end

function a = signed(e,w)
% sin(4beta) 项的有符号系数，用于观察换向前后符号翻转。
coef = w\e; a = coef(1);
end

function a = harm(e,w)
coef = w\e; a = hypot(coef(1),coef(2));
end
function a = harmBand(e,w,band)
coef = w\e; idx = 2*band-1; a = hypot(coef(idx),coef(idx+1));
end

function [e,betaHat] = chanErr(betaTrue,betaSignal,gx,gy,phix,phiy)
% betaSignal 是产生信号的真实驻波角；betaTrue 是用于取误差参考的标称角。
betaHat = estimate(betaSignal,gx,gy,phix,phiy);
e = betaHat - betaTrue;
end

function [e,betaHat] = chanErrAvg(betaTrue,betaSignal,gx1,gy1,gx2,gy2,phix1,phiy1,phix2,phiy2)
% 两相轮转：先各自算相量，再平均，最后取角。对应“换向平均”解调。
z = (phasor(betaSignal,gx1,gy1,phix1,phiy1)+phasor(betaSignal,gx2,gy2,phix2,phiy2))/2;
betaHat = unwrap(angle(z))/4;
e = betaHat - betaTrue;
end

function [e,betaHat] = chanErrDiff(betaTrue,betaSignal,gx1,gy1,gx2,gy2,phix1,phiy1,phix2,phiy2)
% 两相轮转的角度差之半：通道误差在两相间符号相反，故半差直接给出它。
b1 = estimate(betaSignal,gx1,gy1,phix1,phiy1);
b2 = estimate(betaSignal,gx2,gy2,phix2,phiy2);
betaHat = (b1-b2)/2;
e = betaHat - 0*betaTrue;   % 期望值即通道误差本身，真值参考为 0
end

function betaHat = estimate(betaSignal,gx,gy,phix,phiy)
betaHat = unwrap(angle(phasor(betaSignal,gx,gy,phix,phiy)))/4;
end

function [I,Q] = rot(I,Q,phi)
% 通道相位误差等价于把该通道的 I/Q 相量旋转 phi。
I2 = cos(phi)*I - sin(phi)*Q;
Q2 = sin(phi)*I + cos(phi)*Q;
I = I2; Q = Q2;
end

function z = phasor(beta,gx,gy,phix,phiy)
Ix = gx*cos(2*beta); Qx = zeros(size(beta));
Iy = gy*sin(2*beta); Qy = zeros(size(beta));
[Ix,Qx] = rot(Ix,Qx,phix); [Iy,Qy] = rot(Iy,Qy,phiy);
N = Ix.^2+Qx.^2-Iy.^2-Qy.^2;
M = 2*(Ix.*Iy+Qx.*Qy);
z = N + 1i*M;
end

function r = identifiability()
% 观测模型（对数域）：第 k 相轮转下，第 i 个电极的读数权重为
%   w_i^(k) = u_{pi_k(i)} + v_i
% u 为通道对数增益，v 为电极对数增益。轮转只置换 u 的下标。
% 未知数 8 个；加常数 c 到所有 u、减 c 到所有 v 不改变观测，故规范自由度 1。
perms = {[1 2 3 4], [2 1 4 3], [3 4 1 2], [4 3 2 1]};
A = zeros(4*numel(perms),8);
row = 1;
for k = 1:numel(perms)
    p = perms{k};
    for i = 1:4
        u = p(i); v = i;      % u 在 1:4，v 在 5:8
        A(row,u) = 1; A(row,4+v) = 1; row = row+1;
    end
end
r.rank = rank(A); r.nullity = size(A,2)-rank(A);
r.null_basis = null(A).';
r.gauge = 'u+c, v-c 不改变观测 -> 全局尺度不可辨';
r.perms = perms;
r.rank_by_phases = zeros(1,numel(perms));
for k = 1:numel(perms)
    r.rank_by_phases(k) = rank(A(1:4*k,:));
end
A1 = A(1:4,:);
r.rank_single_phase = rank(A1); r.nullity_single_phase = 8-rank(A1);
end
