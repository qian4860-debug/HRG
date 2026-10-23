# 全角模式文献建模：从公式逐步推导的对比

日期：2026-10-23。比较对象：四篇指定核心文献、已经取得正文证据的其他方法族，以及原有 73 项本地、80 项网上资料目录。本文是新增审查稿，不改写已验收 V7 的代码、模型、证据或旧报告。

**结论先行：**四篇核心文献共享“两个近简并模态—同步解调—椭圆参数—能量、正交、相位控制—驻波角输出”主线。差别主要在坐标约定、平均近似、误差参考平面和控制/补偿结构。并不是所有公式只差一个系数：原文局部存在不能用坐标变换解释的不自洽；双行波锁相、原始载波 Kalman 解调、在线辨识也确实改变了状态或观测模型。

## 0. 阅读证据及如何使用这份对比

全文 PDF 页码从文件第一页起算，区别于论文印刷页。L/W 编号沿用已有 `layered/evidence/literature_comparison/comparison_catalog.json`，避免同名、重复文件被当成独立来源。

|编号|文献与本次比较的正文依据|推导重点|
|---|---|---|
|L057|陈洋《半球谐振陀螺量化误差与阻尼误差抑制技术研究》，2023；PDF24–26、49–51、59–60、66、70|机械模型、椭圆不变量、小短轴平均方程、量化与阻尼补偿|
|L054|蒲云飞《半球谐振陀螺全角模式控制技术研究与实现》，2022；PDF43–46；实现章节证据见旧目录|PI→PR→PIR 的稳态误差推导与低频切换|
|L053|刘学《半球谐振陀螺全角模式控制与误差补偿系统设计与实现》，2024；PDF55–59、62–65|数字解调、系统实现、阻尼/虚拟进动补偿|
|L052|张岚昕等《半球谐振陀螺全角模式信号处理控制方法》，2019；PDF2–5，尤其3–4|早期完整信号处理与控制框架；检查印刷式一致性|
|L058|杨小龙等《基于Kalman滤波解调的半球谐振陀螺全角控制方案及仿真》，2023；PDF1–6，其中4–6为本次补读|直接估计载波余弦/正弦系数，不是对导航角度做 Kalman|
|L061|关泽源等《基于频率解调的半球谐振陀螺控制系统设计》，2023；PDF2–3 行波分解，4–5系统证据|顺逆行波分离及两路 PLL 的差频|
|L059|《基于RLS算法的全角模式半球谐振陀螺自补偿方法》，2023；PDF1–6|角位置谐波回归与递推辨识|
|L063|Zhao 等，Dead Area Compensation in Rate-Integrating HRG，2021；已有PDF1–5证据，本次核对机械式及阈值的缓存页|阻尼各向异性、死区与反馈补偿|
|L039|Real-Time Elimination of Harmonic Drift … Based on FRP Control Scheme，2026；PDF1–8已有证据，本次核对4–5|虚拟进动/往返运动与谐波漂移在线估计|
|L050/L055/L056|参数辨识、误差分离及通道全温补偿文献；具体节选页见目录|辨识参数的物理含义与可辨识边界|
|L069|《谐振陀螺仪系统理论》；PDF27、30等已有阅读证据|连续体模态投影的上游背景；不是据此已计算本表头的 Bryan 因子|

其他本地和网上条目的逐项映射见 [corpus_mapping.md](corpus_mapping.md)。目录覆盖不等于全文公式覆盖；摘要、题录、不能解析的文件均保留相应状态。没有正文时不从标题编造其状态方程。本文中“推导”是统一假设下重新演算，“原文”仅指标明页码/式号的内容。

## 1. 先把角度、短轴和解调符号统一

### 1.1 物理驻波角不是模态向量角

取壳口周向角为 \(\psi\)，二阶工作模态的主要形状写成

\[
w(\psi,t)=x(t)\cos2\psi+y(t)\sin2\psi.\tag{1}
\]

若线性驻波位于物理角 \(\theta\)，

\[
w=a\cos[2(\psi-\theta)]\cos\Phi
=a[\cos2\theta\cos2\psi+\sin2\theta\sin2\psi]\cos\Phi.
\tag{2}
\]

所以模态向量朝向是 \(\alpha=2\theta\)，不是 \(\theta\)。二次不变量再引入一倍角度，最终得到 \(4\theta\)。这是文献中“2”和“4”最常见的来源，必须在比较动力学系数以前确定。

### 1.2 本文统一约定

\[
J=\begin{bmatrix}0&-1\\1&0\end{bmatrix},\quad
R(\alpha)=\begin{bmatrix}\cos\alpha&-\sin\alpha\\\sin\alpha&\cos\alpha\end{bmatrix}.
\tag{3}
\]

物理位移 \(q=(x,y)^T=A_{ref}\Re\{z e^{j\omega_0t}\}\)，无量纲复包络取

\[
z=e^{j\varphi}R(\alpha)\binom{a}{jb},\quad a>|b|,\quad\alpha=2\theta.
\tag{4}
\]

其中 \(b\) **带符号**，表示椭圆旋向；不能用无符号短半轴替代。展开得

\[
\begin{aligned}
x/A_{ref}&=a\cos\alpha\cos\Phi+b\sin\alpha\sin\Phi,\\
y/A_{ref}&=a\sin\alpha\cos\Phi-b\cos\alpha\sin\Phi,
\end{aligned}\quad\Phi=\omega_0t+\varphi.\tag{5}
\]

四篇核心文献常用的短轴符号 \(q_p\) 则写为

\[
x=a_p\cos\alpha_p\cos\Phi-q_p\sin\alpha_p\sin\Phi,\quad
y=a_p\sin\alpha_p\cos\Phi+q_p\cos\alpha_p\sin\Phi.\tag{6}
\]

在相同坐标、载波相位、幅度单位下，映射为

\[
a=a_p/A_{ref},\qquad b=-q_p/A_{ref},\qquad\alpha=\alpha_p.
\tag{7}
\]

不要把式(6)的 \(q_p\) 直接代入式(4)，否则正交控制方向会反。

### 1.3 IQ 支路还要再检查一次符号与增益

本文采用 \(2\cos\omega_0t\) 与 \(-2\sin\omega_0t\) 同步解调，则

\[
C=\Re z,\quad S=\Im z,\qquad z=C+jS.\tag{8}
\]

若文献直接使用 \(\cos\)、\(+\sin\) 混频并低通，它得到

\[
C_p=C/2,\quad S_p=-S/2;\qquad z=2(C_p-jS_p).\tag{9}
\]

若文献定义的系数已经补过2倍增益，只有正弦符号变换，没有幅值2倍。由式(9)可知，二次不变量差4倍；其中与 \(S\) 奇次相关的不变量还变号。仅对齐角度、却不对齐 IQ 参考，就无法比较 \(Q\)、锁相误差和 PI 增益。

## 2. 从连续表头到各篇共用的双模态机械式

