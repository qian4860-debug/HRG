# HRG 全角模式数字 ASIC MATLAB V4.2

V4.2 是独立于 V4.1 的“测量可信度优先”升级版。全部 MATLAB 函数采用 `HRG_WA_v42_*` 名称，避免新旧目录同时在路径中时误调用。

当前补丁修订为 V4.2.2：ACQUIRE阶段仍采用积分器冻结的受限正向驱动或反向制动，但进入RUN时改为按HRG慢变量稳态驱动力重建PI积分器，并刷新斜率限制历史和DAC流水线，避免捕获限幅驱动残留抬高RUN窗口能量均值；同时增加性能失败子项诊断。

## 本版新增

- DPLL 有效性冻结：能量、四倍角方位矢量、AFE/ADC 饱和、定点不变量溢出或非有限数任一异常时，冻结 DPLL 积分器和 NCO 频率字；恢复首拍只重建展开锚点。
- 完整抗饱和：DPLL、能量 PI 和正交 PI 均包含条件积分、输出反算和积分限幅；E/Q 环还把控制字斜率限制及 DAC/驱动物理饱和误差反算回积分器。
- Kalman 速率估计：使用连续驻波角与驻波角速度二状态模型、创新门限、无效测量预测保持、Joseph 协方差更新和数值下限保护。
- Allan/PSD：自动选择最长连续稳定 RUN 数据段，输出重叠 Allan 偏差、无工具箱 Welch PSD/ASD、短时 ARW 估计和记录内最小 Allan 量级。
- 多种子 Monte Carlo：支持确定性种子、Q 值、频率裂解、阻尼不均匀、AFE 增益/偏置及 DAC 增益离散，输出逐样本 CSV 与 P95 汇总。
- 真实 SELFTEST：测试载波在 AFE 之前注入，经过 AFE、ADC、NCO 混频和抽取链路后同步相关；检测链路增益或正交残差不合格时进入 FAULT 并安全关断。

## 首次运行

```matlab
clear functions; % 清除MATLAB函数缓存，防止旧版路径残留。
rehash; % 刷新MATLAB路径缓存。
verify_HRG_WA_v42_install; % 确认测试、仿真、参数和噪声分析文件来自同一V4.2目录。
run_HRG_WA_v42_demo; % 运行标称闭环演示并导出MAT、CSV和六联图。
test_HRG_WA_v42; % 执行十组闭环用例、Allan/PSD功能回归和三种子Monte Carlo冒烟回归。
```

专项入口：

```matlab
run_HRG_WA_v42_noise_demo; % 运行三十秒零速记录并导出Allan偏差和PSD。
report = run_HRG_WA_v42_monte_carlo(); % 按参数表头执行正式多种子与参数离散统计。
run_HRG_WA_v42_selftest_demo(false); % 验证真实检测链路SELFTEST正常通过。
run_HRG_WA_v42_selftest_demo(true); % 阻断测试注入并验证SELFTEST失败安全路径。
```

## 人工编辑入口

只建议编辑 `HRG_WA_v42_user_config.m`。其中包含仿真时基、谐振子物理量、AFE/ADC/DAC、DPLL、E/Q 控制器、完整抗饱和、Kalman、SELFTEST、保护与回归门限、Allan/PSD 和 Monte Carlo 参数。

修改物理表头后，不应直接沿用旧控制器结论。先运行：

```matlab
u = HRG_WA_v42_user_config(); % 读取集中式用户参数表头。
p = HRG_WA_v42_params(u); % 执行单位转换、派生量更新和一致性检查。
[~, suggestion] = HRG_WA_v42_autotune(p, false); % 只计算DPLL、E环和Q环解析初值。
disp(suggestion); % 审阅量程、延迟、展开和增益建议。
```

详细顺序见 `HRG_WA_V42_参数与控制器修调指南.md`。

## 文件说明

- `HRG_WA_v42_simulate.m`：HRG 慢变量、AFE/ADC、数字控制、Kalman、SELFTEST、DAC 和状态机闭环模型。
- `HRG_WA_v42_metrics.m`：RUN 有效窗口、测量有效率、功能/性能/故障/SELFTEST 分层判据。
- `HRG_WA_v42_noise_analysis.m`：重叠 Allan 偏差和 Welch PSD/ASD。
- `run_HRG_WA_v42_monte_carlo.m`：多种子与器件参数离散统计。
- `HRG_WA_v42_regmap.m`：50 个 32 位 APB/AXI-Lite 建议寄存器描述。
- `HRG_WA_v42_export_vectors.m`：含冻结、无效原因、抗饱和、Kalman 和 SELFTEST 字段的 RTL 对拍 CSV。
- `test_HRG_WA_v42.m`：十组闭环回归、Allan/PSD 功能回归和 Monte Carlo 冒烟回归。

## 关键判读

- `measurementInvalidReason`：bit0 低能量、bit1 低方位矢量、bit2 AFE/ADC 饱和、bit3 定点溢出、bit4 非有限数。
- `pllFreezeCount`：无效测量期间 DPLL 实际冻结的控制拍数。
- `antiWindupCount`：任一条件积分、输出反算、斜率跟踪或执行器饱和跟踪动作次数。
- `actuatorTrackingCount`：后级斜率限制或 DAC/驱动物理饱和反算次数。
- `fixedOverflowCount`：只统计真实 Q 格式超范围，不把正常控制限幅混入。
- `kalmanRejectCount`：测量有效但创新超过门限而拒绝更新的次数。

默认误差阈值是软件回归门限，不是产品指标。本模型用于公开理论下的系统方案、控制极性、接口、字长和 RTL 对拍规划，不能替代真实谐振子辨识、长时零偏试验、PVT、硬件在环、转台和温箱验收。

## V4.2.2 能量入口可信度修正

本修正版在 ACQUIRE 进入 RUN 的瞬间不再把捕获阶段的限幅能量驱动直接继承到正常运行窗口，而是按公开 HRG 慢变量稳态方程重建能量环与正交环积分器初值，并同步刷新控制字斜率限制历史和 ASIC 到 DAC 的短流水线。这样可以避免 RUN 有效统计窗口内 `energyMean` 被捕获驱动残留抬高，保持“有限开环启动、完整抗饱和、测量可信度门控、Kalman 速率估计、SELFTEST 与 Monte Carlo 回归”这一套验证逻辑不变。
