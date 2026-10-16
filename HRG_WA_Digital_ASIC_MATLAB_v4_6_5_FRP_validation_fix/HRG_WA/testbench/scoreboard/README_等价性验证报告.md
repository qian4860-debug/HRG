# RTL 与 MATLAB 模型等价性验证

日期：2026-10-15。工具：MATLAB、本机 Vivado XSim 2025.1、Python 标准库。

## 结论

**当前 RTL 不与 V4.6.5 完整 MATLAB 模型等价；即使只限定到相同 ADC 输入的数字解调前端，也没有达到逐码等价。**

本轮新增了可执行的 SystemVerilog scoreboard，实际运行事件驱动仿真。没有修改现有 RTL、MATLAB 算法、原有 testbench 或验收门限。

| 检查 | 本轮实际结果 | 能支持的结论 |
|---|---|---|
| DSP 整数实现参考，逐时钟比较 | 15330 个驱动时钟、350 笔抽取输出，0 错误 | 测试场景下 RTL 符合独立 Python 整数参考所定义的现有实现语义 |
| PI 整数实现参考 | 2400 个驱动时钟、2055 笔 update，0 错误 | 测试场景下的条件积分、限幅、使能及三拍命令延迟一致 |
| CORDIC 数学参考 | 132 笔，0 错误 | 所测幅度/象限内角度误差≤64 个 24-bit 相位码，18 拍延迟及忙时拒收正确 |
| MATLAB 前端模型参考 | 350 笔×9字段；192 笔有差异、1698 个字段不一致 | 严格逐码等价失败 |
| 原有顶层 SPI/相干载波 smoke test | PASS：nav=398，E=16777252，phase4=3436527 | 原有有限场景仍能运行；不能代替模型等价检查 |
| Scoreboard 负向对照 | 故意把首拍期望 Cx 改大 1 LSB，成功捕获并 `$fatal` | 比较器和失败出口实际生效；脚本在 finally 中恢复向量原始字节 |

`IMPLEMENTATION_SCOREBOARD_PASS` 与 `MATLAB_EQUIVALENCE_FAIL` 可以同时出现：前者检查已实现的整数语义，后者检查原始 MATLAB 规格。前者不构成模型等价证明。

## 阅读材料及版本选择

已查看“全角陀螺”目录中的资料索引、白皮书，以及已有数字 ASIC 论文文本提取中关于 NCO、PI、CORDIC 的相关段落，并对照当前模型、两套 RTL 和旧审计记录。未逐页重读所有论文及专利。

| RTL 目录（相对项目根目录） | 主要配置 | 与当前模型的关系 |
|---|---|---|
| `HRG_WA_Digital_ASIC_MATLAB_v4_6_5_FRP_validation_fix/HRG_WA/src` | ADC Q2.16；40 kS/s；5 kHz；R=40；解调 Q6.22；不变量 Q8.24 | 本次 scoreboard 的实际 DUT |
| `hrg_wa_verilog_rtl_tb_full_frontend_annotated_fix_qparam/rtl` | ADC Q1.15；64 kS/s；8 kHz；R=64；数据 Q2.30 | 另一个实现合同，不能直接对拍 V4.6.5；本轮进行源码对照，未为其声称新增仿真覆盖 |

第二套 RTL 的 `hrg_fir5_lpf.v` 为 `[1 4 6 4 1]/16`，当前模型为 `[1 2 3 2 1]/9`，已经存在实质传递函数差异。其旧 RAW 闭环记录也不能作为等价证明。

## 已定位的不一致

以下行号均相对于当前未修改源码。

1. **NCO 相位与混频对齐不同。** MATLAB `HRG_WA_v46_simulate.m:272` 先调用 `local_integer_nco_step` 推进相位，再用新参考混频。RTL `hrg_nco.v:27` 在同一上升沿以非阻塞赋值更新参考；`hrg_dsp_core.v:38` 的乘积在该沿使用旧参考，相差一个有效 ADC 样本。MATLAB 用完整相位的 sin/cos 并以 131071 归一化，RTL 使用象限内64段中点 ROM 和 Q1.17 缩放，另有量化差异。
2. **CIC 级间递推不同。** MATLAB `HRG_WA_v46_simulate.m:339` 用本次更新后的前一级积分器继续更新后一级；RTL `hrg_dsp_core.v:98` 三个积分器使用前一拍状态，抽取时梳状器也读取更新前的 `int2`。这会改变脉冲响应和数据延迟，不能仅凭直流增益一致判为等价。
3. **舍入及中间格式不同。** MATLAB 的 `local_fixed` 为最近舍入+饱和；CIC 归一化和 FIR 使用34位/26小数位，之后解调量再量化到28位/22小数位。RTL 混频采用算术右移，除法向零截断，再右移；归一化历史使用32位寄存器。不变量最终也直接右移截断。当前未定义二者的位级统一合同。
4. **PI 只有简化实现。** 模型 `local_pi_aw` 含积分器限幅、条件积分后的重新计算、反算泄放；外围还包含模式切换、斜率限制与执行器跟踪。RTL `hrg_controller.v` 实现条件积分和命令限幅，积分器为 Q22 贡献量，未实现上述完整行为。因此本轮 PI PASS 仅对应整数实现参考，未把它标为 MATLAB PI 等价。
5. **系统功能不齐。** 当前 `hrg_sensor_if_top.v` 的 NCO FCW 来自配置，未接入模型的 L→DPLL→FCW 闭环；导航部分直接将四倍角差除4并乘1000，未实现模型中的 Bryan 系数、虚拟进动抵消、Kalman、温度/谐波补偿和 RLS/EKF/FRP。RTL README 本身也将若干高级算法排除在综合边界外。
6. **顶层接口仍需独立验收。** `nav_valid_o` 直接连接 CORDIC valid，而 angle/rate 在下一时钟由该 valid 更新；使用者必须明确数据与valid的合同。无效测量恢复时，模型重新建立相位锚点，当前 RTL 仍保留旧相位。这里只记录源码风险，本轮没有宣称这些场景已被顶层 scoreboard 覆盖。

