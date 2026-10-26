# V9：把两个优化做深的可辨识性实验

本轮不是继续扩大算法集合。围绕两个可以被反驳的问题，新增两个透明小模型，并以原ADC/DAC完整载波闭环做留出对照。V7、V8、WZ原始依赖保持不变。

- [专家会额外做什么、原始材料、方法工具、外部证据及重写题目](docs/protocol.md)
- [从零开始：学术推导与通俗解释逐项配对](docs/from_zero.md)
- [实际结果、失败对照及边界](docs/results.md)

核心结果：未校准检测可以给出很小的衰减拟合残差，却把阻尼方向项估错；冻结标定后跨转速更一致。完整载波直接角度RMS从.518542°变成.00163999°；校准关失败的角度门限在校准开时通过。重复静电软化的故障版本在参考电压处产生2.0264mHz假频裂；正确表述一致，数值误差随步长减半约缩小16倍。

这些是合成假设、预充能、恒速、噪声关闭的模型内证据，不是实测表头性能。正交残差略有增加；不声称所有指标改善。尚无真实计量、第三方实测认证或长期随机噪声结论。

## 模型与接口

|模型|作用|证据范围|
|---|---|---|
|models/hrg_wa_v9_identification.slx|慢包络、实际检测矩阵、量化、冻结标定；3个Scope|隔离H1；没有把它称为RF或完整PLL验证|
|models/hrg_wa_v9_bias_reference.slx|机械弹簧、静电反馈及参考扣除分别画出；2个Scope|固定模态小信号机械载波；通过builder切换故障版本|
|models/hrg_wa_v9_frozen_calibration.slx|原电容/AFE/ADC/DAC/数字滤波/控制器加冻结标定；21个Scope、16个Spectrum|实际原采样率闭环对照；旁路直接角度|

估计器接收的只有夹具参考/测量，或校准后的测量轨迹。`truth`仅用于评分，不是控制器或拟合函数的输入。RF训练夹具采用独立的精确电容基频数值积分，留出验证采用原时间域电容及完整电路；不使用留出误差重拟合。

## 运行

```matlab
cd('C:/Users/11725/Desktop/HRG_WA/HRG_WA_simulink/identifiability_v9')
addpath(pwd)
out = w9_demo('identification'); % 快速理解检测污染与校准
out = w9_demo('bias');           % 机械载波及参考偏置反馈
out = w9_demo('rf');             % 完整载波，可能需要数分钟，图窗保留
```

全部重算：

```matlab
w9_run_core;        % 3转速、两步长；2电压、3表述、两步长
w9_run_rf;          % 独立夹具拟合后冻结；两组实际RF；原门限与完整记录
w9_check_delivery;  % 清空调用者配置后重新打开、编译并记录版本
w9_plot;
```

```powershell
python HRG_WA_simulink/identifiability_v9/tools/verify.py
python HRG_WA_simulink/identifiability_v9/tools/report.py
python HRG_WA_simulink/identifiability_v9/tools/seal.py
```

`seal.py`默认只核对封存哈希，不覆盖证据。重新仿真后，先查看新增结果并完成独立核对；确认接受这次新记录后，再运行`seal.py --seal`更新本目录清单并提交Git。它不会重新封存或修改V7/V8/WZ原文件。

独立Python核对不需要MATLAB运行时，只需NumPy和本仓库已跟踪的验收输入。全部重新仿真需要MATLAB、Simulink与DSP System Toolbox；实际版本见`evidence/delivery.json`。门限在`profile.json`，物理/数值功能门限与实物规格区分。

全部零交叉括号样本和固定规则的载波状态探针均纳入Git；完整机械载波原始轨迹另保存在本机`HRG_WA_simulink/layered/_work/v9_raw`，可从脚本重新生成。公开核对不依赖这些隐藏原始文件。失败对照不被删除或被总体pass覆盖。

## 当前没有做的事

没有把H1估计的阻尼继续接入RF补偿；没有实现完整在线DQC/FTR状态机、非线性执行逆、全温/未知运动在线辨识或TDM内闭环。本轮验证的是检测校准如何影响参数解释与现有闭环，以及参考偏置等价性。后续加功能前应先注册新的预测和验收数据划分。
