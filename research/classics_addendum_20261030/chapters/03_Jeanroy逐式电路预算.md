## 第二编第三章　Jeanroy：从高Q和频差推到电路精度

<a id="J01"></a>
### 原式(1)，PDF1：通用两自由度式与四种力

原文写

\[
m\ddot x+h_v\dot x+kx=2m\Omega\dot y+F_x,\quad
m\ddot y+h_v\dot y+ky=-2m\Omega\dot x+F_y.
\]

本书把原文阻尼字母h改写为 \(h_v\)，避免与半频差混淆。把右侧科氏项移到左侧，矢量式为 \(m\ddot q+h_v\dot q+kq+2m\Omega J\dot q=F\)。它相当于模态陀螺系数取1的简化模型；实际半球表头应恢复 \(\alpha=2B\)，不能从这个简式推出 \(B=1\)。

令 \(q=av\cos\omega t\)，速度 \(-a\omega v\sin\omega t\)。写四力

\[
F=P_{12}v\cos\omega t-P_{11}v\sin\omega t
+P_{22}w\cos\omega t-P_{21}w\sin\omega t.
\]

\(P\) 是有符号物理力峰值（N）。与Ragot式(7)逐系数对照：

\[
C_a=P_{11}/(2ma\omega),\quad C_p=P_{21}/(2ma\omega),
\quad C_r=-P_{12}/(2ma\omega),\quad C_q=-P_{22}/(2ma\omega).
\]

所以表1的 \(F_{11},F_{12},F_{21},F_{22}\) 应理解为经过定义后的作用通道，不可看到F就认为后文°/s数字仍是牛顿。通俗解释：方向和快相位共同决定力“帮着振动”“改变节奏”“转动驻波”还是“把轨迹推成椭圆”。

<a id="J02"></a>
### 原式(2)，PDF2：FTR所需方向力

锁角时需抵消科氏横向力。由简化式(1)，\(\dot q=-a\omega v\sin\omega t\)，其科氏项峰值 \(2ma\omega|\Omega|\)。按 \(2ma\omega\) 归一化后，方向命令幅值即 \(|\Omega|\)，原文写 \(F_{21}=\Omega\)。真实半球模式为

\[
|P_{21}|=2ma\omega\alpha|\Omega|,\qquad |C_p|=\alpha|\Omega|.
\]

这解释FTR为什么随输入率提高驱动动态。若已知压电驱动力系数 \(\Theta_d\,[N/V]\) 与驱动器传函 \(H_d(i\omega)\)，电压峰值为 \(V_{21}=|P_{21}|/(|\Theta_dH_d|)\)。若只有整链辨识结果，直接用端到端电压/电角率系数，不虚构 \(m,a,\Theta_d\) 各自的绝对值。

<a id="J03"></a>
### 原式(3)，PDF2：Q到振幅时间常数，逐个系数保留

\[
\ddot x+\frac{\omega_0}{Q}\dot x+\omega_0^2x=0.
\]

特征根实部 \(-\omega_0/(2Q)\)，因此 \(a(t)=a_0e^{-t/\tau}\)，\(\tau=2Q/\omega_0=Q/(\pi f_0)\)，归一化补能命令 \(C_a=1/\tau=\pi f_0/Q\)。也可从能量验证：\(E=ma^2\omega_0^2/2\)，\(\dot E=-\omega_0E/Q\)；两边除E，\(2\dot a/a=-\omega_0/Q\)，得到同一振幅时间常数。

当 \(f_0=10000Hz,Q=5000\)：\(\pi f_0/Q=2\pi=6.2831853s^{-1}\)，乘 \(180/\pi\) 得360°/s。Q改为 \(10^7\)：\(\gamma=0.00314159265s^{-1}\)，\(\tau=318.309886s\)，\(\gamma=0.18°/s=648°/h\)。这与原文一致。**能量**衰减常数为 \(\tau/2\)，做ring-down回归必须说清拟合的是幅度还是能量。

<a id="J04"></a>
### 原式(4)，PDF2：频差的Hz、rad/s和半差约定

原文写 \(F_{22}=df\)，并把1Hz换为360°/s、0.5mHz换为0.18°/s。按它的工程表述是 \(2\pi df\) 率量；式面省略了Hz到rad/s的换算。不能直接把这项等同于本书Ragot的 \(C_q\)。

