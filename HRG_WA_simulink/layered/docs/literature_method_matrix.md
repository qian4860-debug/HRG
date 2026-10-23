# 全角文献逐项方法对照清单

日期：2026-10-23。完整比较说明见同目录 `literature_derivation_comparison.md`。

本地73个不同字节对象（139处路径）全部登记；既往网络来源合并为80条记录。仅题录/摘要/扫描失败条目不能声称已逐式比较。

## 本地原文与邻近资料

| ID | 资料 | 已核对PDF页/层级 | 推导方法 | 与工程相同 | 差别/边界 |
|---|---|---|---|---|---|
| L001 | 项目整理白皮书V1.0 | [1, 2, 3] / derived | 工程二次整理 | 覆盖全角信号链 | 非独立原始论文，不作为自身推导的外部证明 |
| L002 | 2025驱动误差辨识与补偿 | [1, 2, 3, 4, 5, 6, 7] / sections | 电极间隙/安装角/驱动增益与相位→误差模型→专门激励辨识 | 都将执行误差放入双模态闭环 | 论文有具体辨识工况；本工程驱动力仍为线性kF，不能继承其实验性能 |
| L003 | 2025虚拟进动频裂辨识与调平 | [1, 2, 3, 4, 5] / sections | 虚拟进动→频裂观测→参数估计→离子束调平 | 都由频裂解释正交及漂移 | 论文闭合到实际机械修调；当前splitHz仅配置/扰动 |
| L004 | 半球谐振陀螺惯性敏感器及其空间应用 | [1, 2, 3, 6, 8, 9] / bibliographic | 封面/前言确认书名；理论章节未逐式读取 | 体系包含表头、控制、温度和空间应用 | 不能依据前言宣称其具体模型与本文等价；扫描章节列入待核验 |
| L005 | Charge-Domain Fractional-N ADPLL | [1, 2, 3] / abstract_claims | 电荷域采样鉴相、CDAC校正分数杂散 | 同涉及相位数字化 | 通用频率综合器；不是HRG机械锁相模型，不直接替换本工程PLL |
| L006 | 2024全角HRG数字ASIC前端 | [1, 2, 3, 4, 5, 6] / sections | 幅度解调→CORDIC DPLL→PI→角度展开→数字模块验证 | 与现有RTL功能链直接重叠 | 会议前端设计验证不是模拟接口/实测芯片签核；本推导额外反推SI电路预算 |
| L007 | AD9215 ADC原厂数据手册 | [1, 2, 3] / adjacent | 器件量程、噪声、时钟与采样规格 | 用于核对转换器接口 | 器件数据不是全角动力学推导；10位器件参数不等于当前18位场景 |
| L008 | AD9704/05/06/07 TxDAC数据手册 | [1, 2, 3] / adjacent | 电流型DAC、更新率与杂散规格 | 对应DAC接口要求 | 实际输出电流/负载须换算，不能直接套±2V电压型行为接口 |
| L009 | CN102812328A 非线性补偿角测量 | [1] / web_sections | 谐波频谱分析→补偿表→变偏置分离电极/电子非线性 | 同关注电路非线性进入角度 | 原PDF文本不可读，改核对公开原文摘要及说明书；当前未实现该谱校准表 |
| L010 | CN105547272A 压电HRG全角检测 | [1] / web_sections | 双PLL、解调、不变量、PI、调制 | 全角多环架构一致 | 压电换能及双PLL；不能沿用电容C/V与静电kF参数 |
| L011 | CN106959106B SOI封装微半球HRG | [1, 2, 3] / abstract_claims | 电极/封装结构及工艺 | 结构决定有效C、参与因子和间隙 | 制造方案，不提供可直接搬用的完整全角电路噪声预算 |
| L012 | CN107014366B 静电圆柱壳体陀螺 | [1, 2, 3] / abstract_claims | 圆柱壳体静电激励检测 | 可用双模态抽象讨论 | 器件为圆柱壳，不照搬半球Bryan系数与电极积分 |
| L013 | CN112504258A 自适应控制电路公开本 | [1, 2, 3] / abstract_claims | 环形二极管检测→ADC→FPGA→DAC反馈 | 多环/不变量路线相近 | 与L060属于同一申请的不同版本，不能算两种独立创新 |
| L014 | CN112595304B 工作模式自适应控制 | [1, 2, 3] / abstract_claims | SoC判定并切换FTR/WA | 共享检测、幅度、正交状态 | 本工程固定WA；模式切换与状态连续性尚未实现 |
| L015 | CN112729334B 电极间隙检测 | [1, 2, 3] / abstract_claims | 开关轮询电容测间隙及周向均匀性 | 为C(q)/增益误差提供实测输入 | 是标定测量线路，非完整WA导航控制推导 |
| L016 | CN113587954A 阻尼不均补偿 | [1, 2, 3] / abstract_claims | 误差拟合、反馈补偿、周期积分 | 同识别方位相关阻尼漂移 | 周期积分与比例因子残差处理不是当前简单PI或一次冻结标定 |
| L017 | CN113670340B X/Y相位差测角 | [1, 2, 3] / abstract_claims | 转台与改进测角方程辨识通道相位差 | 同区分公共与差分相位 | 需要已知转台条件，不能用公共相位校准替代两轴辨识 |
| L018 | CN114396927B SoC时分复用 | [1, 2, 3] / abstract_claims | FPGA采样/锁相、ARM控制、检测激励开关 | 与分层接口建模目标相同 | 真实切换及处理分区；V6仅门控驱动不等价 |
| L019 | CN114608614A 主动进动在线调谐 | [1, 2, 3] / abstract_claims | PIR稳态控制→正交控制量识别频裂轴/幅→电调 | 频裂、正交和控制力具有同一物理联系 | 增加PIR及模态匹配执行器，当前未闭合在线调谐 |
| L020 | CN114838741A 激励电极误差补偿 | [1, 2, 3] / abstract_claims | 正交脉冲扰动→PLL响应→增益扫描 | 同利用控制环串扰暴露执行误差 | 是特定静态方位辨识，不等同普适在线联合估计 |
| L021 | CN115388910B 误差自激励 | [1, 2, 3] / abstract_claims | 虚拟哥氏力与不同工作模式响应 | 同采用虚拟角速度激励 | 权利要求包含开环/FTR情形，不可一律当作WA自由进动方程 |
| L022 | CN115574798A 提高综合性能 | [1, 2, 3] / abstract_claims | WA选择最佳点→平台伺服维持等效力平衡 | 同利用驻波方位 | 包含外部惯性平台和电机，当前单表头闭环未建模 |
| L023 | CN115876182B 电极误差建模 | [1, 2, 3] / abstract_claims | 理想矩阵→刚度/阻尼不均→检测矩阵变换 | 与本工程矩阵链最直接相通 | 完整方程还含转动导数等项；平均近似和坐标须逐项映射 |
| L024 | CN116608889A 阻尼自校准 | [1, 2, 3] / abstract_claims | 输出速率模型→反馈速率→参数估计 | 同处理阻尼正弦项 | 特定反馈激励和标度条件；不是仅在输出减掉已知仿真真值 |
| L025 | CN116929322A 精确控制 | [1, 2, 3] / abstract_claims | 八电极分时、过零/CORDIC相位跟踪、EQL及SR | 与ASIC前端模块高度重叠 | 必须核对过零时序与数据有效窗；当前模型无完整八电极时序 |
| L026 | CN117330044A 驻波电信号解调 | [1, 2, 3] / abstract_claims | 滤波、参考信号、乘法解调、相位/角度反演 | 同为信号解调路线 | 摘要和权利要求不构成已核验的完整噪声、动态预算 |
| L027 | CN117705163A 自激解耦标补 | [1, 2, 3] / sections | 转台检测→虚拟激励相位→执行→静态阻尼分阶段辨识 | 同强调检测、执行、相位与结构误差分开 | 具有明确可分离激励条件；当前RLS/EKF接入不代表已复现全过程 |
| L028 | CN118010069A 振动误差补偿 | [1, 2, 3] / abstract_claims | 加速度曲线统计与振动状态修正 | 同要求环境误差验证 | 不是两模态静态角度误差模型，须增加振动耦合路径 |
| L029 | CN118836840A 差分调频自补偿 | [1, 2, 3] / abstract_claims | 顺逆行波分离→双AGC/PLL→虚拟哥氏调频→阻尼补偿 | 同属WA并利用虚拟进动 | 观测量是行波幅频；不能直接套幅度IQ的ADC/PLL预算 |
| L030 | EP1722193A2 HRG control | [1, 2, 3] / sections | 波腹/波节时空控制分量及WA/FTR | 与能量/正交/锁相自由度划分一致 | 与L067及US7318347B2按控制路线归组，不重复计算方法 |
| L031 | EP2356404B1 Vibratory gyro calibration | [1, 2, 3] / abstract_claims | 系统冗余参考下重复标定漂移/方位相关误差 | 同承认校准随时间退化 | 多陀螺参考条件；当前单表头模型不能证明该自校准可观测性 |
| L032 | EP3096111B1 HRG | [1, 2, 3] / sections | 模态提取、频率校正、负刚度正交抑制与幅度控制 | 同有双模态、PLL和角度输出 | 直流刚度调节与交流力的执行方式不同，不能都简化成同一kF |
| L033 | Full digital FTR control | [1, 2, 3] / abstract_claims | DSP+FPGA力再平衡闭环 | 可借鉴数字实现和环路方法 | 方位被锁定，输出来自再平衡力；不是WA角度输出公式 |
| L034 | 全差分运放输出平衡 | [1, 2, 3] / abstract_claims | 共模反馈与差分通路共享器件 | 为读出共模/匹配提供电路参考 | 不是WA机械模型；需在晶体管级另验证 |
| L035 | High-Q MEMS whole-angle operation | [1, 2, 3] / sections | 高Q自由衰减与闭环WA对照 | 同用两模态与能量/正交/PLL | 平面MEMS，角增益和结构参与因子不作为宏观HRG真值 |
| L036 | Safran HRG技术综述 | [1, 2, 3] / abstract_claims | 产品原理和工程实现经验 | 驻波进动、对称性要求一致 | 产品介绍不能代替本文各参数的推导和独立实验 |
| L037 | JP2008241706A 双谐振子标度自校准 | [1] / web_sections | 双谐振子分别闭环/WA，再交换工作方式 | 同需校准标度因子 | 增加第二个谐振子及参考，非单表头FRP；原PDF日文编码未直接采用 |
| L038 | 2025闭环单通道TDM检测 | [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11] / sections | 复用读出闭环→切换误差模型→改进解调 | 同处理X/Y增益与相位不一致 | 真实单通道时分检测；当前连续双通道及驱动门控未覆盖该机制 |
| L039 | 2026 FRP谐波漂移消除 | [1, 2, 3, 4, 5, 6, 7, 8] / sections | 多误差动力学→正反进动→在线辨识及温度验证 | 同用方位谐波与虚拟进动 | 特定FRP激励和辨识模型；工程内核接入不等于复现论文性能 |
| L040 | Safran导航级Si-MEMS | [1, 2, 3] / abstract_claims | 产品/技术性能演进 | 可参考噪声、环境验证项目 | 邻近器件资料，非本项目HRG参数来源 |
| L041 | US10113873 多质量WA MEMS结构 | [1, 2, 3] / abstract_claims | 多质量/耦合梁形成两振动模态 | 同需简并模态与换能器 | 平面多质量结构，m/B/电极模型不同 |
| L042 | US10520331 WA死区校准 | [1, 2, 3] / abstract_claims | 辨识速率死区并施加补偿力 | 与阻尼死区和主动补偿有关 | 需执行器可用性与辨识条件，不能由已有阈值公式证明已实现 |
| L043 | US7912664 多陀螺自校准 | [1, 2, 3] / abstract_claims | 冗余、多轴、模式反转与比例因子估计 | 同利用模式变化分离误差 | 依赖系统冗余，不是单HRG三环结构 |
| L044 | US8800349 多陀螺标度校准 | [1, 2, 3] / abstract_claims | 至少四陀螺参考→驻波位置变化→标度估计 | 同采用驻波位置和已知激励 | 独立参考来自其他陀螺；当前无此系统 |
| L045 | US8991249 压电组件振动陀螺 | [1, 2, 3] / abstract_claims | 两模态压电驱动/检测结构 | 双模态抽象可以借用 | 压电本构和换能系数须重推，电容/静电预算不能复用 |
| L046 | US9080870B2 MEMS angular rate sensor structure | [1] / adjacent | 首页摘要渲染：质量块两转动自由度与哥氏检测结构 | 同利用哥氏耦合 | 邻近速率MEMS结构，不是WA-HRG完整控制推导；未读正文系数 |
| L047 | US9217640 双向驻波控制 | [1, 2, 3] / abstract_claims | 周期正反进动、扣除控制量并与参考比较 | 与FRP校准思想接近 | 具体参考、波形、误差识别条件不同，不认定为同一实现 |
| L048 | 非轴对称振动误差模型更新 | [1, 2, 3] / abstract_claims | 非轴对称三维振动加速度耦合 | 同要求结构不均匀性建模 | 二维近谐振模型未覆盖完整三维振动误差 |
| L049 | CN116610030B 死区与抗干扰 | [1, 2, 3] / abstract_claims | 随机平均→死区/外扰复合观测器→前馈+PI | 同有慢变量与死区 | 扰动观测器和鲁棒性证明未在当前三PI中实现 |
| L050 | 吴俊恒2023特征参数辨识与补偿 | [4, 5, 6, 7, 8, 23, 24, 25, 26, 27, 28, 29, 30] / sections | 薄壳/Lagrange→平均慢变量→LS/RLS→两力前馈 | 与频裂/阻尼矩阵、参数辨识链一致 | 论文细化控制量观测与输出/力前馈两种补偿；当前未逐工况复现实验 |
| L051 | 项目生成的全角教材 | [1, 2, 3] / derived | 二次整理 | 与工程解释一致 | 不能用项目自身文稿证明推导正确 |
| L052 | 张岚昕等2019信号处理控制 | [1, 2, 3, 4, 5, 6, 7] / sections | 二阶模型→椭圆→相干解调→EQL/SR→PI→Simulink | 基础功能链与本工程一致 | 式(4)-(7)角度及SR印刷需独立验算；未展开当前完整接口噪声预算 |
| L053 | 刘学2024控制与误差补偿系统 | [2, 3, 4, 5, 6, 7, 8, 9, 10, 34, 35, 36, 37, 38, 39, 40, 41, 43, 55, 56, 57, 58, 59, 62, 63, 64, 65] / sections | 薄壳/平均→4θ误差→分时电路→主动补偿→样机 | 同把检测/控制/驱动放进系统链 | 原文有实际切换/拟合和样机测试；本工程尚无同等硬件证据 |
| L054 | 蒲云飞2022全角控制技术 | [3, 5, 9, 11, 13, 14, 15, 43, 44, 45, 46, 55, 56, 57] / visual_sections | 薄壳/平均→PI谐波残差→PIR→卸荷分时→频裂电调 | 基础双模态/三环一致 | PIR内模、真实卸荷时序和电调是当前PI/V6模型缺项 |
| L055 | 何栓2023误差分析及补偿 | [4, 5, 6, 7, 8, 9, 23, 24, 25, 26, 27, 28, 29] / sections | 环形/二阶模型→四控制力→检测/执行矩阵→顺序解耦 | 与综合误差链和矩阵表达相通 | 论文增加可分离条件、两力前馈和双陀螺标度；不能由单轨迹RLS替代 |
| L056 | 2025通道误差与全温补偿 | [1, 2, 3] / sections | 检测/执行幅相及非线性→全温补偿 | 直接支持接口误差不能独立于控制分析 | 本工程温度系数和漂移仍为假设，未复现其全温标定 |
| L057 | 陈洋2023量化与阻尼误差 | [1, 2, 3, 4, 5, 6, 7, 8, 9, 23, 24, 25, 26, 27, 34, 35, 36, 49, 50, 51, 52, 53, 59, 60, 61, 62, 63, 66, 70] / sections | 平均法→内部截位传播→浮点→偏导测率/TD→虚拟旋转阻尼补偿 | 与Jacobian、噪声和死区链同源 | ADC位置/量化类型不同；论文具体浮点/TD/交替旋转不等同当前定点预算和内核 |
| L058 | 2023 Kalman解调全角控制 | [1, 2, 3] / sections | 双模态→状态估计解调→不变量→控制 | 物理状态和不变量可对应 | Kalman观测器取代部分传统解调；式(7)局部角度印刷不直接照搬 |
| L059 | 2023 RLS自补偿 | [1, 2, 3, 4, 5, 6] / sections | 方位相关漂移参数化→RLS递推→在线补偿 | 与工程RLS补偿内核方向一致 | 辨识激励、回归量及验证数据需对齐，不能仅以算法名判定等价 |
| L060 | CN112504258B 自适应控制电路授权本 | [1, 3, 4] / sections | 电容检测/ADC/FPGA/DAC、多环控制 | 总体功能链一致 | 和L013版本相关；式(8)零相位反例已核对，不能逐字照搬 |
| L061 | 2023频率解调控制 | [1, 2, 3, 4, 5] / sections | 顺逆行波分离与频率同步解调→多环→FPGA+DSP | 机械WA目标相同 | 状态坐标/观测器/NCO数量及误差传递改变，非换一个atan即可实现 |
| L062 | 2022 MEMS 3D HRG综述文件 | [] / unreadable | 原文件解析Unexpected EOF | 仅保存路径与SHA | 本地文件不能读，旧索引的已验证状态需降级；不据文件名总结正文 |
| L063 | 2021阻尼死区与虚拟进动 | [1, 2, 3, 4, 5] / sections | 阻尼不均→锁定阈值→虚拟进动 | 与本项目死区机理一致 | Δ衰减及角度定义不同，阈值系数按本项目Γ重新投影 |
| L064 | 2021矢量合成全角控制 | [1, 2, 3, 4, 5, 6, 7] / sections | 控制力矢量合成/分解与相位跟踪 | 与h的空间/时间分量可映射 | 侧重实际电极合力与效率；本推导另做噪声及接口预算 |
| L065 | 2026图形化薄膜高Q mHRG | [1, 2, 3] / abstract_claims | 薄膜工艺→损耗机制→Q和频裂测试 | 为Q/Δf/阻尼均匀性提供器件约束 | 制造/器件论文，不是整套控制或电路参数推导 |
| L066 | NASA R&T汇编中的HRG条目 | [1, 2, 3, 138] / background | PDF138页为HRG/Hubble说明 | 确认WA为速率积分、可切换FTR及电容换能 | 260页汇编而非260页HRG专著，不含可复用的完整控制推导 |
| L067 | US20060248953A1 HRG control | [1, 2, 3] / abstract_claims | 经典WA/FTR时空控制分解 | 与US7318347B2/EP1722193A2控制路线一致 | 公开版本不同不作为三套独立方法计数 |
| L068 | US20160334214A1 HRG | [1, 2, 3] / abstract_claims | 振型提取、频率校正、直流正交及交流维振 | 基础全角状态一致 | 直流刚度调节和交流力必须分别建模 |
| L069 | 谐振陀螺仪与系统技术 | [5, 7, 27, 30] / visual_sections | 薄壳模态积分→Bryan因子→等效二阶→平均慢变量 | 给出本工程B/双模态抽象的上游理论 | 书中保留形函数积分与结构设计；当前B/m直接参数化 |
| L070 | 2011商用SDR控制RIG | [1, 2, 3] / sections | 商业采集/FPGA软件链实现幅度正交转向控制 | 与分层数字/模拟接口及延迟预算相近 | 具体商业硬件7ms延迟不是当前7.525ms估算的验证证据 |
| L071 | 2022非线性RIG作者稿 | [1, 2, 3] / sections | 平面MEMS非线性、能量/控制耦合 | 提示大幅SNR与非线性折中 | 器件和角度因子不同，不能移植其数值为HRG设计值 |
| L072 | 2012 Foucault pendulum on a chip | [1, 2, 3] / sections | 高Q对称MEMS→自由进动与闭环角测量 | 速率积分与对称性机理一致 | 平面四质量/2kHz器件，模态质量及角增益不同 |
| L073 | 2023 MEMS接口ASIC片上温补 | [1, 2, 3] / adjacent | MEMS驱动环/系统带宽/温补ASIC | 接口噪声、闭环和温度分析可借鉴 | 新根目录筛查发现的邻近技术，不能直接作为WA-HRG方位控制推导 |

