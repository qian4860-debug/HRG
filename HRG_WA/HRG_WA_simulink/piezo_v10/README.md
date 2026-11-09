# V10压电式全角载波闭环

> 2026-11-09 当前 6800 Hz 双路线入口：[参数、原生模型与验证说明](../../codex_md/22_6800Hz参数回填与原生双方案_20261109.md)；代码和模型在 `head6800_20261109/`。本文件下文保留历史 V10 说明。

[总书第三版](../../压电全角总书第三版_原理到V10实现.md)从球壳到电路、控制和验收逐步推导；[实现说明](docs/implementation.md)说明每个状态、矩阵行和验收边界。旧V7—V9保留。

合成1kHz表头，12状态双向机电模型，带输入负载反作用、驱动器/电荷放大器/AFE、ADC/DAC量化、矢量AGC、正交与局部PLL。模型含10个Scope、2个原生Spectrum Analyzer。MATLAB R2025a实际运行，结果见`evidence/results.json`。未实现的TDM、在线相位注入辨识、真实噪声/Allan等在说明中明确列出。

```matlab
cd('C:/Users/11725/Desktop/HRG_WA/HRG_WA_simulink/piezo_v10')
addpath(pwd)
p10_run
p10_finalize
out=p10_demo; % 保持模型和波形窗口
```

工程根目录：

```powershell
python HRG_WA_simulink/piezo_v10/verify_independent.py
python research/scholar_piezo_20261029/reproduce_piezo.py
python tools/build_piezo_v10_book.py
python HRG_WA_simulink/piezo_v10/check_delivery.py
```

需要MATLAB、Simulink及DSP System Toolbox；Python只需要NumPy。所有参数均非真实表头实测值。scoreboard共用数字控制tick，只证明调度一致；独立Python另核对物理矩阵及能量平衡。不要把此结果当作芯片、实物或论文全部算法的验收。