### 2.1 模态投影，而不是凭经验指定每个系数

设完整三维位移场 \(u(r,t)=\phi_x(r)x(t)+\phi_y(r)y(t)\)。先写动能、弹性能和耗散，再对两个广义坐标做 Lagrange 方程：

\[
M_{ij}=\int_V\rho\phi_i\cdot\phi_j\,dV,\quad
K_{ij}=\int_V\varepsilon(\phi_i):\mathcal C:\varepsilon(\phi_j)\,dV,
\quad D_{ij}\text{由耗散投影或试验辨识}.\tag{10}
\]

旋转动能的交叉项产生反对称陀螺矩阵。对近简并、同一归一化的一对模态，取 \(M\simeq mI\)，其常用一阶形式是

\[
\ddot q+(2\Gamma+4B\Omega J)\dot q+
\frac Km q+2B\dot\Omega Jq=\frac Fm.\tag{11}
\]

\(B\) 是本文“物理驻波角/壳体角”的有符号 Bryan 增益约定。其值需要三维模态积分或校准；只有式(1)的标量壳口形状，不能推出本表头的数值。改变轴方向可改变符号，不能不看约定直接把某篇的 \(k\)、\(\lambda\) 填成工程 \(B\)。

式(11)保留一阶 \(\Omega,\dot\Omega\) 项。部分文献还保留旋转坐标中的 \(\Omega^2\) 刚度项，部分直接忽略。只有在相同坐标和相同量级截断下才能称其等价，不能为所有论文指定一个通用的离心项系数。

### 2.2 阻尼和刚度主轴分开表示

定义

\[
A_\beta=R(2\beta)\operatorname{diag}(1,-1)R^T(2\beta)
=\begin{bmatrix}\cos4\beta&\sin4\beta\\\sin4\beta&-\cos4\beta\end{bmatrix}.
\tag{12}
\]

\[
\Gamma=\gamma I+\frac{\Delta\gamma}{2}A_{\beta_d},\quad
\frac Km\simeq\omega_n^2I-\omega_n\Delta\omega A_{\beta_k},\quad
\Delta\omega=2\pi\Delta f.\tag{13}
\]

这里 \(\Delta\gamma\) 是**振幅衰减率特征值的全差**；\(\Gamma\) 特征值为 \(\gamma\pm\Delta\gamma/2\)。\(\beta_d,\beta_k\) 是物理主轴角，允许不同；有符号 \(\Delta\omega\) 的正负与主轴编号必须一起保存。

例如文献有 \(\ddot x+(2/\tau)\dot x+\omega_n^2x=0\)，包络衰减为 \(e^{-t/\tau}\)，故

\[
\gamma=1/\tau,\qquad Q_m\simeq\omega_n/(2\gamma),\qquad
\Delta\gamma=1/\tau_1-1/\tau_2.\tag{14}
\]

把二阶方程中的 \(2/\tau\) 当成包络衰减率，会把启动增益、阻尼补偿量和死区阈值同时放大2倍。

### 2.3 与 L057 式(2.12)逐项对应

L057 PDF24 写的交叉速度是 \(-2k\Omega\dot y,+2k\Omega\dot x\)，阻尼非对角项为 \(\Delta(1/\tau)\sin2\theta_\tau\)，刚度项为 \(\omega\Delta\omega\cos2\theta_\omega\) 等。若其 \(x,y\) 与式(1)具有相同投影意义，则

\[
\alpha_p=2\theta,\quad \theta_{\tau,p}=2\beta_d,\quad
\theta_{\omega,p}=2\beta_k,\quad k=2B,\quad
\Delta(1/\tau)=\Delta\gamma.\tag{15}
\]

于是论文里的 \(\cos2(\alpha_p-\theta_{\tau,p})\) 正是本文的 \(\cos4(\theta-\beta_d)\)。若另一篇直接把物理角叫 \(\theta\)，它的系数表会不同。L057 PDF49–51 的例子用 \(k=0.5\)、\(\Omega=30^\circ/s\) 得模态角速度约 \(-0.2618\,rad/s\)，说明必须先看变量含义，不能凭“典型常数约0.3”强行配对。

**能量结构检查：**纯 Coriolis 项应满足

\[
\dot q^T J\dot q=0.\tag{16}
\]

它只改变方向，不直接做功。这是比比较正负号更可靠的第一项核查。

## 3. 从二阶机械式推到复包络：明确省掉了什么

\[
\dot q=A_{ref}\Re\{(\dot z+j\omega_0z)e^{j\omega_0t}\},\quad
\ddot q=A_{ref}\Re\{(\ddot z+2j\omega_0\dot z-\omega_0^2z)e^{j\omega_0t}\}.
\tag{17}
\]

令 \(F(t)=\Re\{F_ce^{j\omega_0t}\}\)。在
\(|\dot z|\ll\omega_0|z|\)、\(\gamma,|\Delta\omega|,|B\Omega|\ll\omega_0\) 下，舍掉 \(\ddot z\)、\(\Gamma\dot z\)、\(\Omega J\dot z\) 等高阶慢变项。先忽略 Euler 项，得到

\[
2j\omega_0\dot z+2j\omega_0\Gamma z+
4j\omega_0B\Omega Jz+(K/m-\omega_0^2I)z=F_c/(mA_{ref}).
\tag{18}
\]

除以 \(2j\omega_0\)：

\[
\boxed{\dot z=-\Gamma z+jHz-2B\Omega Jz+h},\quad
H=\frac{K/m-\omega_0^2I}{2\omega_0}\simeq\delta I-dA_{\beta_k},
\quad d=\pi\Delta f,\quad h=\frac{F_c}{2jm\omega_0A_{ref}}.
\tag{19}
\]

\(\delta\simeq\omega_n-\omega_0\)。若保留式(11)的 Euler 项，式(19)另有

\[
+j\frac{B\dot\Omega}{\omega_0}Jz.\tag{20}
\]

因此平均模型与载波模型的等价是有带宽条件的；快速角加速度、开关边沿、谐振外噪声和混叠，不能由式(19)自动代表。L052 显式写角加速度项、部分慢变量论文不写该项，首先是近似范围差异，不能只靠改系数消除。

## 4. 不先假设短轴为零：完整椭圆慢变量推导

### 4.1 旋转到椭圆坐标

令 \(w=(a,jb)^T\)，\(\widetilde h=e^{-j\varphi}R^T(\alpha)h\)，\(g=\Delta\gamma/2\)、\(\nu=2B\Omega\)。定义

\[
c_d=\cos4(\beta_d-\theta),\quad s_d=\sin4(\beta_d-\theta),\quad
c_k=\cos4(\beta_k-\theta),\quad s_k=\sin4(\beta_k-\theta).
\tag{21}
\]

式(4)求导、左乘 \(e^{-j\varphi}R^T\)：

