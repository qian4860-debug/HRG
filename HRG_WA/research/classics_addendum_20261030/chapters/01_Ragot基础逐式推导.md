## 第二编第一章　Ragot：从实振动逐步得到四个控制通道

### 先固定基底，否则无法审查正负号

用 \(I\) 为单位矩阵，\(J=\begin{bmatrix}0&-1\\1&0\end{bmatrix}\)，\(v=(\cos\theta,\sin\theta)^T\)，\(w=Jv=(-\sin\theta,\cos\theta)^T\)。逐项验证：

\[
J^2=-I,\quad v^Tv=w^Tw=1,\quad v^Tw=0,\quad
\dot v=\dot\theta w,\quad\dot w=-\dot\theta v,\quad v^TJ=-w^T.
\]

后面每个投影均用这六条关系，不另换 \(J\) 的方向。\(b\) 是有符号短轴；\(a>0,|b|<a\)。物理圆轨道 \(|b|=a\) 没有唯一主轴，任何求角算法都不能绕过此奇异性。

<a id="R01"></a>
### 原式(1)，PDF1：模态方程与自然频率

把实际壳体位移写成 \(u(r,t)=M_1(r)\eta_1(t)+M_2(r)\eta_2(t)\)，只保留一对近简并模态。理想、无损、等质量等刚度时，两条独立牛顿方程均为 \(m\ddot\eta_i+k\eta_i=0\)。两边除 \(m\)：

\[
\ddot\eta+\omega_0^2\eta=0,\quad \omega_0^2=k/m,\quad\omega_0=\sqrt{k/m}.
\]

模态质量依赖 \(M_i\) 的归一化。如果把模态形状放大 \(s\)，坐标缩小 \(s\)，质量与端口耦合也必须随之换算，不能从一个未知振幅单位单独反推绝对质量。

<a id="R02"></a>
### 原式(2)，PDF1：为什么是椭圆而不是两条无关正弦

同频的两通道正弦可写为 \(P\cos\phi+Q\sin\phi\)。选择主轴和快相位后，得到

\[
\eta=a v\cos\phi+bw\sin\phi,\quad \phi=\omega_0t+\phi_0.
\]

在旋转主轴系中，\(v^T\eta=a\cos\phi,w^T\eta=b\sin\phi\)，所以 \((v^T\eta/a)^2+(w^T\eta/b)^2=1\)。\(b=0\) 时成为线段，即纯驻波。\(\theta\to\theta+\pi\) 同时 \(\phi\to\phi+\pi\) 不改变 \(\eta\)，故以 \(\pi\) 为模态主轴周期。半球二阶模态再除2才得到物理波腹方向。

<a id="R03"></a>
### 原式(3)，PDF2：把控制力分到两种时间基底

\[
f=f_c\cos\phi+f_s\sin\phi,\qquad \ddot\eta+\omega_0^2\eta=f/m.
\]

\(f_c,f_s\) 各为二维慢变力矢量，不是单个标量。四个自由数正好允许分别作用于频率、幅度、短轴、方向。力单位为N，除 \(m\) 才是加速度；后文控制命令的rad/s是另一次归一化。

<a id="R04"></a>
### 原式(4)，PDF2：慢变量究竟怎样求两次导数

令 \(p=av,q=bw\)，\(\dot\phi=\omega_0+\delta\omega\)。先一次求导：

\[
\dot\eta=(\dot p+\dot\phi q)\cos\phi+(\dot q-\dot\phi p)\sin\phi.
\]

再逐括号求导，尚不删项：

\[
\ddot\eta=(\ddot p+\ddot\phi q+2\dot\phi\dot q-\dot\phi^2p)\cos\phi
+(\ddot q-\ddot\phi p-2\dot\phi\dot p-\dot\phi^2q)\sin\phi.
\]

一阶平均近似要求 \(|\dot a/a|,|\dot b/a|,|\dot\theta|,|\delta\omega|\ll\omega_0\)，慢量二阶导和慢率乘积小。用 \(\dot\phi^2-\omega_0^2=2\omega_0\delta\omega+(\delta\omega)^2\)，删最后平方；用 \(\dot p=\dot a v+a\dot\theta w\)、\(\dot q=\dot b w-b\dot\theta v\)。于是残差的两个系数为

\[
r_c=-2\omega_0(a\delta\omega+b\dot\theta)v+2\omega_0\dot b\,w,
\]
\[
r_s=-2\omega_0\dot a\,v-2\omega_0(b\delta\omega+a\dot\theta)w.
\]

