# RTL修订与Scoreboard验证

日期：2026-10-16。基线：Git `c61523f`。本次范围按用户确认，完成前端、控制与导航闭环；不实现在线 RLS/EKF、Kalman 或 FRP 训练。

## 结果

| 验证层 | 实际场景/数量 | 结果 |
|---|---|---|
| 原MATLAB前端逐码参考 | 350笔×9字段；15330驱动时钟 | 0差异；基线1698处差异全部消除 |
| 控制器基本scoreboard | 2055笔update | 0错误 |
| CORDIC数学参考 | 132笔；四轴/全象限/忙时输入/复位中止 | 0错误；误差≤64相位码 |
| PI完整抗饱和 | 5000组；独立整数参考+原MATLAB `local_pi_aw` | 整数逐码一致；原MATLAB最大差1个Q30 LSB，门限4 LSB |
| DPLL | 6000时钟向量；启停/有效性/冻结/饱和/基准FCW变化 | 0错误 |
| 导航 | 6000时钟向量；相位跨周/恢复/异常跳变/虚拟进动/滤波/清零 | 0错误 |
| 控制器扩展 | 3200时钟向量；模式/斜率/反算/执行器跟踪/RUN入口 | 0错误 |
| 顶层集成scoreboard | 182889驱动时钟、4000控制输出、4000导航输出 | 逐时钟0错误 |
| 原有SPI/载波smoke | nav=400，E=16777440，phase4=3436527 | PASS |
| 负向对照 | 故意破坏首拍Cx期望值1 LSB | 比较器捕获并fatal，之后恢复文件原始字节 |
| Vivado RTL综合展开 | `synth_design -rtl` | 0错误、0严重警告、34普通警告 |

`results.json` 保存机器可读结果和源码/向量SHA256。`simulation.log`、`loop_simulation.log`、`top_scoreboard_simulation.log` 保存对应XSim原始结果；`detection_simulation.log` 中的fatal是负向对照的预期结果。

已提交的原始日志快照位于 `evidence_20261016/`，后续运行不会覆盖这些版本记录。`golden_provenance.json` 同时记录原MATLAB源码、参数、适配器、ADC/PI输入和黄金输出的规范化文本哈希；使用保存向量前会检查，输入或模型改变时必须重新运行MATLAB导出，不能继续套用旧期望值。

## 实现变化

1. `hrg_nco.v`：用40级组合旋转CORDIC替代象限中点ROM，32位完整相位、18位幅值码、幅值分母131071；混频使用推进后的同一有效样本参考。RTL中没有 `real`、`$sin` 或 `$cos`。常量生成器为 `generate_nco.py`。
2. `hrg_dsp_core.v`：三级积分器同样本级联更新，梳状器读取新末级积分状态；CIC归一化与FIR历史采用Q26，解调Q22，不变量Q24；最近舍入、半LSB远离零，与原模型的对应函数一致。
3. `hrg_pi_aw.v`：独立的抗饱和PI数据通路。实现候选积分限幅、条件积分冻结、反算泄放、最终积分限幅和最终命令重算。积分器为未乘Ki的40位Q30，不再用旧版Q22加权贡献量代替。
4. `hrg_controller.v`：双PI、能量2/s与正交4/s斜率限制、斜率反算跟踪、执行器饱和反馈跟踪、三控制拍命令流水线。STARTUP开环驱动0.35，ACQUIRE能量窗口外受限驱动，RUN入口按保持驱动重建积分器并刷新能量/正交流水线。全局禁用在下一control update清空待执行命令。
5. `hrg_dpll.v`：相位误差 `-L/max(E,0.08)`，Kp=8、Ki=35，积分贡献限幅800 Hz、校正限幅1200 Hz、反算增益12/s。无效测量冻结积分器和FCW，有效后继续更新。校正叠加到配置基准FCW。
6. `hrg_navigation.v`：24位模相位差展开、四倍角除4、Bryan系数转换、实际交付虚拟进动抵消、45 Hz一阶速率低通。测量无效时冻结并撤销相位锚点，恢复首拍重新锚定，不积分失效期间未知位移；超过0.8π的单拍四倍角变化产生unwrap fault并冻结该拍。输出valid与角度/速率同沿更新。
7. `hrg_sensor_if_top.v`：接通DPLL→FCW反馈；增加可选250 ms STARTUP和至少500 ms ACQUIRE的硬件状态机，满足E/Q/PLL锁定条件才进入RUN；测量有效性改为R/S矢量幅值判断。DAC最近舍入并饱和到signed16位，回算实际交付量用于控制与导航。快照数据使用同一笔测量及新状态，避免读取上一笔status。

## 数值与接口合同

控制率固定1 kHz，ADC有效采样率40 kS/s，抽取R=40。valid空洞表示系统时钟中没有新的ADC采样；不能借此改变物理采样周期后仍沿用1 kHz的控制/导航比例。