从刚度独立演算：两主频为 \(\omega_x=\omega_0+h_f\)、\(\omega_y=\omega_0-h_f\)，略去 \(h_f^2\)，则 \(K/m=\omega_0^2I+2\omega_0h_f\operatorname{diag}(1,-1)\)。在与主轴夹45°时，横向刚度力峰值为 \(2ma\omega_0|h_f|\)。按前节的 \(2ma\omega_0\) 除，最大 \(|C_q|=|h_f|\)。而完整Hz频差

\[
df=\frac{\omega_x-\omega_y}{2\pi}=\frac{h_f}{\pi},\quad |C_q|_{max}=\pi|df|.
\]

所以按统一控制命令，1Hz对应180°/s，0.5mHz对应0.09°/s。原文360°/s是完整频差的角频率，不能同时当作同一归一化下的横向力命令；它可能体现工程幅值定义，论文未把该处力归一化交代到足以消除此2倍差。预算中同时列“文献率量 \(2\pi df\)”和“本书命令 \(\pi df\)”，再用载波模型注入确认，不能悄悄选择有利数字。

<a id="J05"></a>
### 原式(5)，PDF2：从力泄漏反推幅相误差上限

小误差 \(\epsilon\) 把主力通道的 \(\epsilon\) 比例漏入方向通道，所以原文写 \(D=\epsilon F_{ij}\)。在本书统一单位下：

\[
|\delta\dot\theta|\le|\epsilon_a C_a|+|\epsilon_q C_q|+|d|,
\quad |\delta\Omega|=|\delta\dot\theta|/\alpha.
\]

给定整机单项零偏预算 \(D_{max}\,[rad/s]\)，先化成电角率预算 \(\alpha D_{max}\)，再得 \(|\epsilon_a|\le\alpha D_{max}/|C_a|\)、\(|\epsilon_q|\le\alpha D_{max}/|C_q|\)。这是真正从系统指标往电路倒推的步骤。\(\epsilon_a\) 可能是轴失准或差分增益，\(\epsilon_q\) 常是相位泄漏；分别需要实际传函映射，不能统称为ADC位数。

复算原文：\(10^{-5}\times0.18\times3600=0.00648°/h\)，四舍五入 \(6.5\times10^{-3}\)。两个来源若完全同向，最坏和为0.01296°/h；只有不相关随机误差才可RSS。原文说各类误差优于0.01°/h，不代表两项最坏和也优于0.01。

PDF4参数用 \(f_0=7500Hz,Q=10^7\)，\(\gamma=\pi7500/10^7=0.00235619449s^{-1}\)，乘 \(180\times3600/\pi\) 得486°/h，原文约500。0.5mHz的**完整**角频差为648°/h，原文约650；统一半差命令为324°/h。10ppm泄漏分别为0.00486°/h和0.00324°/h电角率，再除 \(\alpha\) 才是整机率。文献数字是样机预算，不能移植为我们压电头的保证。

<a id="J06"></a>
### 原式(6)，PDF2：不平衡能量比例的假设

原文估计 \(dE=E\,dm/m\)。若一小质量 \(dm\) 与模态质量m有同一速度幅值，\(E\propto m v^2\)，就有该比例。若不平衡导致的质心位移幅值为主模态的 \(r\) 倍，能量比还应乘 \(r^2\)。因此 \(dm/m\) 在此是有效不平衡耦合的估计量，不能把任意静态称重质量差直接代进去。

<a id="J07"></a>
### 原式(7)，PDF2：支撑寄生模态的相位式及其限制

印刷关系为

\[
E'=dE\arctan\left[\frac{\omega_1\omega_2}{Q_2(\omega_2^2-\omega_1^2)}\right].
\]

括号来自二阶系统动态刚度 \(D_2=\omega_2^2-\omega_1^2+i\omega_1\omega_2/Q_2\) 的相位比。\(\tan\delta=\operatorname{Im}D_2/\operatorname{Re}D_2\)。但相位不是一般情况下每周期耗散能量比例；过共振相位应采用atan2分支，损耗能量必须非负。原式作为远离寄生共振的量级估计使用，不能当完整被动模型。

<a id="J08"></a>
### 原式(8)，PDF3：Q定义与原文数值重算

Q定义为 \(Q=2\pi E/E'\)，所以 \(1/Q_{dm}=E'/(2\pi E)\)。把(6)、(7)代入即原式(8)。数值用 \(\omega_1/2\pi=10000Hz,\omega_2/2\pi=1000Hz,Q_2=10,dm/m=10^{-3}\)：