这是核心中间结果；下面所有控制方向均可从它重算。通俗解释：快振动负责每秒来回几千次，慢变量描述“来回运动的线段”怎样变长、变椭圆、转向和改变节奏。

<a id="R05"></a>
### 原式(5)，PDF2：四次投影与二元消元

由 \(r_c=f_c/m,r_s=f_s/m\)，分别投影：

\[
\dot a=-\frac{v^Tf_s}{2m\omega_0},\quad
\dot b=\frac{w^Tf_c}{2m\omega_0}=-\frac{v^TJf_c}{2m\omega_0},
\]
\[
a\delta\omega+b\dot\theta=-\frac{v^Tf_c}{2m\omega_0},\quad
b\delta\omega+a\dot\theta=\frac{v^TJf_s}{2m\omega_0}.
\]

系数矩阵 \(T=\begin{bmatrix}a&b\\b&a\end{bmatrix}\)，行列式 \(a^2-b^2\)，伴随矩阵 \(\begin{bmatrix}a&-b\\-b&a\end{bmatrix}\)。因此

\[
\begin{bmatrix}\delta\omega\\\dot\theta\end{bmatrix}
=\frac1{2m\omega_0(a^2-b^2)}
\begin{bmatrix}a&-b\\-b&a\end{bmatrix}
\begin{bmatrix}-v^Tf_c\\v^TJf_s\end{bmatrix}.
\]

原图放大核对后，下行确为 **正的** \(v^TJf_s\)，不是OCR可能误读的负号；式(5)与此一致。分母趋零时不是数值精度问题，而是圆的长轴方向失去定义。

<a id="R06"></a>
### 原式(6)，PDF2：只在短轴被压到零后解耦

代 \(b=0\)，定义 \(K_r=1/(2ma\omega_0)\)，得到

\[
\delta\omega=-K_rv^Tf_c,\quad\dot a/a=-K_rv^Tf_s,
\quad\dot b/a=-K_rv^TJf_c,\quad\dot\theta=K_rv^TJf_s.
\]

若 \(b\) 残差较大，必须回到式(5)，不能继续使用四个互不耦合积分器。用 \(|b/a|\)、\(a^2-b^2\) 设置解角有效标志，正是工程中的正交残差验收。

<a id="R07"></a>
### 原式(7)，PDF3：由命令合成物理力

记 \(S=2ma\omega_0\)。原文定义

\[
f=-S[(C_rv+C_qw)\cos\phi+(C_av+C_pw)\sin\phi].
\]

故 \(f_c=-S(C_rv+C_qw),f_s=-S(C_av+C_pw)\)。例如 \(v^TJf_s=-S[C_av^TJv+C_pv^TJw]=-S[0-C_p]=SC_p\)。这一行明确决定方向命令的符号。

<a id="R08"></a>
### 原式(8)，PDF3：一个必须标出的符号不一致

将上述两力代入原式(6)，四项分别为

\[
\delta\omega=C_r,\quad \dot a/a=C_a,\quad \dot b/a=-C_q,\quad\dot\theta=+C_p.
\]

印刷式(8)前三项相同，但最后写 \(\dot\theta=-C_p\)。这与同页式(7)、前页式(6)在同一 \(J\) 定义下不自洽；后面的式(17)、(25)、(27)又使用正的 \(C_p\)。本书后续使用从力定义直接得到的 \(+C_p\)，不把印刷负号写进控制器。最小反例：\(v=(1,0),m=a=\omega_0=1,C_p=1\)，则 \(f_s=(0,-2)\)，式(6)给 \(\dot\theta=1\)。

<a id="R09"></a>
### 原式(9)，PDF3：四个力通道的物理解释表

同方向、同位移相位的力改变恢复刚度，因此改变频率；同方向、同速度相位的力改变平均做功，因此改变振幅；横向、同位移相位的力产生椭圆短轴；横向、同速度相位的力转动主轴。这是编号表，不是额外一条微分方程。

平均功率也能独立检查：\(\dot\eta\simeq-a\omega_0v\sin\phi\)，故 \(\langle f^T\dot\eta\rangle=ma^2\omega_0^2C_a\)，而 \(E=ma^2\omega_0^2/2\)，所以 \(\dot E=2EC_a\Rightarrow\dot a/a=C_a\)。这与纯代数投影得到同一结论。

<a id="R10"></a>
### 原式(10)，PDF3：质量、阻尼、刚度与旋转同时存在