\[
\dot w+j\dot\varphi w+\dot\alpha Jw=
[-\Gamma'+jH'-\nu J]w+\widetilde h.\tag{22}
\]

取第一分量实部、第二分量虚部：

\[
\dot a=-(\gamma+gc_d)a+ds_kb+\Re\widetilde h_1,\quad
\dot b=-(\gamma-gc_d)b-ds_ka+\Im\widetilde h_2.\tag{23}
\]

另外两个分量给出

\[
\begin{bmatrix}a&-b\\-b&a\end{bmatrix}
\binom{\dot\varphi}{\dot\alpha}=
\binom{a(\delta-dc_k)+b(\nu-gs_d)+\Im\widetilde h_1}
{-a(\nu+gs_d)-b(\delta+dc_k)+\Re\widetilde h_2}.\tag{24}
\]

定义 \(E=a^2+b^2\)、\(Q=2ab\)、\(D=a^2-b^2=\sqrt{E^2-Q^2}>0\)。式(24)的行列式恰为 \(D\)，求逆得

\[
\dot\varphi=\delta-dc_k\frac ED-gs_d\frac QD+
\frac{a\Im\widetilde h_1+b\Re\widetilde h_2}{D},\tag{25}
\]

\[
\dot\alpha=-\nu-dc_k\frac QD-gs_d\frac ED+
\frac{b\Im\widetilde h_1+a\Re\widetilde h_2}{D}.\tag{26}
\]

物理角速度是 \(\dot\theta=\dot\alpha/2\)：

\[
\boxed{\dot\theta=-B\Omega+
\frac{\Delta\gamma}{4}\frac ED\sin4(\theta-\beta_d)
-\frac{\pi\Delta f}{2}\frac QD\cos4(\theta-\beta_k)
+\frac{b\Im\widetilde h_1+a\Re\widetilde h_2}{2D}}.\tag{27}
\]

这里清楚区分三项：理想进动、阻尼各向异性、频差×正交残差；还有执行力在角向上的投影。频差本身不必然在 \(Q=0\) 时直接产生该阶角漂移，但会通过式(23)不断生成短轴，闭环必须压制。

### 4.2 直接推能量和正交量

由 \(\dot E=2a\dot a+2b\dot b\)、\(\dot Q=2b\dot a+2a\dot b\)：

\[
\boxed{\dot E=-2\gamma E-\Delta\gamma D\cos4(\theta-\beta_d)
+2\Re(z^\dagger h)},\tag{28}
\]

\[
\boxed{\dot Q=-2\gamma Q+2\pi\Delta f D\sin4(\theta-\beta_k)
+2\Re[z^\dagger(iJ)h]}.\tag{29}
\]

这些是对式(19)的**精确变量变换**，不是对完整非线性壳体、载波电路的无条件精确模型。特别是 \(D\to0\) 时接近圆形轨迹，驻波方向与公共相位不能独立辨识；此时简单把分母夹成 epsilon 会掩盖状态退化，应标记估计无效/切换启动策略。

### 4.3 L057/L054 等常用方程在哪里作了近似

若 \(|Q|/E\ll1\)，则

\[
D=E\sqrt{1-(Q/E)^2}\simeq E,\qquad a\simeq\sqrt E.
\tag{30}
\]

替换误差从 \((Q/E)^2\) 阶开始。L057 PDF26 式(2.18)、L054 PDF43 式(3.3)的 \(\sqrt E\)、\(Q/E\) 正是这种控制工作点附近的形式。它们适合分析已建幅、短轴已小的闭环；不应从零能量直接用 \(Q/E\) 积分来代表完整启动，更不能据此证明大椭圆瞬态等价。

## 5. 四个力分量如何对应能量、正交、相位与进动

取论文常用力分解

\[
\frac{F(t)}{mA_{ref}}=R(\alpha)
\binom{f_{ac}\cos\Phi+f_{as}\sin\Phi}
{f_{qc}\cos\Phi+f_{qs}\sin\Phi}.\tag{31}
\]

此处 \(f\) 已除以 \(mA_{ref}\)，单位为 \(s^{-2}\)；若论文写的是牛顿，须补除质量和幅值参考。利用 \(\Re[(u-jv)e^{j\Phi}]=u\cos\Phi+v\sin\Phi\)，式(19)给出

\[
\widetilde h_1=\frac{-f_{as}-jf_{ac}}{2\omega_0},\qquad
\widetilde h_2=\frac{-f_{qs}-jf_{qc}}{2\omega_0}.\tag{32}
\]

在 \(b\simeq0\) 时：

|力分量|本文工作点作用|含义|
|---|---|---|
|\(f_{as}\)|\(\dot E|_F=-a f_{as}/\omega_0\)|沿主轴、速度相位；能量/建幅|
|\(f_{qc}\)|\(\dot Q|_F=-a f_{qc}/\omega_0\)|横向、位移相位；正交抑制；论文 \(Q_p=-Q\) 因而符号反转|
|\(f_{ac}\)|\(\dot\varphi|_F=-f_{ac}/(2\omega_0a)\)|主轴、位移相位；频率/相位扰动|
|\(f_{qs}\)|\(\dot\theta|_F=-f_{qs}/(4\omega_0a)\)|横向、速度相位；虚拟进动/角向控制|

代入式(15)与 \(Q_p=-Q\)，L057 的 \(\dot\alpha_p=-k\Omega+\tfrac12\Delta\gamma\sin2(\alpha_p-\alpha_d)+\tfrac12\Delta\omega\cos2(\alpha_p-\alpha_k)Q_p/E-f_{qs}/(2\omega_0\sqrt E)\) 就与式(27)的小短轴形式相符。

相位误差的符号必须从实际参考重建：文献把 \(\delta\phi\) 叫“输入相位减 PLL 相位”，未必就与本文 \(\varphi\) 同号，特别是在其正弦支路或正交激励也翻号时。应先用式(8)/(9)还原复包络，再比较相位误差，而不是仅比较变量名。

**控制器参数不能整组照搬：**控制 \(a\) 与控制 \(E\) 的小信号误差相差 \(\delta E=2a_0\delta a\)；控制 \(Q\) 与 \(Q/E\) 相差 \(E_0\)；控制原始 \(L\) 与控制相位相差 \(2D_0\)。再乘解调、ADC、DAC和力增益，才得到实际开环增益。

## 6. 从 IQ 推出角度、相位和量化灵敏度

### 6.1 先推不变量，再选择 atan2

由式(4)/(8)直接展开：

\[
E=|z_x|^2+|z_y|^2,\quad Q=2(C_xS_y-S_xC_y),\tag{33}
\]

\[
R=|z_x|^2-|z_y|^2,\quad S_\theta=2(C_xC_y+S_xS_y),\quad
R+jS_\theta=D e^{j2\alpha}=D e^{j4\theta},\tag{34}
\]

