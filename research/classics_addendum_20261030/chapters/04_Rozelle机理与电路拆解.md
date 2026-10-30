## 第二编第四章　Rozelle：把工业原理叙述还原成可计算关系

本文没有编号方程。以下Z01–Z08为本书自编节点，每节先定位其原文论述，再补推数学；它们不是作者原式。历史时间线不强行编成方程，产品指标也不当作通用物理常数。

<a id="Z01"></a>
### Z01，PDF18–19／印刷16–17：四节点驻波、角度与角增益

二阶赤道径向位移可以写为

\[
u_r(\varphi,t)=a\cos[2(\varphi-\beta)]\cos\omega_0t
=a[\cos2\beta\cos2\varphi+\sin2\beta\sin2\varphi]\cos\omega_0t.
\]

与模态坐标比较：\(\eta_1=a\cos2\beta\cos\omega_0t\)，\(\eta_2=a\sin2\beta\cos\omega_0t\)，所以 \(\theta=2\beta\)。节点由 \(\cos2(\varphi-\beta)=0\) 得 \(\varphi=\beta+\pi/4+k\pi/2\)，共四处；波腹由 \(\varphi=\beta+k\pi/2\) 得四处。快相位变 \(\pi\) 使长短轴外形交换，但不是驻波真的瞬间转了90°；不能用单帧壳形识别整机转角。

理想慢方程 \(\dot\theta=-\alpha\Omega\)，积分 \(\theta(t)-\theta(0)=-\alpha[\Psi(t)-\Psi(0)]\)。除2：

\[
\Delta\beta=-B\Delta\Psi,\quad B=\alpha/2,\qquad
\widehat{\Delta\Psi}=-\operatorname{unwrap}(\Delta\beta)/B.
\]

原文“约0.3”是特定半球结构的物理角增益，且明确需要使用前标定（PDF19）。它不是我们的精确标定值，也不说明所有材料、边界、贴片、加工残差下均相同。若 \(B(T)=B_0[1+k_T(T-T_0)]\)，用固定 \(B_0\) 解算得到相对率误差约 \(k_T\Delta T\)。原文约0.5ppm/°C意味着20°C变化对应约10ppm量级，不能在未知压电结构上直接承诺该值。

通俗解释：表壳转了一个角，驻波在壳上向反方向滑过一小部分角。先用驻波的角度尺读数，再除经过标定的比例，才是陀螺整机转角。

<a id="Z02"></a>
### Z02，PDF19–20／印刷17–18：WA不是所有环路都断开

原文WA允许方向自由，同时维持幅度、抑制行波并跟踪频率。所谓open loop指方向测量通道，不等于取消幅度、正交与PLL闭环。FR则增加方向锁定，以方向控制命令推算输入率。两者对应

\[
\text{WA}: C_p=0,\quad \dot\theta=-\alpha\Omega+b(\theta),
\qquad
\text{FR}:\dot\theta=0,\quad C_p\simeq\alpha\Omega-b(\theta).
\]

波位读数误差 \(e_\theta(\theta)\) 与真实漂移 \(b(\theta)\) 不同：\(\hat\theta=\theta+e_\theta(\theta)\)，所以

