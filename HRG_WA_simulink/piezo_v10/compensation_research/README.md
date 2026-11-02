# 标定、速率残差与各向异性补偿研究分支

入口为已保存的 `models/hrg_wa_compensation_research.slx`，原验收版本不改写。

```matlab
addpath('C:/Users/11725/Desktop/HRG_WA/HRG_WA_simulink/piezo_v10/compensation_research');
[out, report] = comp_demo;    % 打开补偿模型及同一质量面板
```

批量结果见 `evidence/index.html`，包括原18个非理想工况及3个新的留出工况。每个工况仍按原门限和源窗口中心评分，不优化真值偏置或延迟。

实现包含：独立参考再标定、从有效测量开始的因果力方向预测、首个完整有效窗口前零力启动、独立辨识的刚度/阻尼不均匀张量前馈。详见 [推导与试验设计](推导与试验设计.md)。控制内核只读取测量和辨识结果，不读取真实Omega、theta0或真实各向异性参数。

重要边界：这里的独立参考数据为合成数据。实际应用必须具备校准电荷、执行响应、机械运动/力观测或等价的独立参考；本分支不是无参考在线自校准，也不保证厂家不给参数时即可自动辨识。机械fixture使用归一化校准观测快照，并非实际采集/微分软件。噪声很强时可仍不通过，失败保留。

## 复验

1. Python/NumPy执行`prepare_sources.py`、`fit_independent.py`，重建研究源码和合成辨识参考（会覆盖对应文件，先保存人工编辑）。
2. MATLAB执行`comp_run`，运行21个MATLAB载波工况及7个Simulink逐拍核对，生成同面板报告。
3. MATLAB执行`comp_ablation`，查看早预测/零启动力消融和10%张量辨识误差。
4. Python/NumPy执行`check_delivery.py`，独立复算逐帧指标、张量符号、参考留出误差和哈希；`--seal`仅在审查后显式使用。

控制代码`comp_tick.m`保留中文注释，状态仍为35维。旧机械、电路、ADC及评分函数均复用；源文件哈希保存在`source_hashes.json`。图文报告、CSV、失败项和消融指标保存在`evidence/`。运行demo只改内存，批量研究会重建本分支模型与证据。

这些是有限时长、有限参数点、合成参考成立时的条件性可行性结果，不是连续工作范围、ARW、温漂、全零幅自激启动或硬件性能认证。