\[
M=C_x^2-S_x^2+C_y^2-S_y^2,\quad
L=2(C_xS_x+C_yS_y),\quad M+jL=z_x^2+z_y^2=D e^{j2\varphi}.
\tag{35}
\]

\[
\theta=\tfrac14\operatorname{unwrap}\arg(R+jS_\theta),\quad
\varphi=\tfrac12\arg(M+jL).\tag{36}
\]

角度支路的连续展开还需初始方向/旋向信息；仅一个时刻的二次不变量给出物理驻波角模 \(\pi/2\)，不能恢复无界全角。单参数 \(\arctan(S/R)\) 还会丢象限。

\[
a=\frac{\sqrt{E+Q}+\sqrt{E-Q}}2,\quad
b=\frac{\sqrt{E+Q}-\sqrt{E-Q}}2.\tag{37}
\]

式(37)保留带符号短轴；要求 \(E\ge|Q|\)，且明确 \(a\ge|b|\)。归一化有噪观测违反不等式时，应记录违规和估计不确定度，不能悄悄取绝对值制造“物理”数据。

### 6.2 角速度与噪声传播

\[
\dot\theta=\frac{R\dot S_\theta-S_\theta\dot R}{4(R^2+S_\theta^2)},\quad
\delta\theta=\frac{R\delta S_\theta-S_\theta\delta R}{4D^2}.\tag{38}
\]

L057 PDF51 式(4.5)分母为2，是其模态角 \(\alpha\) 的导数；物理角还须除2。若使用同一符号却直接比较两篇角速度，便会错误判断模型差2倍。

令 \(v=(C_x,S_x,C_y,S_y)^T\)，则

\[
\nabla R=2(C_x,S_x,-C_y,-S_y)^T,\quad
\nabla S_\theta=2(C_y,S_y,C_x,S_x)^T,
\quad g_\theta=\frac{R\nabla S_\theta-S_\theta\nabla R}{4D^2}.
\tag{39}
\]

\[
\sigma_\theta^2\simeq g_\theta^T\Sigma_vg_\theta.\tag{40}
\]

这比只写 ADC 的 \(\Delta^2/12\) 更完整：必须先把 ADC、解调、抽取、通道相关性传播到 \(\Sigma_v\)。相干采样、截断、DAC回路误差常产生随角度周期变化的确定性误差，并不满足独立白噪声条件。L057研究的内部量化/模拟同步解调参考平面，与数字 ADC 后解调结构的量化位置不同，不能同用一个 ENOB 公式替代。

## 7. 四篇核心文献：逐式相同点、不同点与局部核查

### 7.1 L057 陈洋：最适合作为统一慢变量对照，但需保留近似与参考平面

推导链为 PDF24 式(2.12)/(2.13)二阶方程→PDF25式(2.14)椭圆→式(2.15)/(2.16)系数和不变量→PDF26式(2.18)平均控制方程→PDF51量化误差→PDF59起阻尼死区/补偿。

相同点：式(15)与 \(Q_p=-Q\) 后，阻尼、频差、科里奥利和四个力分量均能在小短轴条件下对应式(27)–(32)。不同点：其控制方程不是任意大椭圆的精确变换；其模拟解调和内部量化问题不能等同于本工程所有 ADC/DAC 误差。

**局部公式核查：**PDF25 式(2.16)复数 \(L\) 表达式的印刷实部为 \(C_x^2-S_x^2-C_y^2+S_y^2\)，同时宣称等于 \(D e^{j2\delta\phi}\) 的实部。取 \(a=1,q_p=0,\alpha=\pi/4,\delta\phi=0\)，由同页式(2.15)有 \(C_x=C_y=1/\sqrt2,S_x=S_y=0\)：印刷实部=0，右端=1。与旋转无关的正确公共相位不变量是式(35)的“加两个模态平方”，而不是相减。该反例只定位同页局部不自洽，不代表整篇实验或实际程序错误。

### 7.2 L054 蒲云飞：机械层相同，主要创新在周期误差控制

PDF43 式(3.3)仍是小短轴平均框架。其 PI/PR/PIR 推导中，先用单位对象说明内模原理。以单位负反馈对象 \(P(s)=1\) 为例：

\[
C_{PI}=k_p+k_i/s,\qquad R_h(s)=\frac{\omega_h}{s^2+\omega_h^2},\quad
E_h=\frac{R_h}{1+C_{PI}}.
\tag{41}
\]

取稳态频响，正弦误差幅度为

\[
|e_h|=\frac{\omega_h}{\sqrt{(1+k_p)^2\omega_h^2+k_i^2}}.\tag{42}
\]

PI不能对非零 \(\omega_h\) 的正弦误差保证零稳态残差。改为 PDF45 式(3.12)的

\[
C_{PR}=k_p+\frac{k_rs}{s^2+\omega_h^2},\qquad
E_h(s)=\frac{\omega_h}{(1+k_p)s^2+k_rs+(1+k_p)\omega_h^2}.\tag{43}
\]

在 \(k_p>-1,k_r>0,\omega_h>0\) 的这个简化对象下，分母稳定，误差衰减到0。然而 PR 的阶跃误差为 \(1/(1+k_p)\)，所以再加入积分：

\[
C_{PIR}=k_p+k_i/s+\frac{k_rs}{s^2+\omega_h^2}.\tag{44}
\]

这说明为什么要同时抑制直流和周期项。因阻尼项是 \(\sin4\theta\)，其时间频率约 \(\omega_h=4|\dot\theta|\)；不是固定等于壳体转速频率。接近死区时 \(\dot\theta\) 非匀速，固定谐振器失谐；原文的低频 PI/PIR 切换有实际意义。

真正对象为 \(P(s)\)，灵敏度应改成 \(1/[1+P(s)C(s)]\)。解调滤波延迟、幅度环、PLL及DAC会改变相位裕度，不能用式(43)单位对象的稳定条件宣布完整系统稳定。当前 V7 用带泄漏的测频谐振支路，有限带宽提高稳健性，也意味着不能声称与理想无损 PIR 零误差完全等价。

### 7.3 L053 刘学：实现闭环和补偿条件必须补写清楚

PDF55系统图为 C/V→ADC→FPGA数字解调→控制/补偿→DAC/开关；PDF56式(4.6)明确用 \(\cos2\vartheta\) 的物理角表达。PDF57式(4.9)又给 \(R=D\cos4\vartheta,S=D\sin4\vartheta\)，与式(34)一致。

**角度公式的局部问题：**PDF57式(4.10)、PDF62式(4.19)的角度写成 \(\arctan(S/R)\)，未显式给 \(1/4\)。若沿用式(4.9)的同一物理角定义，则应为式(36)。取 \(\vartheta=0.1\,rad\)，\(\operatorname{atan2}(S,R)=0.4\,rad\)，不是0.1。实际程序可能在别处缩放/展开，单凭论文印刷式不能断言硬件输出有4倍误差；但不能直接照抄这个式子。

