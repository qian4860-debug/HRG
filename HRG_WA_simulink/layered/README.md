# 全角 HRG 分层闭环 Simulink 模型

本目录在原 `HRG_WA_simulink` 数学模型上增加机械—模拟接口—数字控制—驱动的真实反馈路径。参考 `thx_gyro_simulink2024` 的分层、逐步加入误差、批量运行方法，以及用户提供的开题报告和博士论文的方法。原模型及原 MATLAB 算法源文件保持独立。

## 运行

已在 MATLAB R2025a、Simulink、DSP System Toolbox 上运行。进入本目录后：

```matlab
addpath(pwd)
wl_demo(5)                 % 构建、运行 2 秒，并打开模型及选定观察窗口
```

窗口修复版建议在 MATLAB 桌面命令窗口执行：

```matlab
out = wl_demo(5);          % 分号避免打印整个 SimulationOutput
```

入口现在使用独立的内存模型 `hrg_wa_v5_demo`；桌面模式让库 Scope/Spectrum 在仿真开始时打开，避免结束后才打开导致无缓存可回放。演示不保存或打印模型文件，保留原 V5 文件，并避免模型导出图时的临时窗口闪现。结束后自动打开普通 MATLAB Figure 结果回放窗口，含 19 个信号页签；载波页显示原采样率波形及 PSD，导航页分开显示角度、角速度和有效标志。可随时重新打开：

```matlab
wl_view_results(out_layered,wl_demo_configuration);
```

`ErrorMessage` 为空、各 `tap_*` 为 timeseries 说明仿真正常完成；`ans = SimulationOutput` 是函数返回值。旧模型的零延迟 Transport Delay 提示不代表实际存在代数环；新构建模型在零 skew 时直接连通，不增加 Memory 延迟。非零 skew 保留真实因果延迟，`wl_sim` 在 skew 符号跨零时自动重建相应路径。

若使用 `matlab -batch`，整个 MATLAB 进程退出时所有图窗都会关闭，这是进程生命周期；桌面调用不需要额外等待。窗口修复验证见 `evidence/demo_window_fix/`。历史清单分别对应 `b1c2a77` 和 `04050e4`，不覆盖重写；当前版本使用 `python tools/verify_spectrum_fix.py` 综合验证历史及增量证据。

频谱观察修复版已给全部 16 个 Spectrum Analyzer 配置独立 `Spectrum_Sample_*` 采样保持支路。驱动/机械/模拟节点按 400 kHz，ADC/混频按 40 kHz，控制 IQ 按 1 kHz 采样后送入仪器；Scope、日志及原反馈仍直接观察原节点。设置频谱仪的显示采样率不能代替这个离散接口。

电压在线功率谱使用 **dBV**；归一化在线谱使用 **dBFS，参考值固定为 1**，不代表 ASIC 的实际满量程。在线谱默认看第一通道。回放窗口的 PSD 使用实际采样率及 `V²/Hz` 或对应归一化平方/Hz；计算去均值但保留趋势，不宣称已隔离噪声。IQ 页增加 `E` 与 `Q/E` 检查，并明确其低频谱主要包含驻波进动。默认约 0.123 Hz 的 IQ 慢变不能靠 2 s 数据充分分辨，调小显示 RBW 或补零不能替代增加有效观测时长。

更新后执行 `clear wl_build wl_view_results wl_native_psd; out=wl_demo(5);` 重建临时模型。原 V5 文件及开工前修改均保留；保存的短时验收模型是 `models/hrg_wa_v5_spectrum_fixed.slx`。编译采样时间、单位、逐点闭环等价性及 PSD 归一化验证见 `evidence/spectrum_fix/`。复查前先运行 `python tools/verify_spectrum_fix.py --prepare-baseline` 导出历史基准，再在 MATLAB 中运行 `wl_validate_spectrum`。

直接打开 `models/hrg_wa_v5.slx` 会初始化模型随附的 V5 配置；按 Run 运行。各模型保存自己的时钟及工况配置，避免 1bit 等专用模型被普通默认参数覆盖。双击各子系统查看信号流及 `Scope_*`、`Spectrum_*`。频谱仪默认看向量第一路，通过前置 Selector 可换另一通道。导航、控制量和诊断量含不同单位，仅配时域观察。