定义三个对称无迹缺陷矩阵 \(D_j=\begin{bmatrix}\Delta_{jc}&\Delta_{js}\\\Delta_{js}&-\Delta_{jc}\end{bmatrix}\)，\(j=m,c,k\)。原文为

\[
m(I+D_m)\ddot\eta+c(I+D_c)\dot\eta+k(I+D_k)\eta
+2m\alpha\Omega J\dot\eta+m\alpha\dot\Omega J\eta=f.
\]

质量、耗散、储能分别决定三个对称矩阵；陀螺项为反对称矩阵，\(\dot\eta^TJ\dot\eta=0\)，所以科氏项本身不做功。这里忽略 \(\Omega^2\) 的频率效应，不是任何高速输入下都精确。

<a id="R11"></a>
### 原式(11)，PDF3：先精确移项，再声明近似

除 \(m\)，用 \(c/m=\omega_0/Q, k/m=\omega_0^2\)，将各缺陷移到右侧：

\[
\ddot\eta+\omega_0^2\eta=f/m-2\alpha\Omega J\dot\eta-\alpha\dot\Omega J\eta
-D_m\ddot\eta-\frac{\omega_0}{Q}(I+D_c)\dot\eta-\omega_0^2D_k\eta.
\]

此步尚有 \(D_m\ddot\eta\)，不能把它直接删除。\(Q\) 对应振幅衰减率 \(\gamma=\omega_0/(2Q)\)，速度系数为 \(2\gamma\)。

<a id="R12"></a>
### 原式(12)，PDF4：质量缺陷中使用零阶运动

一阶微扰中，\(\ddot\eta=-\omega_0^2\eta+O(\epsilon\omega_0^2\eta)\)。故
\(-D_m\ddot\eta=+\omega_0^2D_m\eta+O(\epsilon^2\omega_0^2\eta)\)。只在已经乘小量的项中这样代入，不能把左边真实加速度也改成零阶值。

<a id="R13"></a>
### 原式(13)，PDF4：为什么只看到刚度减质量

\[
-\omega_0^2D_k\eta+\omega_0^2D_m\eta=-\omega_0^2(D_k-D_m)\eta.
\]

令 \(u=\Delta_{kc}-\Delta_{mc},z=\Delta_{ks}-\Delta_{ms}\)，则频率缺陷为 \(\begin{bmatrix}u&z\\z&-u\end{bmatrix}\)。给 \(D_k,D_m\) 同时加同一个小矩阵，不改变这一阶窄带观测；所以仅用共振附近的I/Q不能唯一拆开质量缺陷与刚度缺陷。

<a id="R14"></a>
### 原式(14)，PDF4：把所有误差写成率量

\[
\ddot\eta+\omega_0^2\eta=f/m-2M_Q\dot\eta-2\omega_0M_{\Delta\omega}\eta,
\]
\[
M_Q=\alpha\Omega J+G,\quad G=\gamma(I+D_c),\quad
M_{\Delta\omega}=\frac{\alpha\dot\Omega}{2\omega_0}J+H,\quad
H=\frac{\omega_0}{2}\begin{bmatrix}u&z\\z&-u\end{bmatrix}.
\]

逐项乘回：\(-2\omega_0(\alpha\dot\Omega/(2\omega_0))J\eta=-\alpha\dot\Omega J\eta\)，\(-2\omega_0H\eta=-\omega_0^2(D_k-D_m)\eta\)。\(G,H\) 的单位均为s⁻¹，便于直接与命令相比。

<a id="R15"></a>
### 原式(15)，PDF4：幅度固定、短轴为零时再求导

取 \(\eta=av\cos\phi,a\) 常数：

\[
\dot\eta=a\dot\theta w\cos\phi-a(\omega_0+\delta\omega)v\sin\phi,
\]
\[
\ddot\eta=a[\ddot\theta w-\dot\theta^2v-(\omega_0+\delta\omega)^2v]\cos\phi
-a[2(\omega_0+\delta\omega)\dot\theta w+\dot{\delta\omega}v]\sin\phi.
\]

若只保留一阶慢率，应删 \(\ddot\theta/\omega_0\) 等二阶项。原文额外保留角加速度修正而略去某些其他高阶项；下面用与其相同的准静态近似（\(\dot{\delta\omega}\simeq0\)、\(G\dot\theta\) 等乘积忽略），单独写出保留的 \(\ddot\theta\)，并不把它称为一致的完整二阶平均模型。