PDF65 式(4.20)把输出分为虚拟、阻尼、地球项：\(w=w_T+w_s+w_e\)。若在**相同方位**、同一坐标符号和等大反向虚拟进动下，

\[
w_+=+v+d(\theta)+w_e,\quad w_-=-v+d(\theta)+w_e,
\quad\frac{w_++w_-}{2}=d(\theta)+w_e.\tag{45}
\]

因此 PDF65 式(4.21)将均值直接解释为阻尼项，需要地球投影已扣除/为零等条件；未知恒定输入也会混入。若两个方向增益不同，还多出 \((v_+-v_-)/2\)；若方位不同，则平均的是两个阻尼值。这不是靠“相加还是相减”的名称可以避免的问题。

同页式(4.22)的每个合力还必须重新投影到式(31)的主轴/横轴、cos/sin四基底，才能确认新增 \(F_s\) 实际是补能还是角向进动。仅凭名称叫“虚拟科氏力”不足以证明其满足式(32)的 \(f_{qs}\) 通道。

### 7.4 L052 张岚昕等：框架可参考，印刷式不能不经结构检查直接实现

该文建立二自由度机械、椭圆、解调不变量、PI/PLL/正交闭环和Simulink，框架与后来的几篇一致。但 PDF3 的几处印刷关系应独立校验：

1. 式(3)两个交叉 Coriolis 速度项都印成负号：\(-2k\Omega\dot y\)、\(-2k\Omega\dot x\)。按其同页正交模态解释，矩阵为对称非对角矩阵，不满足式(16)。取 \(k\Omega=0.6,\dot q=(1,2)^T\)，其 \(\dot q^TG\dot q=-4.8\ne0\)。正交坐标反射/换轴不会把一个对称矩阵变为反对称矩阵，因此这不只是旋向约定；须核对排版或原模型。
2. 同页椭圆式(4)的角参数与解调式(6)的二倍角写法需要额外变量映射，不能按同名变量强行相等。
3. 式(7)一个 \(R\) 的代数定义与右侧角函数不一致：取线性振动 \(a=1,q=0,\theta=\phi=0\)，不补2倍的解调系数给 \(C_x=1/2\)，代数定义的 \(R=1/4\)，所印 \(\sin2\theta\) 右端却为0。交换 R/S 名字仍需同步改其定义、方向和后续 atan2，不能只换一个函数。

处理方式是从同一位移式按式(8)–(35)重推整套信号，而不是逐个打补丁。这些局部反例不否定其系统结构、仿真或所有实验结论。

## 8. 其他方法族：究竟改变了哪一层方程

### 8.1 L058：Kalman 替代的是载波解调估计器

PDF4–6 式(21)–(23)：单路采样信号

\[
y_k=C_k\cos\omega t_k+S_k\sin\omega t_k+n_k,\quad
\xi_k=\binom{C_k}{S_k},\quad
\xi_{k+1}=I_2\xi_k+w_k,\quad H_k=(\cos\omega t_k,\sin\omega t_k).
\tag{46}
\]

\[
P_k^-=P_{k-1}^++Q_w,\quad K_k=P_k^-H_k^T(H_kP_k^-H_k^T+R_n)^{-1},
\quad\hat\xi_k^+=\hat\xi_k^-+K_k(y_k-H_k\hat\xi_k^-).\tag{47}
\]

其 Joseph 协方差更新保留数值半正定性。估计得到两路C/S，再走椭圆和PI。与本文式(8)物理量相同，但观测器是时变 \(H_k\)，不再只是固定混频+低通。

可观性要求采样相位提供两个独立方向；若总采同一载波相位，或有效采样窗退化，\(\sum H_k^TR_n^{-1}H_k\) 不满秩。噪声协方差和随机游走假设也须与通道和慢变量带宽相符。当前 V7 的 Kalman 是导航端 \([\theta,\dot\theta]\) 滤波，不能据其名称声称已复现这篇的 ADC→IQ Kalman 解调。

### 8.2 L061：不是换一个 atan，而是把驻波拆成两路行波

采用论文的带符号短轴 \(q_p\)，令 \(u=x+jy\)。由式(6)：

\[
u=e^{j\alpha}(a\cos\Phi+jq_p\sin\Phi)
=\frac{a+q_p}{2}e^{j(\Phi+\alpha)}
+\frac{a-q_p}{2}e^{-j(\Phi-\alpha)}.\tag{48}
\]

所以顺逆两路的正频率参考相位可以选择 \(\Phi\pm\alpha=\Phi\pm2\theta\)：

\[
\omega_+=\dot\Phi+2\dot\theta,\quad
\omega_-=\dot\Phi-2\dot\theta,\quad
\boxed{\dot\theta=(\omega_+-\omega_-)/4},\quad
\dot\Phi=(\omega_++\omega_-)/2.\tag{49}
\]

L061 PDF2–3 的两路 PLL/幅度分离由此而来；论文顺逆方向若与本文相反，差频顺序也反。其物理角标度仍应回到 \(\Omega=-\dot\theta/B\) 的已校准方向。

公共谐振频漂在差频中消去，但差分锁相误差不消去：\(\delta\dot\theta=(\delta\omega_+-\delta\omega_-)/4\)。电路不匹配、短轴导致两行波幅度不等、PLL带宽不同仍影响输出。它改变了观测和控制结构；不能说只把 IQ 后的 atan 换成频率计就实现了原文。

### 8.3 L063/L057：阻尼死区从同一个标量方程产生

令 \(Q\simeq0\)、无角向控制，式(27)变为

\[
\dot\theta=-B\Omega+A_d\sin4(\theta-\beta_d),\quad A_d=\Delta\gamma/4.
\tag{50}
\]

若 \(|B\Omega|\le|A_d|\)，存在固定点，部分为稳定点，驻波可能锁在某方向而不连续进动。因此理想化死区边界为

\[
|\Omega|\le\frac{|\Delta\gamma|}{4|B|}.\tag{51}
\]

L057 PDF59–60 的模态角形式是 \(\dot\alpha_p=-k\Omega+\tfrac12\Delta\gamma\sin2(\alpha_p-\alpha_d)\)，阈值 \(k|\Omega|\le|\Delta\gamma|/2\)，用式(15)后相同。

L063 的陀螺矩阵写成相反方向、角增益记为 \(\lambda\)；若其解的角是模态向量方向，须先转物理角；若已定义为物理角，则按其自身空间投影映射。不能只看到 \(\lambda\approx0.275\) 就认定与本文 \(B\) 同一系数，更不能据命名反过来判定其整个模型错误。

式(51)不含静电刚度、通道误差、有限正交残差和反馈补偿，实际死区可能不同。补偿后要重新用式(27)和实际执行矩阵计算剩余角向项。

### 8.4 L059/L050：RLS 并没有增加一个新的机械定律

把式(50)写为回归：