\[
x=\frac{10000\times1000}{10(1000^2-10000^2)}=-0.0101010101,
\]
\[
\arctan x=-0.0101006666,\quad (10^{-3}/2\pi)\arctan x=-1.6075710\times10^{-6}.
\]

印刷公式照用给负耗散，而原文给正 \(1.6\times10^{-6}\)。要复现它的正量级需取损耗角绝对值；这一步是本书指出的必要解释，不是印刷式写明的绝对值。靠取绝对值也不能使它在共振附近变成完整能量模型。

<a id="J09"></a>
### 原式(9)，PDF3：多个损耗途径为什么倒数相加

各耗散功率相加，\(P_{loss}=\omega E/Q+\omega E/Q_{dm}\)。定义总Q满足 \(P_{loss}=\omega E/Q_g\)，两边除 \(\omega E\)：

\[
1/Q_g=1/Q+1/Q_{dm}.
\]

用原文舍入值 \(1/Q_{dm}=1.6\times10^{-6}\)、\(Q=10^7\)，总倒数 \(1.7\times10^{-6}\)，故 \(Q_g=588235.294\)。\(f=10kHz\) 时补能率 \(180f/Q_g=3.06°/s\)。原文以 \(Q_g\simeq Q_{dm}=625000\) 近似，得2.88°/s；10ppm泄漏 \(2.88\times10^{-5}\times3600=0.10368°/h\)，约0.1。若保留本征损耗，3.06给0.11016°/h。书中同时记录精确倒数和近似，不能把两种算法混成一条计算链。

### 本书补推：一个保证耗散为正的最小支撑模型

以下不是Jeanroy原式，而是用于V10后续扩展的物理一致替代。两个坐标x、y采用对称惯性耦合 \(\kappa\)，令 \(\kappa^2<m_1m_2\) 保证质量正定。频域矩阵为

\[
\begin{bmatrix}k_1-m_1\omega^2+i c_1\omega&-\kappa\omega^2\\
-\kappa\omega^2&k_2-m_2\omega^2+i c_2\omega\end{bmatrix}
\begin{bmatrix}x\\y\end{bmatrix}=\begin{bmatrix}F\\0\end{bmatrix}.
\]

第二行给 \(y=\kappa\omega^2x/(k_2-m_2\omega^2+ic_2\omega)\)。代第一行，附加动态刚度

\[
\Delta K=-\frac{\kappa^2\omega^4}{a+ib}
=-\frac{\kappa^2\omega^4a}{a^2+b^2}+i\frac{\kappa^2\omega^4b}{a^2+b^2},
\quad a=k_2-m_2\omega^2,\ b=c_2\omega.
\]

对正频率与 \(c_2>0\)，虚部恒非负。令 \(k_i=m_i\omega_i^2,c_2=m_2\omega_2/Q_2\)，在主频 \(\omega_1\) 处，弱耦合近似附加倒数Q为

\[
\Delta(1/Q)=\frac{\operatorname{Im}\Delta K}{m_1\omega_1^2}
=\frac{\mu\omega_1^3\omega_2/Q_2}{(\omega_2^2-\omega_1^2)^2+(\omega_1\omega_2/Q_2)^2},
\quad \mu=\kappa^2/(m_1m_2).
\]

它同时给耗散和频移，且共振附近有有限阻尼分母。不能将 \(\mu\) 直接等同于原文 \(dm/m\)；需支撑振动/频响测试辨识。通俗解释：支撑不是凭空“吃掉一部分Q”，而是被主振子带动，再通过自身阻尼消耗能量；能量必须去向明确且非负。

### PDF4–8：从器件预算走到系统证据

平面电极/封装、六自由度平衡、低频差与高Q协同降低所需控制力，这是本文最有价值的设计链条。文中温度、振动、20g/9ms冲击、6只陀螺六个月老化、八个方位各十次五分钟对准、两小时飞行及海试提供不同维度证据。0.6mrad对准RMS约0.03438°；它属于整个惯导及对准算法，不是单陀螺瞬时角度误差。

海试误差 \(0.1°\sec(纬度)\) 与地球自转水平分量 \(\Omega_E\cos\lambda\) 相关。简单静态寻北线性化：\(\Omega_N=\Omega_E\cos\lambda\cos\psi\)，\(\Omega_East=-\Omega_E\cos\lambda\sin\psi\)；小航向误差由横向率误差除 \(\Omega_E\cos\lambda\)，因此高纬误差放大。以49°为例 \(0.1/\cos49°=0.15243°\)。这些系统结果不能用于证明当前V10压电模型已经达到同样等级。
