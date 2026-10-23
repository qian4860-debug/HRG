# V7之上的新增文献推导与优化探索

本目录是独立研究分支，保留V7原始217项验收依赖及旧模型字节。新增109份下载文献中，本轮实际选择六篇的相关正文作核对；其他文献没有被自动升级为“逐式已读”。所有表头数值与标定夹具仍是假设，不是实测参数。

- [逐步推导](docs/mechanics_to_algorithms.md)：结构积分、完整圆环计算例、HRG模态/电极/电路反作用、噪声和采样、电路指标、IQ及控制/校准/导航，逐步写出中间计算。
- [数值代入表](docs/calculation_trace.md)：由脚本生成的SI公式、代入数值、结果及单位。
- [模型探索及实际结果](docs/model_exploration.md)：独立留出实验、载波初始化问题、所有通过/失败项、观察仪器及限制。
- [全部109份新增文件的核对层级](docs/new_source_coverage.md)：题名初筛、前页机器提取与6篇正文核对分别登记。

```matlab
cd('C:/Users/11725/Desktop/HRG_WA/HRG_WA_simulink/literature_v8_research')
addpath(pwd)
[out,c] = w8_demo; % 带Scope和回放Figure的合成标定场景
```

观察模型：`models/hrg_wa_v8_calibrated.slx`。桌面MATLAB运行可以保留图窗；批处理退出会关闭图窗。可在模型内查看ADC、混频、CIC、FIR、IQ、控制命令、DAC、驱动及机械节点的Scope/Spectrum。频谱单位、实际采样率及观察支路无扰动检查见`evidence/instrumentation.json`。

`w8_config`复用V7的集中机械JSON与电路profile，再加载本目录`profile.json`；默认校准关闭、矩阵为单位阵，避免将合成标定当成实测标定。修改实际机械或电路条件后须重算预算和滤波支持长度、重新取得标定数据、构建新模型并重跑对应验证。新增参数尚未映射ASIC SPI或RTL。

研究代码只从测得IQ、公开时钟和既有命令生成反馈；机械真值仅用于外部scoreboard。训练合成数据明确假定有独立参考，未解决未知表头下全部参数的可辨识性。在线三倍频估计、完整非线性执行逆、RC机电电调、长期噪声、全温和RTL实现仍待后续验证。

复核命令：

```powershell
python HRG_WA_simulink/literature_v8_research/tools/derive_and_check.py
python HRG_WA_simulink/literature_v8_research/tools/report_and_verify.py
```

MATLAB完整探索为`w8_run_studies; w8_build_delivery; w8_plot_results`；会重建本研究目录的实验数据，不改V7数据。初次复现需Python的NumPy、pypdf及本机MATLAB/Simulink与DSP System Toolbox；版本记录见证据清单。原文PDF保持本地，不随GitHub源码分发。