批量验证入口：

```matlab
wl_validate_algorithms    % 原算法核与独立参考计算的 scoreboard
wl_validate_models        % V2—V6、独立机械解、观察仪器一致性、ADC 过载及 1bit 转换器
wl_run_sweeps             % 27 个单因素工况 + 3 个独立随机种子
wl_run_joint_candidates   % 上述筛查后的 Rf × 输入电流噪声，6 个联合假设工况
wl_algorithm_study        % 长时间在线更新、FRP 训练/冻结验证及基带频响
wl_architecture_study     % 连续/时分驱动 × 有/无寄生馈通，4 个配对工况
```

载波模型使用 400 kHz 固定步长求解、40 kHz ADC/DAC、1 kHz 控制。正常模式下含多个解释执行算法块，批量运行比包络模型慢。执行脚本会重建对应模型及更新 `evidence/`；原验收结果可通过 Git 标签恢复。

## 递进版本

| 版本 | 增加的功能 | 用途 |
|---|---|---|
| 原 V1 | 原载波与慢变包络数学模型 | 数学符号、Bryan 系数和基本闭环对照 |
| V2 | 库模块构成双积分机械头、理想电容检测、NCO/IQ、PI 抗饱和、驱动与导航 | 建立闭环基准，独立矩阵指数检查机械方程 |
| V3 | 机械各向异性、能量频移、电容非线性、C/V/PGA/抗混叠极点、噪声、采样及转换误差、驱动极点/压摆/限幅 | 分配模拟和转换器指标 |
| V4 | IQ/控制量定点格式、控制流水延迟、ADC 过载污染传播与有效性门控 | 数字链路时序与接口质量 |
| V5 | 原 Kalman、RLS、参数 Kalman、FRP 算法核及新观测接口 | 算法嵌入、训练/应用分离；默认只开导航 Kalman |
| V6 | 整载波周期交替驱动、2 倍有效时段幅度、寄生电馈通 | 候选系统结构的配对对照实验 |

V3 不是只有模拟误差：也承接表头配置中的机械和装配非理想。V5 默认关闭在线辨识、矩阵补偿与 FRP；用显式开关开启，避免未经辨识验证的系数直接改变控制。

V6 当前实现的是周期驱动门控，检测连续运行。它没有实现完整的驱动/检测隔离及读出消隐；门控窗的平均增益为 1，因此馈通的载频分量仍可保留。若继续研究时分隔离，需要增加与 ADC/DAC 延迟对齐的检测窗口和边沿消隐，并重新校准与验收。

`hrg_wa_v5_envelope.slx` 是长时间算法研究加速模型。它使用窄带接口等效量，不产生 ADC/DAC 载波波形；不能用它验收混叠、位流、谐波或转换器 SINAD。`*_sweep`、`*_free`、`*_overrange`、`*_bitstream`、`*_architecture` 是对应验收工况模型。

## 参数如何修改

机械默认参数继续由原 `wa_parameters` 读取集中表头配置 `HRG_WA/config/head_default.json`。质量、间隙、电容、偏置电压、噪声及接口位宽等研究参数集中在 `wl_config.m`；均标为假设值。新接口行为参数尚不等于已分配的 ASIC SPI 寄存器。

建议复制配置而不是修改模型内部数值：

```matlab
c = wl_config(5);
c.name = 'hrg_my_head';
c.massKg = 1e-6;             % 用实测/设计值替换
c.gapM = 5e-6;
c.c0F = 1e-12; c.cfF = 1e-12;
c.cvInArtHz = 1e-15;
c.duration = 1;
[out,c] = wl_sim(c,true);    % 修改结构、时钟或观察设置后显式重建
wl_metrics(out,c)
```

更改 ADC/DAC 架构、无限带宽与有限带宽的切换、CIC 级数、温度扰动结构或观察模块后必须重建。普通扫参应保留已建结构，`wl_sim(c,false)` 会在加载后再次应用配置，避免模型打开回调覆盖工况。改变实际极点、延迟、增益时，默认保留标称相位/虚拟旋转增益校准，用于暴露设计裕量；若模拟重新标定，必须明确重新计算并记录校准常数，不能悄悄使用被仿真表头真值。

