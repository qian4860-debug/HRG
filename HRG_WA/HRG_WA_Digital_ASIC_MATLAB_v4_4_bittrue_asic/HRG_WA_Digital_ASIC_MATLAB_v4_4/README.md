# HRG_WA 全角模式数字 ASIC MATLAB 行为级模型 V4.4

本版本在 V4.3.1 在线标定安全释放通过版本基础上，加入位真 ASIC 数据通路建模。V4.4 默认仍保持原 V4.3.1 等效定点路径，新增 `bittrue_asic` 专用回归用例打开 CIC/FIR、整数 NCO、迭代 CORDIC、每级 Q 格式、流水线 valid、CDC 同步和 SPI 事务模型，从而在不破坏既有闭环、SELFTEST、在线标定和 Monte Carlo 判据的前提下验证硬件化数据链路。

运行：

```matlab
clear functions;
rehash;
test_HRG_WA_v42;
```

主要文件：

- `HRG_WA_v42_params.m`：集中参数表，新增 `p.asic.bitTrueEnable`、整数 NCO、CIC/FIR、CORDIC、CDC 和 SPI 参数。
- `HRG_WA_v42_simulate.m`：多速率闭环仿真器，新增位真前端链路、整数相位累加器 NCO、CIC 抽取、FIR 补偿、迭代 CORDIC、valid 流水线、CDC 同步事务和 SPI CRC 事务模型。
- `HRG_WA_v42_metrics.m`：新增位真 ASIC 活动性统计与 `passBitTrueAsic` 判据。
- `test_HRG_WA_v42.m`：新增 `bittrue_asic` 回归用例，并保留 V4.3.1 的 `online_calibration` 用例。
- `HRG_WA_v42_regmap.m`：新增 `0x0140` 起始的位真 ASIC 诊断寄存器区。
- `verify_HRG_WA_v42_install.m`：新增 V4.4 修订号和位真函数存在性检查。
- `V4.4_位真ASIC功能说明.md`：说明新增硬件链路、寄存器映射和验证方式。

注意：本代码仍为 MATLAB 行为级和位真近似模型，用于论文建模、算法验证、RTL 规格推导和 ASIC 接口规划；真实器件指标仍需 RTL 对拍、门级仿真、硬件在环、温箱和转台实验确认。