\[
\dot\theta+B\Omega=c_s\sin4\theta+c_c\cos4\theta+c_0,\quad
c_s=A_d\cos4\beta_d,\quad c_c=-A_d\sin4\beta_d.
\tag{52}
\]

\[
h_k=(\sin4\theta_k,\cos4\theta_k,1)^T,\quad
K_k=\frac{P_{k-1}h_k}{\lambda_f+h_k^TP_{k-1}h_k},\quad
\hat c_k=\hat c_{k-1}+K_k(y_k-h_k^T\hat c_{k-1}),
\quad P_k=\frac{(I-K_kh_k^T)P_{k-1}}{\lambda_f}.\tag{53}
\]

此处 \(\lambda_f\) 为遗忘因子，与 L063 角增益符号无关。原文可能用模态角、归一化输出或更多谐波，先做式(15)/(38)换元，再比较回归基底。固定一个方位时设计矩阵秩最多1，三个参数不可唯一辨识；需要覆盖足够方位/注入已知激励。未知 \(\Omega\)、地球项或零偏进入常数/谐波，不能因为残差下降就宣布“已分离纯机械阻尼”。

小椭圆及通道非理想会改变式(52)系数甚至引入8次等高阶项。增加基底前必须说明具体误差机制及独立可观性，不能无限增加拟合项后赋予每项一个机械解释。

### 8.5 L039/虚拟往返进动：利用对称性分离，不是无条件抵消

在相同 \(\theta\) 上配对正反向运动，设已去除已知输入后的读数为

\[
y_\pm(\theta)=\pm v\,[1+\epsilon_\pm(\theta)]+d_\pm(\theta)+b_\pm.
\tag{54}
\]

若 \(\epsilon_+=\epsilon_-\)、\(d_+=d_-=d\)、\(b_+=b_-=b\)，

\[
(y_++y_-)/2=d(\theta)+b,\quad
(y_+-y_-)/(2v)=1+\epsilon(\theta).\tag{55}
\]

方向偶对称漂移和方向奇对称增益项由此分离。L057 PDF70 式(5.17)–(5.19)对单向虚拟进动积累增益误差、正反交替降低该误差的讨论，与 FRP 方法族是相关的对称性思想，但不能把不同论文的训练、在线辨识和切换协议当成同一个算法。

失配时均值残差含 \(v(\epsilon_+-\epsilon_-)/2\)、温漂和配对方位误差。FRP 覆盖足够方位、正反路径和参数更新时间是算法本体的一部分；它不是在角度输出后加一条任意正弦拟合即可等价。

### 8.6 检测/执行通道与机械误差分离：为何需要先校准电路

令检测 \(d=G_sz\)，实际驱动 \(h=G_uh_c\)，机械复矩阵 \(A=-\Gamma+jH-2B\Omega J\)。若 \(G_s\) 为固定可逆矩阵：

\[
\dot d=G_sAG_s^{-1}d+G_sG_uh_c.\tag{56}
\]

