# 闭环质量观察与中文可视化报告

本目录在已验收中文模型上增加只读观察子系统，另存为`models/hrg_wa_quality_monitor.slx`；不覆盖旧模型，不把评分真值送入反馈。

```matlab
addpath('C:/Users/11725/Desktop/HRG_WA/HRG_WA_simulink/piezo_v10/quality_dashboard');
[out, report] = quality_demo;
```

运行后保留模型、质量观察子系统、分项曲线窗口和中文数值判定窗口。双击`Quality_Monitor`中的独立Scope，查看归一化能量、能量误差%、两路归一化Q、正交残差、锁相检测残差、三个时间差、有效性和真正以Hz表示的锁相频率。窗口内的显示结果仍以原始拍速保持；离线报告只对每个完整帧计数一次。

如果已经有`p103_demo`得到的out，无须重跑：先加入本目录，执行`quality_setup; report=quality_report(out,p,true);`。其中p必须是该次仿真的实际参数，不能对更改过Omega/B/Cp的结果套用默认配置。

## 评分定义

- 能量归一化为`E/charge_target²`，目标1，E的单位C²；不是机械能J。
- Q按目标电荷归一化；向量Q的RMS只作描述，不单独设通过门限。
- 正交残差`2(IxQy-IyQx)/E`、锁相检测残差`(I·Q)/E`均无量纲。后者不是直接以rad计的相位角。
- 时间差按`end-start`、`center-start`、`available-end`显示，默认分别为975、487.5、25μs。初始未完成窗口不作为完整帧评分。
- 机体角度误差为`-(beta_corrected-beta_truth)/B`，以度显示。实际施加Cp按原评分器积分扣除，不做真值对齐、拟合偏置、优化延迟或选择角度分支。
- 无效/截幅帧的残差和角度评分不可用；无效帧不跨段解包。未知B时机体角度不可评分，总体不能被标为通过。
- 稳态区间为本次仿真后40%，图表保留全部完整帧以显示建幅过程。演示门限：有效率≥95%，平均归一化能量偏差<5%，正交/锁相残差RMS各<1e-3，角度RMS<0.1°，时间戳偏差<1e-6μs，无DAC截幅。它们不是厂家或硬件验收指标。

## 输出

`evidence/quality_dashboard.png`为独立量纲的分项曲线，`quality_text.png`为中文数值面板；`quality_report.html`可在浏览器直接查看；`quality_report.txt`为UTF-8文字；`quality_frames.csv`保留逐帧数据；`quality_results.json`保留指标和各项布尔判定。

MATLAB运行`quality_verify`检查只读观察不改变原状态/DAC、模型重载、无效帧处理及评分一致性。Python/NumPy运行`check_delivery.py`核对CSV中的角度、能量、残差、时间单位及交付哈希。重建模型或报告会改变封存字节，需重新审阅后再封存。该报告不估计短记录的ARW或硬件零偏稳定性。
