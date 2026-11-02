function y=quality_values(d,p)
% 纯观察计算，无状态、无控制反馈；输入为18维原始诊断。
% 输出：归一化能量、归一化Q两路、正交残差、锁相检测残差、
% 三个时间差[us]、有效标志、频率[Hz]、能量相对误差[%]。
E=d(6);den=max(E,p.charge_target^2*1e-12);
I=d(1:2);Q=d(3:4);ok=d(8)==1&&d(18)==0&&all(isfinite(d(1:7)));
res=[Q/p.charge_target;2*(I(1)*Q(2)-I(2)*Q(1))/den;(I'*Q)/den];
if ~ok,res(:)=NaN;end
y=[E/p.charge_target^2;res;1e6*[d(11)-d(10);d(12)-d(10);d(13)-d(11)];double(ok);d(5)/(2*pi);100*(E/p.charge_target^2-1)];
end