首次差异出现在第41笔输出（前40笔为零输入）：

| 字段 | RTL | MATLAB | 差值/LSB |
|---|---:|---:|---:|
| Cx | 10237 | 8444 | 1793 |
| Sx | 125 | 8444 | -8319 |
| E | 124 | 170 | -46 |
| L | 3 | 170 | -167 |

这是零输入后的脉冲响应，起始状态、ADC码和 FCW 相同；差异不能归因于机械模型或随机噪声。完整逐笔数据见 `dsp_comparison.csv`。全部场景最大绝对误差：Cx=1093912 LSB、Sx=2681738 LSB、E=548646 LSB、L=14078464 LSB。解调字段使用22小数位，不变量使用24小数位，不能直接跨字段比较 LSB 数。

## Scoreboard 结构

`generate_vectors.py` 使用固定种子465生成 ADC 驱动及独立整数期望值；不读取仿真输出或 RTL 内部状态。刺激覆盖零输入、单脉冲、正负直流、相干双通道正弦、ADC极值、随机输入、可变FCW、相位回卷、valid空洞、连续valid和中途复位。PI 场景覆盖各使能组合、正负误差、小误差积分、饱和/退出饱和、负增益及更新空洞。

`export_model_vectors.m` 是自动生成的 MATLAB 适配器。其 NCO/CIC/FIR/不变量/定点函数从当前 `HRG_WA_v46_simulate.m` 原样提取；参数从 `HRG_WA_v46_params()` 读取。适配器将同一 ADC 码除以2^16、按 FCW 配置相同 NCO 频率，每40个有效样本调用原模型抽取并导出四个解调量和五个不变量。原模型内的机械、AFE、ADC噪声及闭环控制没有参与这个前端隔离实验。

`tb_hrg_scoreboard.sv` 以驱动时钟的下降沿给输入、上升沿之后比较输出，避免 NBA 竞争。前端逐时钟检查 valid、phase、wrap、overflow、全部9字段及无valid时保持行为；期望valid驱动模型文件消费，可检测丢包和重复输出，不会通过跳过错误输出自动重新对齐。CORDIC 检查四轴、全部象限、busy期间start及复位中止；使用独立 atan2 数学参考并按相位周期计算误差。

## 运行

在本目录打开 PowerShell：

```powershell
# 完整生成向量并运行严格模型等价检查：当前会失败，这是本次发现。
./run_scoreboard.ps1

# 使用已交付向量复现严格结果，无需重新启动 MATLAB。
./run_scoreboard.ps1 -SkipGeneration

# 仅将整数实现检查作为通过条件，仍打印 MATLAB_EQUIVALENCE_FAIL。
./run_scoreboard.ps1 -SkipGeneration -ImplementationOnly

# 原有顶层 smoke test。
./run_top_smoke.ps1

# 必须先编译 scoreboard；此脚本验证比较器的错误检测能力。
./verify_scoreboard_detection.ps1

# 汇总并记录源码/向量SHA256；需先生成各份日志。
python analyze_results.py
```

默认使用 `D:\matlab\bin\matlab.exe` 及 `D:\vivado\2025.1\Vivado\bin`，可通过脚本参数修改。脚本检查仿真日志中的 `$fatal` 和显式 PASS 标记，避免 XSim 在 `$fatal` 后仍返回0造成误报。

## 交付与验收边界

- `simulation.log`：严格检查失败记录；`implementation_simulation.log`：整数实现检查通过记录。
- `top_simulation.log`：原有 SPI/顶层 smoke 记录；`detection_simulation.log`：负向对照失败记录（这是预期行为）。
- `results.json`：机器可读汇总和源码/向量 SHA256；`manifest.json`：刺激规模与生成器种子。
- `dsp_comparison.csv`：3150 行实际RTL/原模型字段对比。

本轮为有限场景的动态验证，未做形式等价证明、综合/STA/CDC签核、SPI读回/CRC压力测试，亦未证明机械闭环和导航性能。CORDIC未穷举32位全范围，DSP overflow仅在这些合法输入下检查为0，未覆盖所有参数组合。第二套64 kS/s RTL没有新增位级scoreboard。

要使现有RTL达到模型等价，下一步应先冻结综合边界和逐级格式/舍入/饱和/valid/群延迟合同，再统一NCO和CIC语义并补齐所需闭环。当前默认严格回归保留失败，可作为后续修正的验收基线。
