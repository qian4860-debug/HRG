# 新增Zotero原文的建模方法对照与阅读范围

17份原PDF已提取全文；下列页码为实际阅读的相关章节，不能将其扩展为所有页面和全部公式已审计。页码含作者稿封面。来源路径、SHA与视觉核验页见`../evidence/source_reading.json`。

已有中文四篇、库中其他专题条目及恢复网络记录仍见[原推导方法总表](../../layered/docs/literature_method_matrix.md)与[逐式对照](../../layered/docs/literature_derivation_comparison.md)。它们的阅读级别不因本轮导入而自动升级。

Zotero新集合的[133条题录覆盖表](../../../research/zotero_integration_20261024/hrg_bibliographic_coverage.md)补足检索入口；其中只具题录证据的记录不能凭标题推断公式。完整个人库其余领域索引留在本地技能，不把SAR ADC等文献充当全角机械推导来源。

|附件ID/题名|已读PDF页|方法及推导链|本工程的相同点、差异和移植边界|
|---|---|---|---|
|2F6FA5W9：Zhao 等 - 2021 - The control algorithm of whole angle mode for HRG based on the vector composition|3,4,5,6,7,8|向量合成控制：二模态动力学→半幅解调→E/Q/R/S/L→能量、正交、PLL→16电极分配|与当前三环骨架一致；原文φ0是模态平面方位，物理圆周角再除2。三相空间矢量背景不自动成为16电极的实际电压实现；式(5)的排印须按正余弦定义重建。|
|33LLJK89：Sun 等 - 2024 - Identification and Compensation Method of Unbalanced Error in Driving Chain for Rate-Integrating Hem|5,6,7,10,11|驱动链矩阵误差：倾斜/偏心改变间隙和电极投影；电阻改变交流增益/相位；辨识后作执行端补偿|支撑冻结执行矩阵校准；不能用检测矩阵逆替代驱动逆，也未覆盖所有温漂/非线性。|
|3JGQXTFY：Hu和Gallacher - 2019 - Effects of nonlinearity on the angular drift error of an electrostatic MEMS rate integrating gyrosco|1,2,3,4,5,6,7,8,9,10|非线性反馈平均法：电容非线性→基频增益与高阶项→反馈产生等效非线性阻尼→进动漂移|三次扣除不是精确逆；已对本作者稿式(17)作代数反例。作者稿不能默认为正式版逐字相同。|
|3WWC87NP：Yan 等 - 2026 - Influence Mechanism of Quantization Error on the Key Parameters of the Whole-Angle Hemisphere Resona|3,4,5,6,7,8,9,10,11,12,13,14,15,16|量化误差传播：量化误差电压→IQ误差→不变量与角度Jacobian→字长/幅度/方位仿真|必须保留解调K与单位，修正展开反例；一般Jacobian不证明误差一定只有4θ。|
|DEA2DW82：Prikhodko 等 - 2012 - Foucault pendulum on a chip Rate integrating silicon MEMS gyroscope|2,3|自由振动全角验证：含转动项的二维振子→轨道椭圆与主轴角→平均法非理想漂移|硅QMG模态角与HRG圆周角不同；其高Q自由衰减实验不是本机能量/正交三环全温验证。|
|ETBPGUEC：Senkal 等 - 2014 - Achieving Sub-Hz Frequency Symmetry in Micro-Glassblown Wineglass Resonators|3,4,5|结构对称性与制造：厚度Fourier→2n阶缺陷与频裂缩放→玻璃吹制压力稳定性→实测频裂|提供结构误差来源，不是完整电子闭环；sub-Hz不能按相同绝对容差推为mHz。|
|HJ8QJI38：Liu 等 - 2025 - An Angle-Dependent Bias Compensation Method for Hemispherical Resonator Gyro Inertial Navigation Sys|2,3,4,5,6,8,9|INS系统温漂标定：4θ系数的频率二次函数→IMU/导航误差方程→48状态Kalman→19位置可观测性|状态观测使用速度/位置误差和设计路径；单个未知运动表头的IQ不能自动观测48个状态。圆环角增益不能通用于半球。|
|JB87VLBY：Wu 等 - 2026 - Localized thermal tuning in fused silica inductive vibrating ring gyroscopes|1,2,3,4,5,6|局部热机耦合调谐：局部温度场→E(χ)→模态加权应变能→双模态频率与热耦合系数|电感圆环用Lorentz力，不具备本电容接口的静电调谐；一般热源方位还需保留刚度交叉项和热时间常数。|
|L6NHMEWD：Prikhodko 等 - 2013 - What is MEMS gyrocompassing Comparative analysis of maytagging and carouseling|2,3,4|物理转位寻北：地球角速率水平投影→180度差分或转台调制→零偏与方位误差|物理转动输入轴与虚拟驻波进动不同；后者不能替代外部方位参考或重力投影。|
|QCCBYZZ5：Ning 等 - 2025 - Identification and correction of phase delay errors for hemispherical resonator gyroscopes|6,7,8|相位延迟注入辨识：正交控制力相位泄漏→正交残差周期注入→正余弦响应辨识→相位校正|需保留频裂同频项、未知转动和相位条件；共相位假设不覆盖两轴延迟不等。|
|RDFG3T5L：Zhao 等 - 2020 - The Energy Compensation of the HRG Based on the Double-Frequency Parametric Excitation of the Discre|3,4,5,6,7,8|双频参激励：离散电极电容→电压平方交叉项→2ω刚度调制→平均矩阵与起振阈值|与当前基频推挽力不同；原文阈值按八个同电容电极推导，不能只改变NCO频率移植。|
|UYU9ZQYT：Zhao 等 - 2021 - High sensitivity rate-integrating hemispherical resonator gyroscope with dead area compensation for|2,3,4,5,6,7|阻尼死区及虚拟进动：阻尼各向异性→方位锁定阈值→虚拟科氏力→输出扣除已知虚拟角|物理/模态角、1/τ及B约定需映射；印刷式(8)不满足等参刚度极限，已作视觉与代数检查。|
|VGZ48WAL：Wang 等 - 2025 - A Novel Closed-Loop Single-Channel Time Division Multiplexing Detection Circuit for Hemispherical Re|3,4,5,6,7,8,9|闭环单通道TDM接口：模拟误差闭环→跟踪DAC量→前向ADC公共路径抑制→时分采样与反馈路径共享|有限L有1/(1+L)残差；切换负载/延迟不完全相同；短采样窗须检查I/Q Gram秩。|
|WNMNLLT2：Prikhodko 等 - 2013 - Compensation of drifts in high-Q MEMS gyroscopes using temperature self-sensing|1,2,3,4|频率自测温：硅QMG模态频率随温度→PLL频率观测→输出热漂标定|Qeff影响速率标度的公式不是WA的B；fPLL还包含频裂方位、电调、幅度和相位偏置。|
|XQVCEDVX：Sun 等 - 2021 - 0.79 ppm scale-factor nonlinearity whole-angle microshell gyroscope realized by real-time calibratio|2,3,4,5,6|检测三倍频实时校准：电容非线性三次展开→基频/三倍频3:1项→幅值校准→全角标度非线性实验|与V8来源S2为同字节文件；检测逆已探索，在线3ω估计及其AFE响应/噪声门控尚未实现。|
|ZAMWMKAD：Wang 等 - 2022 - Effect of metallization on quality factor and noise characteristics in fused silica dual-shell gyros|1,2,3,4,5,6,7|镀层损耗和噪声：金属层厚度→机械Q与导电性→FRB电路/噪声→工艺权衡|FRB双壳器件与500kHz读出不能套成本机5kHz WA指标；应联动扫Q(h)、R(h)。|
|ZN9RFGQS：Serrano 等 - 2016 - Substrate-decoupled, bulk-acoustic wave gyroscopes Design and evaluation of next-generation environ|3,4,5|衬底隔离与损耗：支撑应变能→锚损耗/PML估计→模态阻尼耦合→结构隔离及抗振|4.3MHz的n=3 BAW速率器件不是n=2 HRG；PML的锚损耗下界不等于封装后实际Q。|

本轮对应实现与算例见[补充推导](source_formula_updates.md)第3–11节；机械积分到电路/算法的主链条见[20节主推导](../../literature_v8_research/docs/mechanics_to_algorithms.md)。每个模型参数都须带结构类别、单位、角度约定与实验条件，论文样机性能不作为本工程达标证据。