对任意可逆 \(T\)，取 \(A'=TAT^{-1},G_s'=G_sT^{-1},G_u'=TG_u\)，观测模型不变。这个相似变换自由度说明，仅从一条闭环轨迹拟合得很好，不能唯一分离机械各向异性、检测交叉耦合和驱动失配。L050/L055/L056 与单纯阻尼回归不同，必须讨论校准、结构约束和独立激励。

若 \(G_s(s)\) 带频率响应，甚至不能用常数相似变换概括；应增加滤波器状态、延迟和采样时序。对感测与驱动分别建模，才能把某个拟合系数归因到某一电路模块。

### 8.7 L002：从电极间隙推到实际执行矩阵，而非只拟合阻尼

该2025驱动误差论文的 PDF4 式(8)–(17)从倾斜表头引起的周向间隙出发，PDF5式(18)–(22)加入安装角与两路相位，PDF6用不同虚拟进动速度做差后辨识。它增加的是式(56)的 \(G_u\)，而不是改一个机械阻尼常数。

以局部平行电容作独立简化推导，\(C\propto1/g\)、\(F\propto V^2/g^2\)。若 \(g=g_0+\delta g\)，

\[
\frac{1}{g^2}\simeq\frac1{g_0^2}(1-2\delta g/g_0),\quad
\frac{\delta G_u}{G_u}\simeq-2\delta g/g_0.\tag{61}
\]

因此小的电极间隙不均直接成为驱动增益不均；电极转角改变空间基底，相位延迟改变时间基底。以对齐电极、只存在两路实数增益 \(g_x,g_y\) 为例，理想补能 \(h_c=u_Ez\) 变为 \(h=u_E\operatorname{diag}(g_x,g_y)z\)。在 \(b=0\) 时投影到横轴：

\[
\widetilde h_2=\frac{u_Ea(g_y-g_x)}2\sin2\alpha,\quad
\delta\dot\theta=\frac{u_E(g_y-g_x)}4\sin4\theta.\tag{62}
\]

它与机械阻尼造成的4次角谐波同形，却随补能控制量变化。只有一个工况时容易混淆；L002的多速度、控制力同步采集和同方位做差正是增加辨识信息。其全文采用的阻尼差参数还存在“半差”定义：PDF6把 \(\Delta(\tau^{-1})\) 定为两轴逆时间常数之差的一半；不能与L057的全差同名照抄。

### 8.8 L003：从四次质量谐波到PLL频差识别，再到物理调平

这篇2025虚拟进动/离子束调平文献 PDF2–3 的路线与“压住短轴”不同：通过转动驻波扫描刚度各向异性，再改变表头质量分布。其上游关系可由模态积分解释：

\[
\cos^22\psi-\sin^22\psi=\cos4\psi,\quad
2\cos2\psi\sin2\psi=\sin4\psi.\tag{63}
\]

所以二阶模态的质量矩阵差分/交叉项对周向密度四次谐波敏感。一般小扰动特征频率满足

\[
\delta\omega_i/\omega_i\simeq\tfrac12\delta K_i/K_i-\tfrac12\delta M_i/M_i.
\tag{64}
\]

材料/几何相关常数仍要通过模态计算或调平标定得到，不能只根据式(63)预测去除多少质量。

由式(25)，在 \(Q\simeq0\)、附加相位力已消除时，实际载频含 \(-d\cos4(\theta-\beta_k)\)。换成Hz：

\[
f_{PLL}(\theta)\simeq f_0-\frac{\Delta f}{2}\cos4(\theta-\beta_k),\quad
\theta(t)=\theta_0+\omega_vt.\tag{65}
\]

论文式(7)/(8)写正号，可通过高低频轴编号和有符号频差映射；拟合的振幅绝对值对应 \(|\Delta f|/2\)。区别在于：阻尼回归用的是角速率中的正弦项，频差识别用的是PLL频率中的余弦项。必须消除式(25)中的正交残差、电子相位及控制力投影，不能把所有PLL波动都当机械频裂。

**新增局部单位核查：**已渲染核对PDF3，式(6)印作 \(f=f_0+2\pi\,\Delta\dot\phi\)。如果相位以rad、频率以Hz定义，转换应为 \(\Delta f=\Delta\dot\phi/(2\pi)\)。其后给出的 \(\Delta f/2\) 谐波幅值可独立由式(65)推出；不能将该行的 \(2\pi\) 系数直接实现。该页其他 \(\omega\) 定义也需要与Hz/rad统一后使用。

离子束调平是改变 \(M,K\) 的加工闭环；静电调谐改变等效 \(K\)；正交反馈只施加 \(h\)。三者虽然都可能降低某个残差，物理作用位置和温度/幅度依赖不同。

### 8.9 L038：闭环单通道TDM还多了一层检测跟踪闭环

该2025论文 PDF7–9 式(10)–(19)不是简单共用ADC。设输入复载波为 \(A_c\)，DAC跟踪量为 \(D_f\)，采集通道为 \(G_{fw}\)，反馈输出通道为 \(G_{fb}\)：

\[
D_e=G_{fw}(A_c-G_{fb}D_f),\quad
D_f=C(s)D_e,\quad
\frac{D_f}{A_c}=\frac{C G_{fw}}{1+C G_{fw}G_{fb}}.
\tag{66}
\]

在稳定且环路增益足够大时 \(D_f\simeq G_{fb}^{-1}A_c\)，所以采集通道的增益/相位影响降低，但跟踪量仍带逆反馈通道。若驱动阶段复用同一个 \(G_{fb}\)，再输出 \(G_{fb}D_f\simeq A_c\)，理想条件下才进一步抵消。有限增益、延迟、开关注入、通道在读出/驱动阶段不一致，会破坏抵消；不能把原文理想闭环结论理解为所有噪声和误差都消失。

该文PDF9还指出X/Y不同时刻采集：若间隔 \(T_c/2\)，在模态角上不同步约 \(\Delta\alpha=2\dot\theta(T_c/2)=\dot\theta T_c\)。把两时刻的IQ当同时值代入式(34)，会产生运动相关误差。这个误差既不等于普通静态通道相位差，也不等于单纯的占空比损失。

### 8.10 L064及经典控制专利：把“合力”进一步落实到每个电极

L064 PDF4–7 的路线仍是椭圆/不变量/能量与正交控制，重点在相位跟踪和16电极的矢量合成。模态坐标中的一般投影可独立写为

\[
F_q=\sum_i b_i F_i,\quad b_i\propto\binom{\cos2\psi_i}{\sin2\psi_i},\quad
B_e=(b_1,\ldots,b_N),\quad B_e F_e=F_q.\tag{67}
\]

电极基底、极性、有效面积已知后才能分配；欠定情形还要满足单极静电力、偏置、饱和等约束，伪逆只是无约束解。参考论文画出16电极、项目使用8电极时，机械式可能仍相同，但 \(B_e\) 不同，不能照抄每路电压。

其PDF5式(5)的S/C支路文本存在重复参考符号，式(6)的若干增益也需从实际混频器重新核对；本文不靠这些印刷增益证明本项目等价。PDF6的角输出明确为 \(2\phi_0\)，说明“先输出二倍角，再在下游换算”本身可以是合法设计，前提是接口标度写清楚。

经典 EP1722193A2（L030）与 EP3096111B1（L032）等专利的已读部分提供时空控制分量、振型提取、频率校正/刚度抑制等实现路线；它们不是另一套自然定律。本文将其落在式(31)、式(59)、式(67)的执行/调谐层。尚只有摘要的专利保持摘要级，不能据其权利要求标题推出每个电压公式。

### 8.11 L071：非线性RIG不能只加一个与方向无关的频漂

该2022作者稿PDF4–6式(3)–(11)在二维平动MEMS模型上增加轴向Duffing项。它的 \(x,y\) 是实际平动坐标，不应自动套用半球壳的 \(\alpha=2\theta\) 物理关系。

以每轴 \(D_ix_i^3\) 为例，\(x_i=A_i\cos\Phi\) 给

\[
x_i^3=\frac{3A_i^3}{4}\cos\Phi+\frac{A_i^3}{4}\cos3\Phi,\quad
\omega_{i,eff}^2\simeq\omega_i^2+\frac34D_iA_i^2.\tag{68}
\]

因此即使 \(D_x=D_y\)，不同方向分配的 \(A_x,A_y\) 也会产生方向相关的等效频差。复包络的一阶基频近似新增

\[
\dot z_i\big|_{nl}=j\frac{3D_iA_{ref}^2}{8\omega_0}|z_i|^2z_i.\tag{69}
\]

与各向同性 \(\eta|z|^2z\) 相比，式(69)是逐轴非线性，不能混为同一个模型；三倍频在平均层被舍弃，在电路载波层可能仍重要。该文研究的是特定MEMS结构及电调谐带来的非线性，不能不经表头辨识就把它的系数用于石英半球。它也不能自动代表网上2026 ORE摘要所称的完整非对称整流机制。

### 8.12 专利及硬件相邻资料如何比较而不夸大

|资料族/编号示例|应落入的数学位置|与核心四篇的实质区别|
|---|---|---|
|CN102812328A（L009）非线性测角补偿|式(39)的测量非线性，增加可校准谐波/查表|校正观测映射，不能替代机械误差抑制|
|CN105547272A（L010）压电全角检测|式(31)/(56)/(67)中的换能与控制矩阵|压电驱动力与静电平方律不同；不可复用式(59)的电压换算|
|CN117705163A（L027）分阶段自激标补|式(56)的观测/执行参数，先验/已知激励约束|阶段和外部参考是可辨识性条件，不只是换拟合器|
|CN112504258B（L060）自适应控制电路|C/V、ADC、FPGA/DAC闭环及接口|系统实施例不是器件噪声/稳定裕度的数值证明|
|仅摘要的主动进动/差分调频/死区专利（如L019/L029/L042/L049）|按已知公开摘要登记到调谐、行波或补偿方法族|未读完整实施例时不宣称已验证具体方程、全部权利要求或创新性|
|ADC/DAC、接口ASIC（L006/L007/L008/L073）|式(40)、式(56)、式(58)–(60)的实现限制|数据手册/ASIC指标不能直接证明某表头整机零偏；需要完整传递链和带宽|
|NASA条目、企业综述、结构/制造专利|应用背景、结构先验和可实现参数范围|不是直接替代式(11)–(29)的控制数学模型|

这里把“结构/制造、系统实现、观测估计、机械与控制推导”分开，是为了逐式比较的对象一致。未取得正文的条目见全目录，不能给它虚构一套详细推导来凑齐覆盖率。

## 9. 相位延迟、电路及采样怎样进入同一套公式

### 9.1 “PLL显示锁定”不等于机械工作在共振点

Nature Scientific Reports 2025 的相位延迟辨识论文把驱动链和检测链延迟分开，并明确 PLL 测得相位包含机械与电子相位。这里用式(19)–(32)独立说明其机制，不借用未经换元的论文系数。

理想正交控制 \(h_Q=ju_QJz\)，若回路相位误差 \(\epsilon\) 令其变为 \(h_Qe^{j\epsilon}\)，在 \(b=0\) 的椭圆坐标中 \(\widetilde h_2=ju_Qa e^{j\epsilon}\)。故

\[
\boxed{\delta\dot\theta=-\frac{u_Q}{2}\sin\epsilon
\simeq-\frac{u_Q\epsilon}{2}},\qquad
\delta\Omega\simeq\frac{u_Q\epsilon}{2B}.\tag{57}
\]

这解释频差很大、正交驱动力很大时，为何极小相位误差也会恶化零偏。单独验收 \(L\to0\) 不够：应同时记录机械相位、检测链相位、驱动链相位及正交控制量。PLL稳态误差、机械失谐和数字参考误差是不同量。

可核对的主来源：[Identification and correction of phase delay errors for hemispherical resonator gyroscopes](https://www.nature.com/articles/s41598-025-86288-1)。该段仅用其相位分解结论；式(57)系数按本文约定自推。

### 9.2 C/V 与 TIA 的“相同”和“不同”

小位移近似 \(\Delta C\simeq C_x x+C_y y\)，电流 \(i_s\simeq V_b\,d(\Delta C)/dt\)。理想反馈阻抗 \(Z_f=R_f/(1+sR_fC_f)\) 时

\[
V_o(s)=-\frac{V_bR_fs}{1+sR_fC_f}\Delta C(s).\tag{58}
\]

在 \(\omega R_fC_f\gg1\) 的电荷放大区，\(V_o\simeq-V_b\Delta C/C_f\)；在另一极限则近似微分跨阻响应。两者可由同一传函描述，但工作区、噪声、环路稳定、输入电容和载波相位完全不同，不能因为都叫C/V就忽略它们对式(57)的影响。

### 9.3 静电执行与电调谐不是同一简化级别

\[
F_i=\frac12\frac{\partial C_i}{\partial q}V_i^2,\quad
V_i=V_{bi}+v_i,
\quad F_i=\frac12C_i'V_{bi}^2+C_i'V_{bi}v_i+\frac12C_i'v_i^2.
\tag{59}
\]

线性驱动保留中项；二次项产生直流和二倍频；再对位移求导会产生静电负刚度并改变 \(H\)。只在驱动端加饱和/非线性，不能声称实现了在线电调谐：后者还要辨识频差/轴角并更新偏置电压，再对机械刚度闭环。

### 9.4 分时电极要建采样观测，不只是乘占空比

有效观测窗 \(m_k\in\{0,1\}\) 下，载波估计可写为

\[
y_k=m_kH_k\xi_k+n_k,\qquad
\mathcal I_N=\sum_{k\in有效窗}H_k^TR_n^{-1}H_k.\tag{60}
\]

未观测时只预测、不把零值当测量更新；采样保持、驱动残留、卸荷恢复、开关注入分别建状态/扰动。相同占空比但不同窗相位会有不同 \(\mathcal I_N\) 和 IQ 条件数，所以不能以占空比一个标量代替所有分时效应。

当前 V7 的真实驱动/卸荷/读出窗仍是双通道同时读出；没有据此宣称已实现所有论文的单通道复用协议。器件未知时可扫参数，但不能将假设参数当成已识别表头指标。

## 10. 用同一验收量比较不同论文/模型

|验收量|由哪些公式决定|必须对齐的比较条件|
|---|---|---|
|建幅时间|式(23)/(28)、启动策略与饱和|初始能量、能量容差、持续稳定窗口；不能用 \(E=0\) 的奇异极坐标启动|
|能量误差|\(E/E_{ref}-1\)|同一幅度/能量单位；实际能量与检测估计值分开|
|正交残差|\(Q/E\)、\(b/a\)|短轴符号、IQ符号一致；两指标非全范围线性等价|
|锁相误差|式(25)/(35)/(57)|机械相位与电子检测相位分开；统一rad/deg|
|全角误差|式(27)/(36)|物理角、模态角、Bryan标度、初始角与展开策略一致|
|角速度噪声|式(38)–(40)|同一带宽、采样率、窗、滤波器；差分噪声随带宽放大|
|零偏及死区|式(50)/(51)/(57)|地球投影/真实输入、平均时间和补偿开关一致|
|饱和裕量|式(31)/(59)及实际DAC/放大器|静态偏置、启动峰值、正交力、输出摆幅和恢复时间共同计入|

“加非理想后曲线还能跑”不是验收。推荐顺序为机械各向异性→C/V幅相→前端噪声/抗混叠→ADC采样/量化→数字解调/延迟→DAC/驱动→静电力/刚度→开关时序→辨识/补偿。每次只新增可追溯因素，用上表同一条件比较；最终再联合扫参，避免补偿器掩盖符号或模型错误。

## 11. 对当前工程的具体判断与边界

1. **理论基线**应采用式(11)/(19)及本文明确的物理角、IQ、短轴约定；载波与平均模型分别承担快速接口和慢闭环验证。
2. **核心文献可转换部分**为双模态线性机械、椭圆不变量、工作点附近 E/Q/相位/进动控制；完整转换包括力单位和解调增益，不能只除一个角度系数。
3. **需要增加结构才能复现的部分**包括 L058 原始载波 Kalman 解调、L061 双行波PLL、某些单通道复用、未知频率搜索、在线电调谐，以及特定 FRP/辨识协议。
4. **不能直接采用的局部印刷式**已在第7节列出并给出代入反例；这是对公式自洽性的审查，不推断作者实际硬件有同样错误。
5. 当前 V7 已有 PI/PIR、机械/接口分层模型和验收证据。旧比较稿中关于“PIR尚未实现”的描述属于历史状态，不能作为当前实现状态。本次未改动/重跑 Simulink；代数校验不等于硬件、全温或未知表头验收。

## 12. 可复查证据和复现

运行 `python verify_formulas.py --write`（依赖 numpy）会检查完整椭圆链式求导与复ODE、E/Q导数、IQ不变量、四个力分量、两种正弦解调、行波分解、相位串扰、辨识秩和配对条件等。随机检查使用固定种子；结果在 `evidence/algebra_checks.json`，仅属数学一致性证据。

`evidence/sources.json` 记录核心源文件哈希、页码和本次新增阅读范围；`corpus_mapping.md` 覆盖全部已登记条目并保持证据级别；`evidence/manifest.json` 固定本次新增交付的字节哈希。原文件、旧阅读证据、V7模型与历史接收哈希不在本次编辑范围内。

进一步查原文时，应先看式号所在页及前一页的变量定义，再看控制图、实现参考平面和实验输入。一个摘要能支持“研究了哪种方法”，不能支持“其所有系数已与本项目等价”。