| 数据 | 格式/单位 |
|---|---|
| ADC | signed18，Q2.16 |
| NCO | signed18幅值码/131071；phase为unsigned32 binary turn |
| 混频、CIC | Q24；CIC寄存器96位 |
| FIR中间量 | signed34 Q26 |
| Cx/Sx/Cy/Sy、控制命令 | signed28 Q22 |
| E/Q/R/S/L | signed32 Q24 |
| PI积分器 | signed40 Q30，未加权误差积分 |
| 角度输出 | signed48 Q24，度 |
| 速率输出 | signed32 Q16，度/秒 |
| 虚拟进动命令与实际反馈 | signed28 Q22，弧度/秒 |
| Bryan系数 | unsigned32 Q30，默认0.277 |
| 内部导航累加/滤波 | 度Q40、度/秒Q32 |

角度/速率接口从旧版“相位码/相位码每秒”改为明确的度和度/秒；下游软件必须按新格式解码。

SPI page0新增字段：CTRL bit4使能DPLL，bit5使能硬件状态机。完整闭环使用CTRL=`0x3F`；原`0x0F`保留软件管理模式和固定FCW路径。硬件状态机配置应同时开启DPLL。

| 字节地址 | 名称 | 编码 |
|---:|---|---|
| 0x54 | ENERGY_HOLD | signed Q22，零选默认0.015708，RUN入口能量保持驱动 |
| 0x58 | QUAD_HOLD | signed Q22，零为字面零，RUN入口正交保持驱动 |
| 0x5C | BRYAN | unsigned Q30，零选0.277 |
| 0x60 | RATE_ALPHA | bits30:0 unsigned Q30，零选45 Hz默认值 |

保持驱动由器件标定配置提供；默认仅补偿标称平均阻尼。这里没有自动计算完整模型的角度相关机械稳态前馈。PI和DPLL常数及更新率固定在当前硬件配置，不支持任意改采样率后自动重整定。温度与谐波补偿、Kalman和在线辨识均不参与本轮直接导航配置，因此不宣称完整MATLAB系统逐码等价。

## 独立参考与闭环轨迹

前端仍由原 `HRG_WA_v46_simulate.m` 的NCO/CIC/FIR/不变量/定点函数原样提取生成黄金值；没有修改原模型，也没有从DUT内部状态生成期望值。PI黄金值也直接调用原模型的 `local_pi_aw`。固定点PI与原浮点函数的差异来自显式Q30量化，允许界限为4 LSB，本轮最大1 LSB。

`loop_reference.py` 另外定义硬件固定点合同；`generate_loop_vectors.py` 用独立浮点PI方程及物理导航换算交叉检查。导航最大数值差为2.983×10^-8度、7.627×10^-6度/秒；这是相同测量下的格式误差，不含传感器误差。

`generate_top_vectors.py` 将独立整数链路与一个名义慢变量plant耦合，生成ADC输入和每时钟期望值，再由顶层scoreboard通过真实SPI管脚配置后回放。期望值不依赖DUT输出；DUT每一拍的DAC、导航valid/角度/速率/status及FCW/模式计数均与参考比较。因为每一步反馈输出均一致，该轨迹验证了所测场景的闭环连接与延迟；它不是硬件在环或独立器件实测。

4秒场景使用5001.5 Hz载波、初始E=0.25、Q=0.015，1.5秒后输入80度/秒；中间包含400个ADC样本的检测信号中断。状态机1.413秒进入RUN，覆盖全部三状态和失效恢复。结束时参考plant E=0.975053、Q=-8.48×10^-6，RTL恢复速率79.914627度/秒，NCO为5001.499988 Hz。plant采用名义平均阻尼、无噪声、无各向异性和频率裂解；不代表完整误差模型的导航性能。

## 复现

在本目录执行：

```powershell
# 默认从当前原MATLAB源码重新导出参考值，并依次完成全部验证和RTL展开。
./run_all.ps1

# 使用已提交的MATLAB黄金向量；其余向量重新生成，不需MATLAB。
./run_all.ps1 -UseSavedMatlabVectors

# 分项入口
./run_scoreboard.ps1 -SkipGeneration
./run_loop_scoreboard.ps1
./run_top_scoreboard.ps1
./run_top_smoke.ps1
./verify_scoreboard_detection.ps1
```

Vivado默认目录为 `D:\vivado\2025.1\Vivado\bin`，MATLAB默认 `D:\matlab\bin\matlab.exe`；均可通过参数指定。若环境不允许启动完整Vivado，可用 `-SkipElaboration` 复用已有展开记录，但摘要仍要求该记录存在且通过。严格脚本检查fatal文本，不能仅凭工具退出码判断成功。

## 验证边界

前端350笔逐码一致是有限动态测试结果，未证明全部32位相位、任意输入序列、96位CIC长时溢出和所有参数组合的形式等价。40级组合NCO及宽除法器已通过RTL综合展开，但尚未做完整映射、面积功耗优化、STA或布局布线；展开检查的示例FPGA型号仅用于工具加载，不是选定产品平台。34条普通警告主要为过程临时变量/未输出计数器优化及原SPI模块未使用端口。

SPI原协议文件保持不变；本轮覆盖真实SPI写CTRL与数据路径，未覆盖所有配置字段读回、跨页与CRC压力场景。第二套64 kS/s旧RTL保持原状，可通过Git追溯。本轮没有把它改成另一份重复的当前实现。
