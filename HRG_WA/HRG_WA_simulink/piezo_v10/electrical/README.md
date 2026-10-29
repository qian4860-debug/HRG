# V10电荷域研究分支

[优化研究说明](../../../V10优化研究_缺少表头参数时的电荷域闭环.md)解释推导与边界。此分支不读取profile中的physical对象，不需要模态质量、C/m或N/V；状态η以C计，绝不当作m。使用此前合成辨识的electrical对象，AFE、时钟、目标电荷和允许电压均为显式合成夹具设置。

MATLAB中运行：

```matlab
cd('C:/Users/11725/Desktop/HRG_WA/HRG_WA_simulink/piezo_v10/electrical')
addpath(pwd)
result=p10e_run;
```

模型`models/hrg_v10_electrical_only.slx`含12状态电荷/电路耦合、ADC、数字控制和3个Scope。电压日志和IQ单位分别为V、C；state第1–2路为C、第3–4路为C/s、其余为V。使用时需同时保留父目录`p10_adc_sfun.m`，仅传.slx不够。观察窗口没有自动关闭操作，可在仿真后手动双击Scope。

Python（工程根目录）：

```powershell
python HRG_WA_simulink/piezo_v10/electrical/verify_electrical.py
python HRG_WA_simulink/piezo_v10/electrical/check_delivery.py
```

已执行8项MATLAB/Simulink与6项独立Python检查。参数与结果见`evidence`。原V10及辨识分支封存校验仍通过。本次静止工况B为空，Ω非零时拒绝运行；未做完整导航、随机噪声、真实参数、机械振幅及安全限值验收。多端口失配与非理想ADC的闭环研究仍待后续，不因为引用论文存在就算实现。

该分支是探索模型，没有实物发布入口。6个独立检查依赖父目录`verify_independent.py`的NumPy矩阵指数实现；其原封存文件保持不变。