绝对路径、SHA-256、重复位置见 `../evidence/literature_comparison/comparison_catalog.json`。

## 既往网络资源逐条覆盖

| ID | 原始来源/题录 | 证据层级 | 相同点 | 差别/待核验 |
|---|---|---|---|---|
| W001 | [Novel Bias Drift Mechanism of Whole-Angle Mode Gyroscopes: Oscillatory Rectification Errors. Nonlinear Dynamics, 2026-07](https://doi.org/10.1007/s11071-026-12837-6) | primary_abstract | 出版社摘要以等价变换及叠加分析周期转动下的非对称动力学漂移 | 订阅预览未提供全文；本工程共同Duffing项不能视为该ORE解析模型，未核对吸引域方程 |
| W002 | [Forgetting filter-based real-time identification and compensation of whole-angle hemispherical resonator gyroscope errors for extensive aerospace applications. AST, 2026-01卷](https://doi.org/10.1016/j.ast.2025.111283) | pending_fulltext | 题录已覆盖；尚不能判定具体推导与项目等价 | 未核验正文的公式、系数、实验条件，不根据题目补写方法 |
| W003 | [Wang N et al. High-precision frequency split Identification and balancing of the hemispherical resonator gyro via Virtual Precession. IFAC-PapersOnLine, 59-20, 640–644, 2025.](https://doi.org/10.1016/j.ifacol.2025.11.223) | local_sections / L003 | 见对应本地条目的具体推导比较 | 本地原文已读范围见localId；不继承旧记录的全文阅读声称 |
| W004 | [11. 亚表面损伤和 Q 提升：IJMS 2025.](https://doi.org/10.1016/j.ijmecsci.2024.109912) | pending_fulltext | 题录已覆盖；尚不能判定具体推导与项目等价 | 未核验正文的公式、系数、实验条件，不根据题目补写方法 |
| W005 | [Equivalent Bryan’s factor in hemispherical resonator gyroscopes with nonuniformities coupling. IJMS, 2026-04卷](https://doi.org/10.1016/j.ijmecsci.2026.111465) | pending_fulltext | 题录已覆盖；尚不能判定具体推导与项目等价 | 未核验正文的公式、系数、实验条件，不根据题目补写方法 |
| W006 | [MEMS interface ASIC with on-chip temperature compensation](https://doi.org/10.1016/j.measurement.2023.113331) | local_sections / L073 | 见对应本地条目的具体推导比较 | 本地原文已读范围见localId；不继承旧记录的全文阅读声称 |
| W007 | [Wang R et al. High-precision identification and compensation of nonlinear error in hemispherical resonator gyro. Measurement, 237, 114945, 2024.](https://doi.org/10.1016/j.measurement.2024.114945) | pending_fulltext | 题录已覆盖；尚不能判定具体推导与项目等价 | 未核验正文的公式、系数、实验条件，不根据题目补写方法 |
| W008 | [Identification and compensation method for unbalance error in signal detection chain of Rate-Integrating hemispherical resonator gyro. Measurement, 2025-01卷](https://doi.org/10.1016/j.measurement.2024.115599) | pending_fulltext | 题录已覆盖；尚不能判定具体推导与项目等价 | 未核验正文的公式、系数、实验条件，不根据题目补写方法 |
| W009 | [Whole-chain multi-mode error compensation for high-precision rate-integrating micro-hemispherical resonator gyroscopes. Measurement, 2026-05卷](https://doi.org/10.1016/j.measurement.2026.121170) | pending_fulltext | 题录已覆盖；尚不能判定具体推导与项目等价 | 未核验正文的公式、系数、实验条件，不根据题目补写方法 |
| W010 | [Foucault pendulum on a chip: Rate integrating silicon MEMS gyroscope](https://doi.org/10.1016/j.sna.2012.01.029) | local_sections / L072 | 见对应本地条目的具体推导比较 | 本地原文已读范围见localId；不继承旧记录的全文阅读声称 |
| W011 | [Wang Q et al. A drive error identification and compensation method for whole angle mode hemispherical resonator gyroscope. Sensors and Actuators A: Physical, 387, 116402, 2025.](https://doi.org/10.1016/j.sna.2025.116402) | local_sections / L002 | 见对应本地条目的具体推导比较 | 本地原文已读范围见localId；不继承旧记录的全文阅读声称 |
| W012 | [Virtual precession-enabled phase error mitigation in high-precision hemispherical resonator gyroscopes. S&A A, 2025-12卷](https://doi.org/10.1016/j.sna.2025.116976) | pending_fulltext | 题录已覆盖；尚不能判定具体推导与项目等价 | 未核验正文的公式、系数、实验条件，不根据题目补写方法 |
| W013 | [Propagation mechanism of 1/f noise in FTR system of micro hemispherical resonator gyroscopes. MSSP, 2025-10卷](https://doi.org/10.1016/j.ymssp.2025.113228) | pending_fulltext | 题录已覆盖；尚不能判定具体推导与项目等价 | 未核验正文的公式、系数、实验条件，不根据题目补写方法 |
| W014 | [Ren X et al. Noise analysis and suppression of whole-angle MEMS gyroscopes based on detection-axes-rotation. Mechanical Systems and Signal Processing, 258, 114724, 2026.](https://doi.org/10.1016/j.ymssp.2026.114724) | pending_fulltext | 题录已覆盖；尚不能判定具体推导与项目等价 | 未核验正文的公式、系数、实验条件，不根据题目补写方法 |
| W015 | [Yu S et al. Real-time correction of gain nonlinearity in electrostatic actuation for whole-angle micro-shell resonator gyroscope. Microsystems & Nanoengineering, 10, 164, 2024.](https://doi.org/10.1038/s41378-024-00818-x) | primary_abstract | 已核验摘要说明非线性执行或参数激励属于相关路线 | 未核验全文系数；位移相关驱动增益/2f0刚度调制不能等同当前线性f0驱动 |
| W016 | [Yu S et al. 0.32 mHz frequency mismatch of micro-shell resonator gyroscope without tuning electrodes achieved by ultra-precision mechanical trimming. Microsystems & Nanoengineering, 11, 102, 2025.](https://doi.org/10.1038/s41378-025-00872-z) | primary_sections | Lynch慢变量→正交控制力随方位变化→频裂及主轴估计，与本项目频裂/控制力机制相通 | 核对原文式(5)-(7)、相位误差与修调流程；原文增加自进动探针、实测标度和机械修调，当前仅有参数注入 |
| W017 | [Wu K et al. Localized thermal tuning in fused silica inductive vibrating ring gyroscopes. Microsystems & Nanoengineering, 2026.](https://doi.org/10.1038/s41378-026-01203-6) | pending_fulltext | 题录已覆盖；尚不能判定具体推导与项目等价 | 未核验正文的公式、系数、实验条件，不根据题目补写方法 |
| W018 | [Manufacturing of 8 million Q-factor micro hemispherical resonator gyroscopes via patterned coating technology. Microsystems & Nanoengineering, 2026-05-22](https://doi.org/10.1038/s41378-026-01321-1) | local_sections / L065 | 见对应本地条目的具体推导比较 | 本地原文已读范围见localId；不继承旧记录的全文阅读声称 |
| W019 | [L2 ／ `C:/Users/11725/Desktop/HRG_WA/全角陀螺/新增资料_20260825/02_控制与信号处理/2021_Dead_Area_Compensation_Rate_Integrating_HRG.pdf`； ／ 本轮读PDF2–5；PDF4–5渲染检查；死区机理。不同符号系数不直接搬入项目](https://doi.org/10.1038/s41598-020-80885-y) | local_sections / L063 | 见对应本地条目的具体推导比较 | 本地原文已读范围见localId；不继承旧记录的全文阅读声称 |
| W020 | [Ning Y et al. Identification and correction of phase delay errors for hemispherical resonator gyroscopes. Scientific Reports, 2025.](https://doi.org/10.1038/s41598-025-86288-1) | primary_sections | 电子相位→正交力泄漏→角速率偏差，与本项目链一致 | 原文式(1)-(13)/图4含在线正交扰动校相；本工程仅标称相位冻结及接口注入 |
| W021 | [Joint compensation of time delay and damping asymmetry errors for whole-angle hemispherical resonator gyroscopes. Review of Scientific Instruments, 2026-01-01](https://doi.org/10.1063/5.0268634) | pending_fulltext | 题录已覆盖；尚不能判定具体推导与项目等价 | 未核验正文的公式、系数、实验条件，不根据题目补写方法 |
| W022 | [Zhou et al. A study of digital ASIC front-end design techniques for whole-angle mode hemispherical resonant gyros. ECIE, 2024.](https://doi.org/10.1109/ecie61885.2024.10627746) | local_sections / L006 | 见对应本地条目的具体推导比较 | 本地原文已读范围见localId；不继承旧记录的全文阅读声称 |
| W023 | [Disk Resonator Gyroscope with Whole-Angle Mode Operation](https://doi.org/10.1109/isiss.2015.7102360) | pending_fulltext | 题录已覆盖；尚不能判定具体推导与项目等价 | 未核验正文的公式、系数、实验条件，不根据题目补写方法 |
| W024 | [In-Run Automatic Mode-Matching of Whole-Angle Micro-Hemispherical Resonator Gyroscope Based on Standing Wave Self-Precession](https://doi.org/10.1109/jsen.2022.3181302) | pending_fulltext | 题录已覆盖；尚不能判定具体推导与项目等价 | 未核验正文的公式、系数、实验条件，不根据题目补写方法 |
| W025 | [Asymmetric Phase-Delay Modeling and Online Compensation for Whole-Angle Micro-Hemispherical Resonator Gyroscopes. IEEE Sensors Journal, 2026](https://doi.org/10.1109/jsen.2026.3728523) | pending_fulltext | 题录已覆盖；尚不能判定具体推导与项目等价 | 未核验正文的公式、系数、实验条件，不根据题目补写方法 |
| W026 | [A Novel Hybrid Mode for Hemispherical Resonator Gyroscope Inertial Navigation Systems: Principle and System-Level Calibration Method. IEEE TII, 2026-10卷](https://doi.org/10.1109/tii.2026.3698512) | pending_fulltext | 题录已覆盖；尚不能判定具体推导与项目等价 | 未核验正文的公式、系数、实验条件，不根据题目补写方法 |
| W027 | [Separation, Identification, and Compensation of Damping, Detection, and Actuation Errors for Rate-Integrating Hemispherical Resonator Gyroscopes. IEEE TIM, 2025](https://doi.org/10.1109/tim.2025.3555670) | pending_fulltext | 题录已覆盖；尚不能判定具体推导与项目等价 | 未核验正文的公式、系数、实验条件，不根据题目补写方法 |
| W028 | [Self-Calibration Method for Phase Errors in Hemispherical Resonator Gyroscopes Based on Virtual Precession. IEEE TIM, 75, 9503212, 2026.](https://doi.org/10.1109/tim.2025.3586357) | pending_fulltext | 题录已覆盖；尚不能判定具体推导与项目等价 | 未核验正文的公式、系数、实验条件，不根据题目补写方法 |
| W029 | [Real-Time Elimination of Harmonic Drift for Hemispherical Resonator Gyro Based on FRP Control Scheme. IEEE TIM, 2026](https://doi.org/10.1109/tim.2025.3650265) | local_sections / L039 | 见对应本地条目的具体推导比较 | 本地原文已读范围见localId；不继承旧记录的全文阅读声称 |
| W030 | [Identification and Compensation of Detection Electrode Errors in Hemispherical Resonator Gyroscopes via Bidirectional Turntable Rotations. IEEE TIM, 2026](https://doi.org/10.1109/tim.2026.3667313) | pending_fulltext | 题录已覆盖；尚不能判定具体推导与项目等价 | 未核验正文的公式、系数、实验条件，不根据题目补写方法 |
| W031 | [Modeling, Decoupling Identification, and Compensation of Imbalance Errors for Whole-Angle Hemispherical Resonator Gyroscopes. IEEE TIM, 2026](https://doi.org/10.1109/tim.2026.3674286) | pending_fulltext | 题录已覆盖；尚不能判定具体推导与项目等价 | 未核验正文的公式、系数、实验条件，不根据题目补写方法 |
| W032 | [Modeling, Characterization, and Compensation of Detection Errors for Differential Frequency Modulation Whole-Angle Hemispherical Resonator Gyroscope. IEEE TIM, 2026](https://doi.org/10.1109/tim.2026.3682829) | pending_fulltext | 题录已覆盖；尚不能判定具体推导与项目等价 | 未核验正文的公式、系数、实验条件，不根据题目补写方法 |
| W033 | [Modeling, Identifying, and Ultrahigh-Precision Trimming of Mass Imperfection in Hemispherical Resonator. IEEE TIM, 2026](https://doi.org/10.1109/tim.2026.3704236) | pending_fulltext | 题录已覆盖；尚不能判定具体推导与项目等价 | 未核验正文的公式、系数、实验条件，不根据题目补写方法 |
| W034 | [1. WA 矢量合成控制：](https://doi.org/10.1186/s13638-021-01913-7) | local_sections / L064 | 见对应本地条目的具体推导比较 | 本地原文已读范围见localId；不继承旧记录的全文阅读声称 |
| W035 | [关泽源等. 基于频率解调的半球谐振陀螺控制系统设计. 压电与声光, 45(4), 494–498, 2023.](https://doi.org/10.11977/j.issn.1004-2474.2023.04.002) | local_sections / L061 | 见对应本地条目的具体推导比较 | 本地原文已读范围见localId；不继承旧记录的全文阅读声称 |
| W036 | [蒋效雄等. 基于 RLS 算法的全角模式半球谐振陀螺自补偿控制. 中国惯性技术学报, 31(4), 401–406, 2023.](https://doi.org/10.13695/j.cnki.12-1222/o3.2023.04.011) | local_sections / L059 | 见对应本地条目的具体推导比较 | 本地原文已读范围见localId；不继承旧记录的全文阅读声称 |
| W037 | [Chen W. HRG simulation, experimental and analysis data, version 1. Mendeley Data, 2026.](https://doi.org/10.17632/t979rtsdsv.1) | pending_fulltext | 题录已覆盖；尚不能判定具体推导与项目等价 | 未核验正文的公式、系数、实验条件，不根据题目补写方法 |
| W038 | [Identification and Compensation of Detection Gain Asymmetry Errors for Hemispherical Resonant Gyroscopes in Whole-Angle Mode. Actuators, 2025-06-03](https://doi.org/10.3390/act14060275) | pending_fulltext | 题录已覆盖；尚不能判定具体推导与项目等价 | 未核验正文的公式、系数、实验条件，不根据题目补写方法 |
| W039 | [Wang Q et al. A Novel Closed-Loop Single-Channel Time Division Multiplexing Detection Circuit for Hemispherical Resonator Gyroscope. Micromachines, 16, 273, 2025.](https://doi.org/10.3390/mi16030273) | local_sections / L038 | 见对应本地条目的具体推导比较 | 本地原文已读范围见localId；不继承旧记录的全文阅读声称 |
| W040 | [9. 谐振子结构多目标优化：Micromachines 2025.](https://doi.org/10.3390/mi16030287) | pending_fulltext | 题录已覆盖；尚不能判定具体推导与项目等价 | 未核验正文的公式、系数、实验条件，不根据题目补写方法 |
| W041 | [6. 温度偏置：Compensation of Temperature-Induced Bias Drift in HRGs. Micromachines 2025.](https://doi.org/10.3390/mi16040357) | pending_fulltext | 题录已覆盖；尚不能判定具体推导与项目等价 | 未核验正文的公式、系数、实验条件，不根据题目补写方法 |
| W042 | [Influence Mechanism of Quantization Error on the Key Parameters of the Whole-Angle Hemisphere Resonator Gyroscope. Micromachines, 2026-01-22](https://doi.org/10.3390/mi17010143) | primary_sections | 从通道量化误差经解调/参数函数传播，与Jacobian方法一致 | 原文§3/§5特别研究方位调制与相干量化；此前独立白噪声位数预算仅是条件近似 |
| W043 | [3. FPGA FTR 控制和误差抑制：](https://doi.org/10.3390/s111211761) | pending_fulltext | 题录已覆盖；尚不能判定具体推导与项目等价 | 未核验正文的公式、系数、实验条件，不根据题目补写方法 |
| W044 | [W3 ／  ／ 原始作者公开摘要，确认2f0参数激励是另一实现路线；未复现其稳定性阈值](https://doi.org/10.3390/s20123549) | primary_abstract | 已核验摘要说明非线性执行或参数激励属于相关路线 | 未核验全文系数；位移相关驱动增益/2f0刚度调制不能等同当前线性f0驱动 |
| W045 | [Automatic Rate and Rate-Integrating Mode-Switchable Axisymmetric Gyroscope](https://doi.org/10.3390/s22124334) | pending_fulltext | 题录已覆盖；尚不能判定具体推导与项目等价 | 未核验正文的公式、系数、实验条件，不根据题目补写方法 |
| W046 | [10. 能量耗散：Sensors 2025.](https://doi.org/10.3390/s25010074) | pending_fulltext | 题录已覆盖；尚不能判定具体推导与项目等价 | 未核验正文的公式、系数、实验条件，不根据题目补写方法 |
| W047 | [7. HRG-INS 角位置相关偏置：Sensors 2025.](https://doi.org/10.3390/s25216639) | pending_fulltext | 题录已覆盖；尚不能判定具体推导与项目等价 | 未核验正文的公式、系数、实验条件，不根据题目补写方法 |
| W048 | [Micromachined Rate-Integrating Gyroscopes: Concept, Asymmetry Error Sources and Phenomena](https://doi.org/10.3390/sym12050801) | primary_sections | 理想/非理想二模态，分离刚度/阻尼误差逐项仿真 | 平面MEMS结构与λ定义不同；与分层扫参方法相近，但不提供HRG电极SI预算 |
| W049 | [王瑞祺等. 全差分频率调制半球谐振陀螺装配误差辨识及补偿方法. 航空学报, 47(5), 332079, 2026.](https://doi.org/10.7527/s1000-6893.2025.32079) | primary_abstract_figures | 官方摘要建立装配倾斜/偏心→通道耦合→动态谐波的链条，与接口闭环思想一致 | 原文采用差分调频、TDM和非线性联合辨识；RichHTML未提供正文公式，不能据摘要套用当前AM预算 |
| W050 | [Rate-Integrating Gyroscope Operation in The Non-Linear Regime](https://bpb-us-e2.wpmucdn.com/faculty.sites.uci.edu/dist/e/700/files/2022/09/DGON22_NonLinear_RIG_Sub.pdf) | local_sections / L071 | 见对应本地条目的具体推导比较 | 本地原文已读范围见localId；不继承旧记录的全文阅读声称 |
| W051 | [MEMS Rate and Rate-Integrating Gyroscope Control with Commercial Software Defined Radio Hardware](https://engineering.purdue.edu/oxidemems/conferences/transducers2011/PDFs/Papers/07-085.pdf) | local_sections / L070 | 见对应本地条目的具体推导比较 | 本地原文已读范围见localId；不继承旧记录的全文阅读声称 |
| W052 | [Online Mode-Matching Method Countering Stiffness Nonlinearity for Whole-Angle Micro-Shell Resonator Gyroscope. IEEE Sensors Journal, 2025.](https://ieeexplore.ieee.org/document/10938217) | pending_fulltext | 题录已覆盖；尚不能判定具体推导与项目等价 | 未核验正文的公式、系数、实验条件，不根据题目补写方法 |
| W053 | [Zeng et al. 0.08 ppm 标度因数非线性 HRG 研究（条目主题简称；完整题名见 IEEE）. IEEE Electron Device Letters, 2025.](https://ieeexplore.ieee.org/document/11145770) | pending_fulltext | 题录已覆盖；尚不能判定具体推导与项目等价 | 未核验正文的公式、系数、实验条件，不根据题目补写方法 |
| W054 | [Modeling, Decoupling Identification, and Compensation of Imbalance Errors for Whole-Angle Hemispherical Resonator Gyroscopes. IEEE TIM, 2026.](https://ieeexplore.ieee.org/document/11435219) | pending_fulltext | 题录已覆盖；尚不能判定具体推导与项目等价 | 未核验正文的公式、系数、实验条件，不根据题目补写方法 |
| W055 | [1. NASA Hubble/HRG 项目材料：](https://ntrs.nasa.gov/api/citations/19960045774/downloads/19960045774.pdf) | background_or_tutorial | 产品/原理/转换器基础参考 | 不是独立完整WA推导；不能用作本项目性能证据 |
| W056 | [2. NASA 航天器姿态与 HRG 模型：](https://ntrs.nasa.gov/api/citations/20130014073/downloads/20130014073.pdf) | background_or_tutorial | 产品/原理/转换器基础参考 | 不是独立完整WA推导；不能用作本项目性能证据 |
| W057 | [P2 ／  ／ 权利要求1、7；式(1)–(8)。原始PDF21页，PDF4/权利要求3/4页的式(8)本轮渲染核实](https://patents.google.com/patent/CN112504258B/zh) | patent_record | 公开专利条目按控制、校准或结构路线登记 | 未读权利要求/说明书的条目不判定公式等价、创新性或已实现；详读条目见本地表 |
| W058 | [3. 单通道时分复用：](https://patents.google.com/patent/CN112506040A/en) | patent_record | 公开专利条目按控制、校准或结构路线登记 | 未读权利要求/说明书的条目不判定公式等价、创新性或已实现；详读条目见本地表 |
| W059 | [4. 检测增益不对称 FTR 标定、WA 补偿：](https://patents.google.com/patent/CN117029882B/zh) | patent_record | 公开专利条目按控制、校准或结构路线登记 | 未读权利要求/说明书的条目不判定公式等价、创新性或已实现；详读条目见本地表 |
| W060 | [6. 全角鲁棒智能控制：](https://patents.google.com/patent/CN117170234A/en) | patent_record | 公开专利条目按控制、校准或结构路线登记 | 未读权利要求/说明书的条目不判定公式等价、创新性或已实现；详读条目见本地表 |
| W061 | [7. 全角驻波方位交替解算：](https://patents.google.com/patent/CN117346821A/en) | patent_record | 公开专利条目按控制、校准或结构路线登记 | 未读权利要求/说明书的条目不判定公式等价、创新性或已实现；详读条目见本地表 |
| W062 | [P4 ／  ／ 说明书S1–S4：转台、虚拟哥氏激励、静态测漂及分阶段标补；S2解释锁相目标值与真实谐振的区别](https://patents.google.com/patent/CN117705163A/zh) | patent_record | 公开专利条目按控制、校准或结构路线登记 | 未读权利要求/说明书的条目不判定公式等价、创新性或已实现；详读条目见本地表 |
| W063 | [5. FTR/WA 双模控制：](https://patents.google.com/patent/CN120252671A/en) | patent_record | 公开专利条目按控制、校准或结构路线登记 | 未读权利要求/说明书的条目不判定公式等价、创新性或已实现；详读条目见本地表 |
| W064 | [9. 宽边缘谐振敏感结构：](https://patents.google.com/patent/EP3059549B1/en) | patent_record | 公开专利条目按控制、校准或结构路线登记 | 未读权利要求/说明书的条目不判定公式等价、创新性或已实现；详读条目见本地表 |
| W065 | [8. 曲面支撑结构制造：](https://patents.google.com/patent/EP4328545B1/en) | patent_record | 公开专利条目按控制、校准或结构路线登记 | 未读权利要求/说明书的条目不判定公式等价、创新性或已实现；详读条目见本地表 |
| W066 | [10. 新型谐振器附件：](https://patents.google.com/patent/EP4594706A1/en) | patent_record | 公开专利条目按控制、校准或结构路线登记 | 未读权利要求/说明书的条目不判定公式等价、创新性或已实现；详读条目见本地表 |
| W067 | [2. Mitsubishi 多电极 HRG：](https://patents.google.com/patent/US20160334214A1/en) | patent_record | 公开专利条目按控制、校准或结构路线登记 | 未读权利要求/说明书的条目不判定公式等价、创新性或已实现；详读条目见本地表 |
| W068 | [1. WA/FTR 经典控制：](https://patents.google.com/patent/US7318347B2/en) | patent_record | 公开专利条目按控制、校准或结构路线登记 | 未读权利要求/说明书的条目不判定公式等价、创新性或已实现；详读条目见本地表 |
| W069 | [4. 两件式 HRG 数字控制器：](https://pmc.ncbi.nlm.nih.gov/articles/PMC4851069) | pending_fulltext | 题录已覆盖；尚不能判定具体推导与项目等价 | 未核验正文的公式、系数、实验条件，不根据题目补写方法 |
| W070 | [Interface Circuits for Readout and Control of a Micro-hemispherical Resonating Gyroscope](https://repository.gatech.edu/bitstreams/5e2a1570-b53c-4ad8-b8d6-1c4e9fe0e8fc/download) | pending_fulltext | 题录已覆盖；尚不能判定具体推导与项目等价 | 未核验正文的公式、系数、实验条件，不根据题目补写方法 |
| W071 | [ADI MT-007：孔径时间、固定延迟与随机抖动](https://www.analog.com/media/en/training-seminars/tutorials/MT-007.pdf) | background_or_tutorial | 产品/原理/转换器基础参考 | 不是独立完整WA推导；不能用作本项目性能证据 |
| W072 | [ADI MT-229：理想ADC量化噪声推导](https://www.analog.com/media/en/training-seminars/tutorials/MT-229.pdf) | background_or_tutorial | 产品/原理/转换器基础参考 | 不是独立完整WA推导；不能用作本项目性能证据 |
| W073 | [5. Safran HRG Crystal/Onyx：](https://www.safran-group.com/news/safrans-hrg-crystaltm-and-onyxtm-revolution-high-performance-naval-inertial-reference-systems-2018-10-23) | background_or_tutorial | 产品/原理/转换器基础参考 | 不是独立完整WA推导；不能用作本项目性能证据 |
| W074 | [6. Ariane 6 采用 SpaceNaute：](https://www.safran-group.com/pressroom/safrans-spacenaute-navigation-system-chosen-new-ariane-6-launch-vehicle-2016-11-30) | background_or_tutorial | 产品/原理/转换器基础参考 | 不是独立完整WA推导；不能用作本项目性能证据 |
| W075 | [4. Safran SkyNaute：](https://www.safran-group.com/products-services/skynaute) | background_or_tutorial | 产品/原理/转换器基础参考 | 不是独立完整WA推导；不能用作本项目性能证据 |
| W076 | [3. Safran SpaceNaute：](https://www.safran-group.com/products-services/spacenaute) | background_or_tutorial | 产品/原理/转换器基础参考 | 不是独立完整WA推导；不能用作本项目性能证据 |
| W077 | [Self-calibration for phase shift in Coriolis vibratory gyroscope with whole-angle mode operation. Measurement.](https://www.sciencedirect.com/science/article/abs/pii/S0263224124019286) | pending_fulltext | 题录已覆盖；尚不能判定具体推导与项目等价 | 未核验正文的公式、系数、实验条件，不根据题目补写方法 |
| W078 | [Chen W et al. Dynamical analysis and unified calibration of assembly and nonlinearity errors for rate-integrating micro hemispherical gyroscope. Aerospace Science and Technology, 2026.](https://www.sciencedirect.com/science/article/abs/pii/S1270963826021589) | pending_fulltext | 题录已覆盖；尚不能判定具体推导与项目等价 | 未核验正文的公式、系数、实验条件，不根据题目补写方法 |
| W079 | [5. HRG 历史和空间应用：Rozelle, *From Wineglass to the Planets*.](https://www.univelt.com/book%3D1438) | background_or_tutorial | 产品/原理/转换器基础参考 | 不是独立完整WA推导；不能用作本项目性能证据 |
| W080 | [Control Scheme and Error Suppression Method for Micro Rate Integrating Gyroscopes](https://www.webofscience.com/wos/woscc/full-record/WOS:000393179500417) | pending_fulltext | 题录已覆盖；尚不能判定具体推导与项目等价 | 未核验正文的公式、系数、实验条件，不根据题目补写方法 |
