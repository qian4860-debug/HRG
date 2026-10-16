# HRG_WA 全角模式数字 ASIC MATLAB 行为级模型 V4.3.1

本版本在 V4.2.2 能量入口可信度修复基础上加入在线标定，并在 V4.3.1 中增加“只辨识、缓释补偿”的安全释放逻辑：检测/驱动矩阵、正弦自激同步解调、RLS/EKF、阻尼不均匀辨识、模态匹配和安全系数更新。基础十组回归默认保持在线标定旁路关闭，新增 `online_calibration` 用例专门验证 V4.3.1 链路。

运行：

```matlab
clear functions;
rehash;
test_HRG_WA_v42;
```

主要文件：

- `HRG_WA_v42_params.m`：集中参数表，新增 `p.calib` 与 `p.drive.crossMatrix`。
- `HRG_WA_v42_simulate.m`：多速率闭环仿真器，新增在线标定总调度、检测矩阵反校正、驱动矩阵预补偿、RLS/EKF和安全系数更新。
- `HRG_WA_v42_metrics.m`：新增在线标定指标与 `passOnlineCalibration`。
- `test_HRG_WA_v42.m`：新增 `online_calibration` 回归用例。
- `HRG_WA_v42_regmap.m`：新增 `0x0100` 起始的在线标定寄存器区。
- `V4.3_在线标定功能说明.md`：说明新增算法链路和验证方式。

注意：本代码仍为 MATLAB 行为级模型，用于论文建模、算法验证和 ASIC 接口规划；真实器件指标需要 RTL、硬件在环和转台实验进一步确认。
