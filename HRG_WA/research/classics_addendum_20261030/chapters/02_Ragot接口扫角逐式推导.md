## 第二编第二章　Ragot：接口如何变成误差，新模式如何抵消误差

<a id="R18"></a>
### 原式(18)，PDF5：检测矩阵不只是一个标量增益

\[
\hat\eta=A\eta,\quad \eta=A^{-1}\hat\eta.
\]

一般 \(A=\begin{bmatrix}a_{11}&a_{12}\\a_{21}&a_{22}\end{bmatrix}\)：对角元描述各通道灵敏度，非对角元包含串扰和轴不正交。行列式太小意味着两个检测端口几乎看到同一模态，逆矩阵会放大噪声。共同标量增益不改方向，差分增益会改方向。这里先用实、常矩阵；后面复矩阵作用于窄带相量，不是直接把实位移乘复数当作物理位置。

<a id="R19"></a>
### 原式(19)，PDF5：实际驱动力与命令之间再隔一个矩阵

\[
f=B(-2m\hat a\omega_0u),\quad
u=[(C_rI+C_qJ)\cos\hat\phi+(C_aI+C_pJ)\sin\hat\phi]\hat v.
\]

检测先把真实轨道变成 \(\hat a,\hat v,\hat\phi\)，算法据此合成力，实际端口又经过 \(B\)。因此只校正ADC增益不足以保证闭环正确：控制器看到的是 \(A\)，驱动回机械的是 \(B\)，两者在不同位置。

<a id="R20"></a>
### 原式(20)，PDF5：一步一步进行坐标变换

常矩阵时 \(\dot{\hat\eta}=A\dot\eta,\ddot{\hat\eta}=A\ddot\eta\)。将式(14)左乘 \(A\)，再将 \(\eta,\dot\eta\) 换成 \(A^{-1}\hat\eta,A^{-1}\dot{\hat\eta}\)：

\[
\ddot{\hat\eta}+\omega_0^2\hat\eta
=AB(-2\hat a\omega_0u)-2AM_QA^{-1}\dot{\hat\eta}
-2\omega_0AM_{\Delta\omega}A^{-1}\hat\eta.
\]

控制力看见的是乘积 \(AB\)，机械矩阵看见的是相似变换 \(AMA^{-1}\)。若 \(A=A(t)\)，精确求导出现 \(2\dot A\dot\eta+\ddot A\eta\)；“温漂慢”只能说明快周期内可近似常数，不意味着长时漂移率对高精度输出一定可忽略。

<a id="R21"></a>
### 原式(21)，PDF5：检测增益为何能污染科氏项

\[
AM_QA^{-1}=\alpha\Omega AJA^{-1}+AGA^{-1}.
\]

取 \(A=\operatorname{diag}(g_x,g_y)\)，直接三矩阵相乘：

\[
AJA^{-1}=\begin{bmatrix}0&-g_x/g_y\\g_y/g_x&0\end{bmatrix}
=\frac{r+r^{-1}}2J+\frac{r^{-1}-r}2\begin{bmatrix}0&1\\1&0\end{bmatrix},\quad r=g_x/g_y.
\]

第二部分是对称矩阵；除非 \(|g_x|=|g_y|\)，它不再是纯反对称科氏结构。共同增益 \(g_x=g_y\) 会消掉；通道差分增益留下方向相关误差。这是应校正幅相矩阵的数学原因。

<a id="R22"></a>
### 原式(22)，PDF5：方向相关的等效标度因数

