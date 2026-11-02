> Codex 文档归档副本｜原路径：[HRG_WA_simulink/piezo_v10/revision_v10_2/README.md](<../../../../../HRG_WA_simulink/piezo_v10/revision_v10_2/README.md>)
> 来源提交：`61ea27a8016a`；源 SHA256：`b579d7872b78abf7bc9c3c96023647cb9781f10f77d2ad799905cfafa0e12635`。历史结论须结合版本阅读。

# V10.2 模块化仿真结构

参考用户提供的 Gyro.rar，静态阅读全部15个SLX及参数脚本后，新建模块库、整机模型与独立端口试验台。原工程未发现可确认的源码再分发许可，本修订只记录模块结构与哈希，代码自行实现；不将原压缩包、模型、PSD.p、slprj或缓存复制进发布版本，不执行其startup或模型回调。

MATLAB运行：

```matlab
addpath('C:/Users/11725/Desktop/HRG_WA/HRG_WA_simulink/piezo_v10/revision_v10_2');
out = p102_demo;
```

打开的顶层模型 `models/hrg_wa_v10_2_modular.slx` 包含：

- `Piezo_Head_and_Circuits`：展开后有机械表头、驱动电子学、压电传感端口、电荷放大器、模拟前端五个链接模块。
- `ADC_Interface`：输入噪声、采样量化、截幅标志。
- `Digital_Control_and_DAC`：沿用已验证V10.1的解调窗口、标定、有效性、AGC、正交、PLL、虚拟进动和DAC状态机；没有宣称这些算法已经全部拆成独立积木。
- `Instrumentation`：独立观察与记录，14个Scope、2个Spectrum Analyzer。包括每段电路电压、机械电荷、IQ、频率、有效性和窗口时间戳；频谱为40kHz离散输入的dBV。

`models/hrg_wa_v10_2_modules.slx` 为原生Simulink模块库；`models/hrg_wa_v10_2_port_bench.slx` 为独立驱动注入、关闭控制反馈的机电联合端口试验台。先 `p102_setup; addpath(fullfile(p102_setup,'models'));`，再打开试验台即可运行。通过模型工作区的p统一配置；不依赖base workspace，不执行clear/clc，不递归添加参考工程路径。

完整复验：在MATLAB中运行 `p102_verify`，然后Python/NumPy执行本目录 `verify_structure.py`。前者重建三份SLX并核对基线、非零ADC噪声、任意刚度/阻尼主轴三组闭环；另核对独立双频端口注入、重载与层次结构。后者静态检查模块库状态归属、随机向量联合更新和原工程审计记录。

详细借鉴与适配理由见 [结构对照与设计说明](<结构对照与设计说明.md>)。这里沿用V10.1的合成物理参数和验证边界；结构等价性不构成新的硬件精度结论。运行demo不会保存覆盖交付SLX，验收/构建函数会明确重建本修订模型。

本次验收：18项MATLAB/Simulink检查、6项独立Python检查全部通过。三组闭环的状态、ADC、DAC、诊断逐拍差异均为零；独立端口试验台差异亦为零。结果见 `evidence/results.json`、`evidence/independent_results.json`，顶层图见 `evidence/architecture.png`。`python check_delivery.py`核查交付哈希及全部V10.1依赖原字节；重新构建SLX可能改变元数据，验收重建后需重新审阅再封存。
