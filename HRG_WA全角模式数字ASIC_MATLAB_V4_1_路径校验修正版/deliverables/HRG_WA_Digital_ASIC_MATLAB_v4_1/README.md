# HRG Whole-Angle Digital ASIC MATLAB V4.1

本目录提供半球谐振陀螺全角模式、检测接口和数字ASIC控制/解算链的行为级模型。V4重点修正了锁定时速率滤波状态复位、导航角积分低通面积损失、FAULT数据污染性能统计，以及“真实定点溢出”和“正常控制限幅”混合计数等问题。

当前修订还将 `loop_disable` 显式故障直接接入连续故障消抖与FAULT锁存逻辑，不再通过临时提高能量保护门限间接触发故障，避免故障在计划注入时刻之前误报。

## 快速运行

1. 将本目录加入MATLAB路径。
2. 先运行 `verify_HRG_WA_v4_install`，确认测试脚本、仿真器和参数文件来自同一新版目录。
3. 打开 `HRG_WA_v4_user_config.m`，在文件表头修改物理量和控制器参数。
4. 运行 `run_HRG_WA_v4_demo`，查看分层通过结论、MAT结果、CSV向量和六联图。
5. 运行 `test_HRG_WA_v4`，执行六组功能、性能、字长、展开、虚拟进动和故障安全回归。
6. 修改物理量后，按照 `HRG_WA_V4_参数与控制器修调指南.md` 的顺序重新修调DPLL、能量环、正交环和导航输出。

## 文件说明

- `HRG_WA_v4_user_config.m`：集中式用户物理量、接口、控制器、自动调参目标和回归门限表头。
- `HRG_WA_v4_params.m`：参数合并、单位转换、派生量和输入函数构造。
- `HRG_WA_v4_validate_params.m`：采样、量程、环路延迟、DPLL范围和展开裕量检查。
- `HRG_WA_v4_autotune.m`：基于当前行为方程的控制器解析初值与动态范围建议。
- `HRG_WA_v4_simulate.m`：HRG慢变量、AFE/ADC、数字ASIC、DAC和故障状态机闭环仿真。
- `HRG_WA_v4_metrics.m`：RUN有效窗口统计与功能/性能/故障安全分层判据。
- `HRG_WA_v4_regmap.m`：32位APB或AXI-Lite建议寄存器表。
- `HRG_WA_v4_export_vectors.m`：带分层诊断计数的RTL逐拍CSV向量导出。
- `run_HRG_WA_v4_demo.m`：标称演示入口。
- `test_HRG_WA_v4.m`：六组回归入口。
- `verify_HRG_WA_v4_install.m`：打印MATLAB实际解析路径并阻止新旧文件混用。
- `HRG_WA_V4_参数与控制器修调指南.md`：物理量改变后的完整修调方法。

## 分层诊断定义

- `fixedOverflowCount`：只统计定点数据通路超出Q格式范围的真实溢出。
- `pllLimitCount`：统计DPLL积分器或频率输出限幅。
- `piIntegratorLimitCount`：统计能量与正交PI积分器限幅。
- `controlOutputLimitCount`：统计能量与正交控制输出限幅。

启动阶段的控制输出限幅可以是预期的起振行为；RUN阶段持续限幅、真实定点溢出或ADC/DAC物理饱和必须单独分析。

## 适用边界

本模型用于公开理论下的系统方案、控制极性、字长、动态范围、状态机、接口和RTL对拍规划。自动调参属于行为模型工程推导，不代表任何厂商量产芯片的确切内部实现，也不能替代器件辨识、晶体管级仿真、PVT/Monte Carlo、硬件在环、转台或温箱验证。