原文写 \(\alpha'(\theta)=\alpha+\Delta\alpha\cos2(\theta-\theta_\alpha)\)，是低阶谐波表示。用一个更直接、可独立验证的几何推导说明来源。令 \(z=Av,\hat\theta=\operatorname{atan2}(z_y,z_x)\)，则

\[
\frac{d\hat\theta}{d\theta}=\frac{z_xz_y'-z_yz_x'}{z_x^2+z_y^2}
=\frac{\det[A v,A w]}{\|Av\|^2}=\frac{\det A}{\|Av\|^2}.
\]

对 \(A=\operatorname{diag}(1,1+\epsilon)\)：分子 \(1+\epsilon\)，分母 \(1+2\epsilon\sin^2\theta+O(\epsilon^2)\)。用 \((1+x)^{-1}\simeq1-x\)：

\[
\frac{d\hat\theta}{d\theta}\simeq1+\epsilon\cos2\theta,
\quad \hat\theta-\theta\simeq\frac\epsilon2\sin2\theta.
\]

所以 \(\dot{\hat\theta}\simeq-\alpha\Omega[1+\epsilon\cos2\theta]\)，物理角误差为 \(\delta\beta\simeq\epsilon\sin4\beta/4\)。这是一个特定实增益例子，不是所有复矩阵误差的完整表达。它同时告诉我们角度误差是周期的；微分后会把角度相关项变成角速度相关项。

<a id="R23"></a>
### 原式(23)，PDF5：补偿矩阵的乘法顺序不能交换

原文的有效检测矩阵 \(A=A_cA_eA_d\)，有效驱动矩阵 \(B=B_dB_eB_c\)，目标均接近 \(I\)。假设台架已辨识 \(A_eA_d\)，则 \(A_c=(A_eA_d)^{-1}\)；已辨识 \(B_dB_e\)，则 \(B_c=(B_dB_e)^{-1}\)。将逆放错边通常不会抵消串扰。

若窄带相量采用 \(e^{i\omega t}\)，检测链相位延迟 \(\tau\) 对应 \(e^{-i\omega\tau}\)。\(e^{-i\delta}=\cos\delta-i\sin\delta\simeq1-i\delta\)，故本来纯同相的控制量出现大小约 \(\delta\) 的正交通道泄漏。采用相反相量约定时虚部符号也反转，工程必须用已知相位注入校准。

<a id="R24"></a>
### 原式(24)，PDF5：三个零偏来源及乘积关系

WA令 \(C_p=0\)，原文将有效方向率写为

\[
\dot\theta=-\alpha'\Omega+\Omega_b,\quad
\Omega_b=d\sin2(\theta-\theta_G)+\Delta\theta\,C_a+\Delta\phi\,C_q,
\]
\[
\Delta\theta=t_0+t_1\cos2(\theta-\theta_t),\qquad
\Delta\phi=p_0+p_1\cos2(\theta-\theta_p).
\]

第1项是真实阻尼各向异性；第2项是维持振幅的力漏入横向速度方向；第3项是正交力因相位误差漏入横向速度方向。\(\Delta\theta,\Delta\phi\) 是依原文定义的有效小误差，其正负最终由实际端口注入测定，不从文字“延迟”猜测。

Ragot样机数字复算：\(65\,\mathrm{deg/s}\times300\times10^{-6}\times3600=70.2\,\mathrm{deg/h}\)；\(85\times300\times10^{-6}\times3600=91.8\,\mathrm{deg/h}\)。原文约70、90合理。这里300ppm相位作为小角弧度系数使用；不是300微度。名义阻尼各向异性1.5°/s与老化引起300°/h漂移不是同一指标。

物理整机零偏要再除 \(\alpha\)：\(\hat\Omega=-\dot\theta/\alpha=\Omega-\Omega_b/\alpha\)。不能把电角率误差与整机角速度误差直接等同。

<a id="R25"></a>
### 原式(25)，PDF6：锁住驻波时输出是什么

令共同执行标度误差为 \(s=\Delta SF\)，用原文近似

\[
\dot\theta=-\alpha'\Omega+\frac{\Omega_b+C_p}{1+s}.
\]

FTR约束 \(\dot\theta=0\)，乘 \(1+s\)、再移项：\(C_p=(1+s)\alpha'\Omega-\Omega_b\)。因此根据 \(C_p\) 求 \(\Omega\) 时，执行增益进入标度因数。原文用 \(\|AB\|=I/(1+s)\) 表达归一化增益，严格矩阵范数应为标量；本书只把它解释为近各向同性部分 \(AB\simeq I/(1+s)\)，各向异性另外处理。

<a id="R26"></a>
### 原式(26)，PDF6：为何主动匀速扫角

若 \(b(\theta)\) 有角度零均值，时间均值仍为

\[
\frac1T\int b(\theta(t))dt=\frac1T\int\frac{b(\theta)}{\dot\theta(\theta)}d\theta.
\]

只有匀速、或采用正确角度权重时，才等于 \(\pi^{-1}\int_0^\pi b(\theta)d\theta\)。新模式命令 \(\theta=rt+\theta_0\)，\(r=\Omega_c\) 常数，一次正扫时长 \(T_c=\pi/r\)。反扫时正的时长为 \(\pi/|r|\)，不能把负 \(r\) 直接变成负时长。

反例：\(b=\sin2\theta,\dot\theta=r(1+\rho\sin2\theta),|\rho|<1\)。展开 \(1/\dot\theta\simeq(1-\rho\sin2\theta)/r\)。分子积分 \(\int b/\dot\theta\simeq-\rho\pi/(2r)\)，分母 \(T\simeq\pi/r\)，时间均值约 \(-\rho/2\)，并不为零。

<a id="R27"></a>
### 原式(27)，PDF6：必须减掉人为扫角命令

代 \(\dot\theta=r\) 入(25)，\(C_p=(1+s)(r+\alpha'\Omega)-\Omega_b\)。减 \(r\)：

\[
y=C_p-r=(1+s)\alpha'\Omega+sr-\Omega_b.
\]

这里 \(y\) 是命令归一化的电角率输出，原文用 \(\hat\Omega\) 记它；在迁移到本工程时，求整机输入仍需除 \((1+s)\alpha'\)，并校正偏置。否则人为扫描会被错误当作真实转动。

<a id="R28"></a>
### 原式(28)，PDF6：一圈平均剩下哪一项

在 \(s,\Omega,\alpha'\) 对该圈近似恒定、或先去掉其已知变化的条件下：

\[
\overline{y-(1+s)\alpha'\Omega}=sr-\frac1{T_c}\int\Omega_bdt
=sr-\frac1\pi\int_{\theta_0}^{\theta_0+\pi}\Omega_b(\theta)d\theta.
\]

方向相关的 \(\alpha'\) 也是谐波；完整圈匀速时其谐波可平均，但若 \(\Omega\) 在圈内变化，\(\alpha'(\theta)\Omega(t)\) 的乘积不保证零均值，需动态误差预算。

<a id="R29"></a>
### 原式(29)，PDF6：正反两圈如何抵消执行标度误差

设两圈相同 \(|r|\)、相同时长且 \(s\) 不变。正圈残差 \(e_+=sr-\bar b\)，反圈残差 \(e_-=-sr-\bar b\)。两者等时平均：

\[
e_{pair}=(e_++e_-)/2=-\bar b.
\]

反圈积分时 \(dt=d\theta/(-r)\)，角积分的方向与分母同时反号，所以阻尼误差的平均不会额外变号。若两圈增益变为 \(s_+,s_-\)，则额外残差为 \((s_+-s_-)r/2\)。若时长不等，还会留下 \(sr(T_+-T_-)/(T_++T_-)\)。换向加速度、驱动饱和和闭环滞后必须计入数据窗，不能把理想折线轨迹当作可直接施加的机械运动。

<a id="R30"></a>
### 原式(30)，PDF7：逐项积分，不能把两个零均值乘积也当作零

暂忽略角加速度修正，\(C_a=\gamma+d\cos2(\theta-\theta_G)\)，\(C_q=h\sin2(\theta-\theta_H)\)。先展开：

\[
\Delta\theta C_a=t_0\gamma+t_0d\cos2(\theta-\theta_G)
+t_1\gamma\cos2(\theta-\theta_t)
+t_1d\cos2(\theta-\theta_t)\cos2(\theta-\theta_G).
\]

中间两项积分为零。用 \(\cos A\cos B=[\cos(A-B)+\cos(A+B)]/2\)，末项平均为 \(t_1d\cos2(\theta_G-\theta_t)/2\)。再展开

\[
\Delta\phi C_q=p_0h\sin2(\theta-\theta_H)
+p_1h\cos2(\theta-\theta_p)\sin2(\theta-\theta_H).
\]

用 \(\cos A\sin B=[\sin(B+A)+\sin(B-A)]/2\)，第一部分为4倍角周期项，第二部分为常数 \(\sin2(\theta_p-\theta_H)/2\)。最终

\[
\bar\Omega_b=t_0\gamma+\frac{t_1d}{2}\cos2(\theta_G-\theta_t)
+\frac{p_1h}{2}\sin2(\theta_p-\theta_H).
\]

这就是原式(30)各积分的完整结果；原文末行再因 \(d\ll\gamma\) 略去中间项，但保留可能较大的 \(p_1h\)。若 \(C_q\) 因换向角加速度含非零均值或与误差相位相关的暂态，上述删项条件需要重新检查。

通俗解释：扫角像把一圈高低不平的路平均。但如果鞋底厚度也随位置变化，两种变化相乘可以留下平均高度，不能只看每个变化单独平均为零。

<a id="R31"></a>
### 原式(31)，PDF7：注入已知频率命令辨识执行标度

使用原文后半部分的操作符号 \(\widetilde C_r=-C_r^{(7)}\)，若两个控制通道具有相同有效增益，频率关系为
\(\delta\omega=\text{机械频率项}-\widetilde C_r/(1+s)\)。因此

\[
a_r=\frac{\partial\delta\omega}{\partial\widetilde C_r}=-\frac1{1+s},\quad
\frac{\partial C_p}{\partial\Omega}=(1+s)\alpha'.
\]

从测量斜率反解：\(a_r(1+s)=-1\Rightarrow s=-1/a_r-1\)。例如 \(s=0.02\)，斜率 \(-0.9803921569\)；斜率误差 \(\delta a\) 放大为 \(\delta s\simeq\delta a/a_r^2\)。并非只需“增加RLS”就自然正确，首先应证明注入量和观测量有独立可辨识响应。

具体测试：在安全幅度下给 \(\widetilde C_r=c_0+c_1\sin\nu t\)，同时记录实际注入、NCO频率、锁相误差、幅度和执行限幅；用复传函拟合相位与增益，或在每个平台等待稳定后拟合斜率。若PLL把 \(\delta\omega\) 定义为被压到零的鉴相误差，则不能把它当作实际共振频率变化，必须同时读取NCO跟踪量或去嵌入闭环。检测/驱动的幅相响应不同也会破坏“同一个 \(s\)”假设，需要分通道验证。

<a id="R35"></a>
### 原式(35)，PDF10：互易性约束与“17参数可观”的边界

所给PDF从(31)跳到(35)，没有(32)–(34)。原文在同一换能器顺序检测/驱动的条件下给

\[
B=\frac{A^T}{1+s}.
\]

这里是普通转置 \(T\)，不是复共轭转置 \(\dagger\)。一个解释互易性的机电端口模型是交叉能量项 \(-q^T\Theta V\)：对 \(q\) 求导给驱动力 \(F=\Theta V\)，对 \(V\) 求导给感应电荷项 \(Q_e=\Theta^Tq\)。这是同一双线性耦合产生的转置关系。实际还存在端口电容、驱动源阻抗、开关瞬态、检测负载和电子增益；只有先归一化并补偿这些链路，才可以把有效A/B约束为该形式。不能因“压电互易”就直接把ADC数字矩阵转置成DAC系数。

原文计数为4个复参数=8实参数，加1个共同增益误差，再加频率/阻尼/输入率相关的8实参数，总17。原文说明已知 \(\Omega\) 时用 \(\delta\omega,C_a,C_q,C_p\) 工厂标定；未知 \(\Omega\) 时用扫角及 \(C_r\) 调制、\(\delta\omega,C_a\) 估计其余参数，再从 \(C_p\) 求率。但没有提供完整估计器、原始数据、规范约束和数值Jacobian，不能据这一段宣称我们已经重现17参数在线辨识。

实际还应检查参数规范自由度。例如只观测式(20)时，\(A\to\lambda A,B\to B/\lambda\) 保持 \(AB\) 与相似变换不变；绝对位移标尺必须由独立校准或规范固定。若同时施加(35)，共同增益也需要相应约束。通用验证步骤是明确参数向量 \(p\)，生成观测 \(z(p,u)\)，计算 \(J_p=\partial z/\partial p\)，经量纲归一化后做SVD；报告秩、条件数、不可辨识组合及独立留出数据残差。计数17不等于秩17。

### 实验与实现：论文证明了什么

PDF7–10：样机采用压电换能器、数字滤波、复幅相补偿、40MHz FPGA、约2400Hz DSP和10Hz热模型；这是其实现速率，不是本表头的必需时钟。电极组合压低低阶寄生模态的作用，高频寄生模态用数字滤波，不能只在数学模型里放一对完美模态。

温度试验漂移RMS约48→13°/h，改善约3.69倍；标度误差正文约3200→360ppm，图5为3245→359ppm，图值比9.04倍。RMS是在所试温度轨迹上的统计量，不等于全温最大误差。Allan图FTR最低约0.1°/h在100s，新实现约0.02°/h在1000s，比较的是不同积分时间，不能写成同带宽噪声改善5倍。2秒扫角周期还引入短时调制，图中2秒整数倍附近的局部极小值不能当作普遍的白噪声标度。

论文所谓完整方案进一步改善短期噪声，提供了研究方向；尚无足够公开细节让本轮复现其全部实测曲线。我们的通过项是代数、理想扫角积分及合成算例，实物指标仍需压电半球表头验证。
