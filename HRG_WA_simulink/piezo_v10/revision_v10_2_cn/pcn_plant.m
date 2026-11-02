function [Ad,Bd,x0,A,B]=pcn_plant(p)
% 机电联合状态方程与精确零阶保持离散化。
% 输入p：物理/电路配置。输出Ad、Bd：一拍状态转移；x0：初始状态。
% x(1:2)=运动电荷r[C]；x(3:4)=电荷速度[C/s]；x(5:6)=驱动器电压[V]。
% x(7:8)=传感端口电压[V]；x(9:10)=电荷放大器电压[V]；x(11:12)=AFE电压[V]。
% 连续模型xdot=A*x+B*u；离散模型x[k+1]=Ad*x[k]+Bd*u[k]。
% 机械本征阻尼不含传感电路加载；加载通过显式端口状态回作用。
% 先按特征电荷/电压归一化再expm，防止量纲悬殊引入虚假低速漂移。
% Motional-charge coordinates: mechanical damping is intrinsic short-circuit
% damping ONLY. Sensor loading remains in explicit electrical states.
w=2*pi*p.f0;J=[0 -1;1 0];R=@(t)[cos(t) -sin(t);sin(t) cos(t)];
assert(p.gamma_intrinsic>abs(p.damping_half_difference));
assert(p.Omega==0||(~isempty(p.B)&&isfinite(p.B)&&p.B>0));
% 【中文步骤】刚度张量：两特征频率在独立刚度主轴上旋转回测量坐标。
K=R(p.stiffness_axis)*diag((w+[-1 1]*pi*p.split_hz).^2)*R(p.stiffness_axis)';
% 【中文步骤】阻尼张量：本征平均衰减率与阻尼不均匀量独立于刚度主轴。
D=R(p.damping_axis)*diag(2*(p.gamma_intrinsic+[1 -1]*p.damping_half_difference))*R(p.damping_axis)';
A=zeros(12);B=zeros(12,2);A(1:2,3:4)=eye(2);A(3:4,1:2)=-K;A(3:4,3:4)=-D;
if p.Omega~=0,A(3:4,3:4)=A(3:4,3:4)-4*p.B*p.Omega*J;end
A(3:4,5:6)=p.b*p.drive_matrix;A(3:4,7:8)=p.kappa*eye(2);
A(5:6,5:6)=-diag(1./p.driver_tau);B(5:6,:)=diag(1./p.driver_tau);
% 【中文步骤】传感节点KCL：静态电容、漏电、负载电导与运动电荷电流共同决定电压。
A(7:8,7:8)=-(1/p.Rs+p.G0)/p.Cs*eye(2);A(7:8,3:4)=-eye(2)/p.Cs;
A(7:8,:)=A(7:8,:)+p.Cds/p.Cs*A(5:6,:);B(7:8,:)=p.Cds/p.Cs*B(5:6,:);
% 【中文步骤】电荷放大器积分及Rf泄放；随后为双通道AFE有限带宽。
A(9:10,7:8)=eye(2)/(p.Rs*p.Cf);A(9:10,9:10)=-eye(2)/(p.Rf*p.Cf);
A(11:12,9:10)=diag(2*pi*p.afe_bw)*p.detect_matrix;A(11:12,11:12)=-diag(2*pi*p.afe_bw);
% Discretize in dimensionless state coordinates: charge C (~1e-11),
% velocity C/s and voltage V differ by many orders of magnitude. A raw-unit
% expm can hide low-rate errors behind a small matrix-relative residual.
qscale=p.charge_target;vscale=max(1e-6,w*qscale*p.Rs);
sc=[qscale qscale w*qscale w*qscale 1 1 vscale vscale qscale/p.Cf qscale/p.Cf qscale/p.Cf qscale/p.Cf];
% 【中文步骤】增广矩阵同时包含状态和输入；归一化后求指数再还原SI量纲。
S=diag([sc 1 1]);M=[A B;zeros(2,14)];E=S*expm((S\M*S)*p.Ts)/S;
Ad=E(1:12,1:12);Bd=E(1:12,13:14);
x0=zeros(12,1);x0(1:2)=p.initial_fraction*p.charge_target*[cos(p.theta0);sin(p.theta0)];
end