\[
\dot{\hat\theta}=[1+e_\theta'(\theta)][-\alpha\Omega+b(\theta)].
\]

忽略小量乘积后，\(\hat\Omega=-\dot{\hat\theta}/\alpha\simeq\Omega+e_\theta'\Omega-b/\alpha\)。读数误差的导数形成标度调制，真实力误差形成偏置；只做一个“角度LUT”不能保证两者同时校正。

原文图23横轴明示electrical angle；其两周期曲线与模态2倍角误差相容。正文说360°回到原位置只是一个充分周期，不意味着最低周期一定是360°物理角。拟合应使用实际电极对称性及留出数据，不能仅凭这句叙述选择傅里叶阶数。

<a id="Z03"></a>
### Z03，PDF20–21／印刷18–19：WA与FR的限制分别来自哪里

FR最大方向命令 \(|C_p|\le C_{p,max}\)，所以近似输入范围 \(|\Omega|\le C_{p,max}/\alpha\)。压电驱动中若线性 \(F=\Theta_dV\)，方向力最大峰值 \(F_{max}=|\Theta_dH_d|V_{usable}\)，则

\[
\Omega_{max,FR}\simeq\frac{F_{max}}{2ma\omega_0\alpha}.
\]

需先扣除补能、正交、建幅和换向占用的电压裕量，再计算 \(V_{usable}\)。叠加正余弦分量在每个通道上峰值为 \(\sqrt{F_c^2+F_s^2}\)，多通道驱动还要逐路检查，不能只检查单个命令。

原文称WA“not limited in rate”意指不受FTR方向平衡力上限约束，不代表电子采样和解包无限量程。若相位无关角估计为 \(\beta=\tfrac14\arg(N+iM)\)，每次更新 \(\Delta\arg=4\Delta\beta\) 需小于 \(\pi\) 才能无先验最近邻解包；因此

\[
4B|\Omega|T_u<\pi\Rightarrow |\Omega|<\frac{\pi}{4BT_u}.
\]

这是相位无关四倍角算法的保守无歧义上限；若保留带符号相位信息或有可靠运动先验，可采用别的分支跟踪策略。实际范围还受低通带宽、延迟、短轴残差、PLL失锁、ADC饱和及平均法 \(\alpha\Omega\ll\omega_0\) 限制。WA不能凭物理原理一句话宣布任意角速度都可测。

<a id="Z04"></a>
### Z04，PDF21–22／印刷19–20：I/Q四变量怎样构造幅度和角度

定义检测载波 \(x=I_x\cos\omega t+Q_x\sin\omega t\)，\(y=I_y\cos\omega t+Q_y\sin\omega t\)。同步乘2倍参考并低通，因为 \(2\cos^2=1+\cos2\omega t\)、\(2\sin\cos=\sin2\omega t\)，得到对应I、Q。这里正弦约定与V10相量约定必须明确映射。

构造相位无关实矩阵

\[
S=\begin{bmatrix}I_x^2+Q_x^2&I_xI_y+Q_xQ_y\\I_xI_y+Q_xQ_y&I_y^2+Q_y^2\end{bmatrix}
=a^2vv^T+b^2ww^T.
\]

所以 \(E_n=\operatorname{tr}S=a^2+b^2\)，\(N=S_{xx}-S_{yy}=(a^2-b^2)\cos2\theta\)，\(M=2S_{xy}=(a^2-b^2)\sin2\theta\)，\(D=\sqrt{N^2+M^2}=a^2-b^2\)。于是

\[
a^2=(E_n+D)/2,\quad b^2=(E_n-D)/2,\quad
\theta=\tfrac12\operatorname{atan2}(M,N),\quad\beta=\tfrac14\operatorname{atan2}(M,N).
\]

短轴符号还需 \(L_d=I_xQ_y-I_yQ_x=ab\)，不能只取平方根。角噪声一阶传播：

\[
\delta\beta=\frac{N\delta M-M\delta N}{4(N^2+M^2)}.
\]

圆轨道D→0时角噪声发散，与Ragot式(5)的奇异分母指向同一个物理原因。纯驻波、同步相位已对齐、检测白噪声各轴等方差 \(\sigma_n^2\) 时，直接 \(\theta=\operatorname{atan2}(I_y,I_x)\) 给 \(\delta\theta=(-\sin\theta n_x+\cos\theta n_y)/a\)，故 \(\sigma_\beta=\sigma_n/(2a)\)。若再换算整机角 \(\Psi=-\beta/B\)，\(\sigma_\Psi=\sigma_n/(2Ba)\)。实际低通带宽和I/Q相关性须进入协方差，不能总套独立等方差。

<a id="Z05"></a>
### Z05，PDF21–22：2倍频参数激励和DC调刚为何不能照搬压电头

Rozelle介绍的静电结构把补能放在2倍频，把正交修正通过DC改变刚度。先从电容端口能量推导（电压由理想源保持时取力的标准形式）：\(F_e=\tfrac12V^2\partial C/\partial x\)。若 \(V=V_b+v\cos\omega t\)，则

\[
V^2=V_b^2+2V_bv\cos\omega t+\frac{v^2}{2}[1+\cos2\omega t].
\]

静电力可有DC、基频、2倍频分量，且 \(\partial F_e/\partial x\) 改变有效刚度。若直接调制刚度 \(k(t)=k_0+\delta k\cos(2\omega t+\psi)\)，对 \(x=a\cos\omega t\)，调制力 \(F_p=-\delta k\cos(2\omega t+\psi)a\cos\omega t\)。乘速度 \(-a\omega\sin\omega t\)，周期平均：

\[
\langle F_p\dot x\rangle=\delta ka^2\omega\langle\cos(2\omega t+\psi)\cos\omega t\sin\omega t\rangle
=-\delta ka^2\omega\sin\psi/4.
\]

由于 \(E=ma^2\omega^2/2\)，参数激励带来的幅度增长率为 \(-\delta k\sin\psi/(4m\omega)\)。抵消阻尼需要 \(|\delta k\sin\psi|/(4m\omega)\ge\gamma\)。这里“2倍频”是刚度泵浦的频率，不是控制环更新带宽。

线性压电直接驱动则 \(F_p=\Theta_dV_d\)。若只给2倍频电压，力也只在2倍频，在理想线性系统中不会因此在 \(\omega\) 共振处提供同样的平均补能。要做压电参数激励，需要另证明电压调刚、几何非线性或相应耦合项。当前V10应先采用已建模的基频直接驱动，不能因这篇有2倍频就切换驱动方法。DC压电电压可产生静态应变，但未必等价于可控、稳定、足量的两模态调刚。

<a id="Z06"></a>
### Z06，PDF15–16／印刷13–14：热设计与频率测温的计算

原文给频率温度系数约84ppm/°C与0.1°C控温。若 \(f(T)=f_r[1+k_f(T-T_r)]\)，则 \(\Delta T=(f-f_r)/(k_ff_r)\)。取**演示** \(f_r=7500Hz\)、\(k_f=84\times10^{-6}/°C\)，斜率0.63Hz/°C，0.1°C对应0.063Hz、8.4ppm。若测量噪声标准差为0.01Hz且其他量已知，温度估计噪声约0.01587°C。

实际频率还会受驱动幅度、端口负载、贴片应力、老化和频率控制注入影响：\(\delta f=k_ff_r\delta T+k_a\delta a+k_V\delta V+\delta f_{age}\)。只测一个f无法无条件区分这些来源。因此扫频辨识与频率控温不能互相当真值；应有独立温度探头及非注入时段交叉验证。

热耗散系数40mW/°C意味着 \(G_{th}=0.04W/K\)，\(R_{th}=25K/W\)。稳态高于环境100K时每只约4W，三只约12W，符合正文给出的量级。动态还需热容 \(C_{th}\)：\(C_{th}\dot T=P-G_{th}(T-T_a)\)，时间常数 \(\tau_{th}=R_{th}C_{th}\)；文章不给我们的 \(C_{th}\)，不能由稳态功率推断热环带宽。

原文提双真空腔“泄漏率相乘”并以 \(10^{-8}\times10^{-8}=10^{-16}\) 类比。若泄漏率具有体积/时间单位，直接乘积量纲不对。双腔应写压强状态：\(V_o\dot p_o=C_o(p_a-p_o)-C_i(p_o-p_i)\)，\(V_i\dot p_i=C_i(p_o-p_i)\)，再加入getter抽速等；效果取决于容积、导通和时间。其隔离思想可借鉴，不能照抄乘法为寿命定量公式。

<a id="Z07"></a>
### Z07，PDF16／表5：数字接口、PWM与噪声指标

表5同为±12°/s范围，角白噪声0.014→0.001arcsec/√Hz为14倍；ARW0.00060→0.00006°/√h为10倍；偏置0.0050→0.0005°/h为10倍；标度稳定性和线性度100→1ppm为100倍。表2、表3的不同系统/试验另列，不能把Hubble实验的最佳值和SSIRU量程拼成一个不存在的产品指标。

原文说PWM相对传统梯形DAC改善稳定性，直接采样/数字解调降低延迟至1ms以内。这是该系统对比，不是PWM天然比任何DAC好100倍。单边沿PWM若平均电压 \(\bar V=V_HD\)，占空比 \(D=t_{on}/T_p\)，则 \(\delta\bar V=V_H\delta t/T_p\)；实际还受电平、边沿、死区、滤波纹波、时钟抖动与压电负载影响。压电负载近似电容时，\(i=C_p\,dV/dt\)，开关尖峰与馈通更需要实测。

对采样正弦 \(v=A\cos\omega t\)，时间抖动小量 \(\delta t\) 给 \(\delta v\simeq-A\omega\sin\omega t\delta t\)。若独立且均方为 \(\sigma_t^2\)，噪声RMS \(A\omega\sigma_t/\sqrt2\)，信号RMS \(A/\sqrt2\)，所以 \(SNR_j=-20\log_{10}(\omega\sigma_t)\)。这适用于随机孔径抖动；两通道固定时差产生确定性相位差 \(\omega\Delta t\)，应作为Ragot \(\Delta\phi C_q\) 型泄漏处理，不能混成同一个白噪声项。

ARW需定义时间单位。例如独立角速度样本 \(n_k\) 方差 \(\sigma_\Omega^2\)，间隔 \(T_s\) 秒，积分角 \(\sum n_kT_s\) 的方差为 \(\sigma_\Omega^2T_s t\)，故以秒计的随机游走系数 \(N_s=\sigma_\Omega\sqrt{T_s}\,[deg/\sqrt s]\)，换为 \(deg/\sqrt h\) 需乘60。滤波后相邻样本相关，改用自协方差求和或规定PSD单双边约定。角白噪声与积分率白噪声不是同一个量，不能用一个常数直接互换。

<a id="Z08"></a>
### Z08，全篇：历史、模式选择与外部证据

PDF3–17叙述材料、支撑、加工、电极、电子学、封装与冗余的累积改进；30mm系统达到甚至超过早期58mm系统，文中解释早期系统受电子学限制。这提醒我们不能只按直径缩放指标，必须测清当前瓶颈。

PDF22–26的NEAR、Cassini、MESSENGER、Deep Impact为当时任务案例，支持技术应用历史，不提供我们的压电模型参数。作者提星敏更新噪声大于陀螺，说明外部参考也有误差；比较应报告双方带宽、时间同步、独立性，而不是把参考设备读数一律当真值。12百万在轨陀螺小时和100%任务成功是该文截至当时的统计，不等于任何样机永不失效；文末“不受quantum limit”是展望性表述，不能否定热噪声、测量噪声和估计下界。

原文还存在历史文字内部不协调，例如PDF13在1996首发附近写“early1966”，PDF8对1982采访与1991报道的叙述不能直接当精确时间线。本书不靠这些日期推导物理，也不擅自改为另一个未经核实的出版年。参考文献页给Lynch发展史的原始线索，但未取得该原文就仍不声称已通读。

三篇的共同结论是：WA的理想几何标度优势需要优质机械、准确读出和低泄漏控制共同兑现；FR的噪声和定点标定优势伴随执行增益进入率标度；主动扫角能抑制部分方向相关漂移，但增加调制、换向和辨识负担。模式选择必须由目标任务和实测瓶颈决定。