实测尚不充分时先测 `f0/Q/Bryan`、位移—电容增益、质量或力系数、频差/阻尼差、各模拟传递函数及噪声。未知项应保留假设标记，扫范围，不应从一次仿真给出唯一电路指标。

## 信号观察与设计要求

19 个节点同时输出完整向量时域日志、Scope；其中 16 个同单位节点有真正库内 Spectrum Analyzer。载波、ADC 和控制节点按各自采样率处理。

| 位置 | 观察对象 | 对应设计决策 |
|---|---|---|
| Mechanical_Head | 位移、速度 | 模态幅度、能量、正交与稳定性 |
| Capacitive_CV_PGA_AA | 理想 C/V、实际 C/V、PGA、抗混叠输出 | 输入等效噪声、带宽、动态范围、馈通、限幅 |
| ADC_Clock_Conversion | 采样保持、实际转换输出 | 位宽、满量程、INL、孔径抖动、通道时间偏差、延迟 |
| NCO_IQ_CIC_FIR | 混频、抽取、FIR、最终 IQ | 载波抑制、噪声折叠、群延迟、定点精度 |
| Discrete_PI / Algorithms | 控制量、导航、更新数/置信度/有效性 | 环路裕量、无效样本门控、辨识覆盖、补偿是否有益 |
| DAC_Driver_Force | 请求值、DAC、实际驱动、反馈力 | DAC 位宽、建立时间、压摆率、输出摆幅、执行延迟 |

`evidence/v*_nominal/` 保存节点采样率、波形 CSV、单通道单边 Hann PSD、配置、导航及接口误差和信号流图。载波 CSV 保留最后 8 个周期的原采样点，图中放大最后 4 个周期，避免任意抽点造成展示混叠；低速 IQ/导航保存全程。PSD 使用有限长度窗口且去均值，不能据此宣称偏置不稳定性或 ARW。

`wl_run_sweeps` 中预算是可修改的研究示例，默认角速度误差标准差 0.1°/s、均值 0.25°/s、ADC 误差 20 µV、能量 0.8—1.2 且不削顶。单因素通过不代表联合角落通过。实际设计应先替换系统指标，再增加带宽—噪声—增益—延迟联合角落及 PVT 工况。

## 算法嵌入与边界

`legacy/wl_legacy.m` 中原函数体逐字提取自 V4.6.5，`legacy/provenance.json` 记录来源与哈希。新适配器只读取实测 IQ、温度、已知执行命令、外部标定许可和 ADC 过载标志；表头真值仅供模型物理接口和 scoreboard 使用。

原 Kalman/PI/RLS/参数 Kalman/FRP 核心已被真实调用。在线阻尼/频差辨识采用针对当前复包络方程重新推导的观测适配；原代码中的参数滤波器不能因此被称为已完整复现另一套非线性 EKF。检测矩阵自校准仍受可辨识性限制，普通全角运动不能保证分离所有机械与读出误差，默认不应用。

FRP 训练需要同时设置 `calibrationPermit` 和 `zeroRateCertified`，模拟专用零速标定工装。生产运行冻结系数并撤销许可。`wl_algorithm_study` 分别报告真实闭环训练活动、冻结不变和留出工况误差；改善与否按结果报告。合成数据上算法核正确不等于在真实表头上标定有效。

此模型是行为级研究工具。CIC 是归一化 boxcar 级联等效，PI/IQ 有指定舍入而非整套 RTL 位真值；ΣΔ 分支是真实一阶泄漏 1bit 反馈位流，不是论文四阶 CIFF；未建立晶体管噪声全频谱、伪电阻完整 PVT/非线性、自激启动专用状态机、开关电荷注入及全套 RTL/模拟网表联合验收。后续电路设计应逐步替换对应子系统并保持相同接口与记分板。

方法与文献页码见 [docs/methodology.md](docs/methodology.md)。实际验收结果与结论见 `evidence/` 和 [docs/results.md](docs/results.md)。

最终交付后，用 Python 依次执行 `tools/audit_native_waveforms.py`、`tools/write_results.py`、`tools/seal_evidence.py` 可重新整理和封存已生成证据；`tools/seal_evidence.py --verify` 只做完整性验证。封存前应先完成上面的 MATLAB 运行，不能用旧报告代替新工况验收。
