# 全角HRG文献优化 V7

V7在原分层模型之外新增，保留旧验收原始字节。机械参数沿用集中表头JSON；接口假设、控制带宽和时分参数集中在`profile.json`。所有数值尚未经真实表头标定。

## 在MATLAB中运行

```matlab
cd('C:/Users/11725/Desktop/HRG_WA/HRG_WA_simulink/literature_v7')
addpath(pwd)
[out,c] = w7_demo('continuous');  % 库Scope、Spectrum及结束后的Figure回放
[out,c] = w7_demo('switched');    % D/卸荷/S/卸荷及有限建立、消隐
[out,c] = w7_demo('pir');
[out,c] = w7_demo('tia');
[out,c] = w7_demo('electrostatic');
[out,c] = w7_demo('startup');     % 真正从零机械状态启动，标称频率附近
```

每次只需运行一个演示。`-batch`进程退出会关闭图窗；桌面命令窗口运行可保留Figure。演示使用临时模型，不改旧SLX。Scope必须在仿真开始前打开才能缓存全过程；普通Figure可通过`wl_view_results(out,c)`回放。

```matlab
c = w7_config([],struct('controlMode','PIR','tdmMode','switched'));
c.duration = 2;
[out,c] = w7_sim(c,false);
m = w7_metrics(out,c);           % 同一组八类外部验收量
b = w7_budget(c);                % SI预算及假设条件
w7_build(c,true);                % 保存到本目录models，不覆盖旧版本
```

`w7_config`第二参数覆盖profile顶层字段，未知字段直接拒绝。更换实际表头请修改profile指向的机械JSON，或复制为新文件再修改路径；接口参数用`profile.circuit`。更改Rf/Cf、f0、时钟、控制带宽、拓扑或开关时间后重新调用配置函数和构建函数。标定常数在配置生成时固定；对实际极点做扰动时直接改`c`而不重新标定，避免误差被自动抵消。实验验证可令`noiseEnable=false`，产品指标不能由此取消噪声。

新增V7参数是行为仿真配置，尚未分配ASIC SPI地址；原机械配置生成与RTL验收流程保留，不能把模型中的新控制器当成已同步实现的RTL。

## 内容与验证

- [从机械到每个电路模块的详细推导](docs/mechanics_to_circuits.md)：15节、19组主要公式、来源页码、参考面、近似和实现映射。
- [实际运行结果](docs/results.md)：PI/PIR、启动、静电力、分时、TIA、数值步长和噪声；失败/未评估项保留。
- `models/`：五个带观察仪器的载波模型和一个PIR包络研究模型；重新打开后初始化自己的配置。
- `evidence/`：JSON记分板、实际配置、原采样率载波尾段和低速全记录CSV、对比图与完整性清单。

```matlab
w7_run_validation         % 19项独立检查、5个载波场景及40s PI/PIR包络对照
w7_validate_mechanics     % 400k/800k实际自由振动与独立矩阵指数
w7_validate_noise         % 同工况CV噪声开/关配对；短记录不是ARW
w7_sweep_interfaces       % 9个短时单因素接口工况，保留标称校准
w7_build_delivery         % 保存新模型并重新打开、编译检查回调和仪器
w7_validate_instrumentation % 实际采样率、单位及观察支路逐点无扰动验证
```

图表和结果文档由`tools/report.py`生成；`tools/verify.py`校验依赖、证据哈希和实际指标。原54项/24工况的验收不重写，新结果有独立目录。V7控制接口仍接入原Kalman/RLS/FRP适配器，默认不启用尚未经物理可辨识与留出验证的在线补偿。

PIR是带泄漏、实测进动频率调谐的研究实现；TDM是双路同时检测的驱动/读出隔离，不是完整单通道复用；静电力是对置平板与显式模态参与系数抽象。尚无全电极调谐、未知频率自动搜索、长期Allan/ARW、全温PVT或RTL位真签核。