<a id="R16"></a>
### 原式(16)，PDF4：四个投影全部展开，并审查印刷符号

把式(15)代入式(14)，再用式(7)。余弦平行项给
\(-2a\omega_0\delta\omega=-2a\omega_0 C_r-2a\omega_0v^THv\)，故

\[
\delta\omega=C_r+v^THv=C_r+\frac{\omega_0}{2}(u\cos2\theta+z\sin2\theta).
\]

余弦横向项给 \(a\ddot\theta=-2a\omega_0C_q-\alpha a\dot\Omega-2a\omega_0w^THv\)，故

\[
C_q=-w^THv-\frac{\alpha\dot\Omega+\ddot\theta}{2\omega_0}
=\frac{\omega_0}{2}(u\sin2\theta-z\cos2\theta)-\frac{\alpha\dot\Omega+\ddot\theta}{2\omega_0}.
\]

正弦平行项给 \(0=-2a\omega_0C_a+2a\omega_0v^TGv\)，故

\[
C_a=v^TGv=\gamma[1+\Delta_{cc}\cos2\theta+\Delta_{cs}\sin2\theta].
\]

正弦横向项给 \(-2a\omega_0\dot\theta=-2a\omega_0C_p+2a\omega_0w^TM_Qv\)，故

\[
\dot\theta=C_p-w^TM_Qv=C_p-\alpha\Omega
+\gamma(\Delta_{cc}\sin2\theta-\Delta_{cs}\cos2\theta).
\]

最后一项用直接相乘核对：\(w^TD_cv=-\Delta_{cc}\sin2\theta+\Delta_{cs}\cos2\theta\)。原文印刷(16)对 \(C_r\)、频差引起的 \(C_q\)、阻尼引起的方向率的符号与上述基础式不一致；原文(17)的后两种谐波形式又与这里相符。故不能把(16)原样用于模型。

三个独立反例：理想振子仅 \(C_r>0\) 时控制力是额外恢复力，\(\omega_{new}^2=\omega_0^2+2\omega_0C_r\)，应频率升高；\(u>0,z=0,\theta=\pi/4\) 时需要正 \(C_q=\omega_0u/2\)；阻尼X大于Y、\(\theta=\pi/4\) 时X分量衰减快，方向应向Y转，即正方向率。这些反例均进入独立检查。

<a id="R17"></a>
### 原式(17)，PDF4：合并正余弦时为什么必须有半角

令 \(h=\sqrt{u^2+z^2},\chi=\operatorname{atan2}(z,u)\)，则 \(u=h\cos\chi,z=h\sin\chi\)。代入：

\[
u\cos2\theta+z\sin2\theta=h\cos(2\theta-\chi).
\]

因此 \(\theta_H=\chi/2\)，而不是 \(\chi\)。同理 \(\theta_G=\tfrac12\operatorname{atan2}(\Delta_{cs},\Delta_{cc})\)。定义 \(\Delta\omega=\omega_0h/2\)，\(d=\gamma\sqrt{\Delta_{cc}^2+\Delta_{cs}^2}\)，得到一致形式

\[
\delta\omega=C_r+\Delta\omega\cos2(\theta-\theta_H),\quad
C_a=\gamma+d\cos2(\theta-\theta_G),
\]
\[
C_q=\Delta\omega\sin2(\theta-\theta_H)-\frac{\alpha\dot\Omega+\ddot\theta}{2\omega_0},\quad
\dot\theta=C_p-\alpha\Omega+d\sin2(\theta-\theta_G).
\]

印刷(17)的轴角定义没有这个1/2，且用单参数arctan丢象限；频率行仍是 \(-C_r\)。使用该行及后文(31)时可另定义 \(\widetilde C_r=-C_r^{(7)}\)，但这一个改名不能同时消除(8)、(16)的其他不一致。

\(H\) 的特征值为 \(\pm\Delta\omega\)。机械两主频近似 \(\omega_0\pm\Delta\omega\)，所以**完整角频差**为 \(2\Delta\omega\)，完整Hz频差为 \(\delta f=\Delta\omega/\pi\)。本书称 \(\Delta\omega\) 为半频差率，不能与Lynch使用的完整分裂量无条件同名替换。阻尼矩阵两衰减率为 \(\gamma\pm d\)，完整衰减率差为 \(2d\)。

通俗解释：矩阵的轴方向转一圈，表格里的正余弦转两圈，所以从正余弦系数反求轴方向时必须除2。频差也要先问“两个频率相差多少”，还是“每个频率偏离中心多少”。
