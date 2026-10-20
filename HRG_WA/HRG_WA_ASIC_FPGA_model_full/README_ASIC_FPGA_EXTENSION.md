# 半球谐振陀螺全角模式 ASIC/FPGA 数字控制接口电路仿真扩展说明

## 1. 目标

本扩展在原 `HRG_WA_sim_model_annotated` 慢变量模型基础上，增加面向最终 ASIC 数字控制接口电路和 FPGA 样机验证所需的完整行为级功能。原文件名和函数名保持不变；新增文件均以 `HRG_WA_*.m` 命名。

核心入口：

```matlab
run_HRG_WA_ASIC_FPGA_demo
```

运行后生成：

```matlab
HRG_WA_ASIC_FPGA_result.mat
```

可进一步导出 FPGA/SystemVerilog testbench 向量：

```matlab
HRG_WA_export_test_vectors('HRG_WA_ASIC_FPGA_result.mat','HRG_WA_vectors.csv')
```

## 2. 已覆盖的样机/ASIC 仿真功能

### 2.1 机械谐振子与全角模式本体

- 全角模式慢变量状态：`E, Q, theta, thetaVirt`
- 输入角速度到驻波角的 Bryan 进动
- 频率裂解 `dOmega`
- 阻尼不均匀 `dTauInv`
- 刚度主轴和阻尼主轴角度
- 驱动误差泄漏到角速度通道
- 温度导致的零偏和标度因数漂移
- 外部振动/电源噪声折算扰动

### 2.2 检测前端与 ADC 接口

- AFE 增益、偏置、串扰矩阵
- AFE 一阶带宽和相位延迟
- AFE 采样延迟线
- 前端噪声、电源噪声、振动噪声
- ADC 位宽、满量程、量化、抖动、饱和检测

### 2.3 FPGA/ASIC 数字算法

- 数字标定增益/零偏补偿
- 定点量化、定点饱和、溢出计数
- CORDIC/atan2 相位解算
- `4*theta` 相位展开
- 全角模式角度输出
- 角速度输出
- 能量 PI 控制
- 正交 PI 控制
- 虚拟进动通道
- 输出一阶平滑

### 2.4 DAC/驱动接口

- DAC 位宽和满量程
- 控制输出限幅
- DAC 量化和可选抖动
- 数字流水线延迟
- 驱动增益、偏置和噪声
- DAC 饱和计数

### 2.5 寄存器、状态机和故障管理

- 建议寄存器表：`HRG_WA_regmap.m`
- 状态机：IDLE、STARTUP、LOCK、RUN、FAULT
- data ready 状态位
- lock 状态位
- ADC/DAC/定点饱和统计
- E 异常、Q 异常、角度跳变故障检测
- 故障注入：ADC stuck、DAC 饱和、AFE 偏置、环路关闭

### 2.6 性能指标统计

`HRG_WA_performance_metrics.m` 统计：

- 最终角度误差
- RMS 角度误差
- RMS 角速度误差
- 最大角速度误差
- 能量均值和标准差
- 最大正交量
- 锁定时间
- 零速偏置
- 零速噪声
- Allan deviation
- ADC/DAC/定点饱和次数
- data ready 计数
- pass/fail 结果

### 2.7 回归覆盖测试

```matlab
HRG_WA_run_coverage_tests
```

覆盖：

- `ideal_float`：理想浮点基准
- `nominal_fixed_asic`：默认 ASIC 定点链路
- `adc_14bit_stress`：低 ADC 位宽压力测试
- `dac_saturation_stress`：DAC 满量程不足压力测试
- `temperature_ramp`：温度漂移测试
- `afe_offset_fault`：前端偏置故障注入
- `loop_disable_fault`：环路关闭故障注入

## 3. 文件说明

原有文件保持：

| 文件 | 作用 |
|---|---|
| `run_HRG_WA_demo.m` | 原慢变量机理演示 |
| `HRG_WA_params.m` | 参数表，已追加 ASIC/FPGA 扩展参数 |
| `HRG_WA_rhs.m` | 原内部 PI 慢变量状态方程 |
| `HRG_WA_output.m` | 原输出和二次解调变量合成 |
| `HRG_WA_fast_rhs.m` | 可选二阶快变量模型 |

新增文件：

| 文件 | 作用 |
|---|---|
| `run_HRG_WA_ASIC_FPGA_demo.m` | ASIC/FPGA 数字接口闭环仿真入口 |
| `HRG_WA_rhs_digital.m` | 由外部数字控制量驱动的 plant 状态方程 |
| `HRG_WA_digital_init.m` | 初始化数字控制状态 |
| `HRG_WA_digital_controller_step.m` | 单采样周期数字控制算法 |
| `HRG_WA_adc_model.m` | AFE + ADC 行为模型 |
| `HRG_WA_dac_model.m` | DAC + 驱动接口行为模型 |
| `HRG_WA_fixed_quantize.m` | 定点量化和饱和模型 |
| `HRG_WA_clip.m` | 通用限幅函数 |
| `HRG_WA_wrap_pi.m` | 相位包裹函数 |
| `HRG_WA_rk4_step.m` | 固定步长 RK4 积分器 |
| `HRG_WA_performance_metrics.m` | 性能指标统计 |
| `HRG_WA_print_metrics.m` | 指标打印 |
| `HRG_WA_allan_dev.m` | Allan 方差/偏差计算 |
| `HRG_WA_regmap.m` | ASIC/FPGA 寄存器表 |
| `HRG_WA_run_coverage_tests.m` | 覆盖测试脚本 |
| `HRG_WA_export_test_vectors.m` | 导出 FPGA 验证 CSV 向量 |

## 4. 后续建议

若要进一步靠近实际样机，还应接入：

1. 真实电容-电压转换电路参数；
2. 实际 ADC/DAC 器件模型；
3. SystemVerilog RTL 联合仿真；
4. 上位机寄存器读写驱动；
5. 转台和温箱实测数据回灌。
