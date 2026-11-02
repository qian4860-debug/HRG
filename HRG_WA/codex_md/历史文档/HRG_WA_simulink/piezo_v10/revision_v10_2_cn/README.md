> Codex 文档归档副本｜原路径：[HRG_WA_simulink/piezo_v10/revision_v10_2_cn/README.md](<../../../../../HRG_WA_simulink/piezo_v10/revision_v10_2_cn/README.md>)
> 来源提交：`61ea27a8016a`；源 SHA256：`c64b8425fd3555c32ee384378ecb241dce49ff2a2cabc57e835bf1ba8fabb01d`。历史结论须结合版本阅读。

# MATLAB与Simulink详细中文注释版

本目录覆盖当前V10.2整机的执行路径：15个中文核心MATLAB函数、模型构建/运行/验收脚本，以及整机、物理模块库、端口试验台三份SLX。历史版本和已封存源文件不改写。`pcn_*`为V10.1核心的注释副本，`p103_*`为中文模型入口；数值算法保持一致，不代表增加了硬件功能。

```matlab
addpath('C:/Users/11725/Desktop/HRG_WA/HRG_WA_simulink/piezo_v10/revision_v10_2_cn');
out = p103_demo;
```

双击顶层子系统，画布中可见中文阅读顺序、输入输出、单位、方程、状态和时序。库中的五个物理模块分别解释其状态与联合离散更新。选中模块查看属性的Description可读补充说明。文件路径/块名保留英文以便脚本定位，不影响中文注释阅读。

建议在MATLAB编辑器依次打开：

1. `pcn_config.m`：合成参数、物理量单位与时间尺度。
2. `pcn_plant.m`：12维状态顺序、刚度/阻尼张量、互易端口、电荷放大器和归一化离散化。
3. `pcn_adc_sfun.m`、`pcn_quantize.m`：噪声、采样、码域、物理限幅和截幅标志。
4. `pcn_tick.m`、`pcn_state.m`：35维状态、逐拍与逐窗口执行顺序、解调、标定、控制和反饱和。
5. `pcn_validity.m`、`pcn_metrics.m`：能量/线性度门限、角度可观性、时间戳与评分。
6. `p103_build.m`：模型与模块库的程序化搭建。

两个易误读之处已特别注明：`freq`和沿用的`Scope_PLL_Hz`实际存放角频率rad/s；E为运动电荷平方和C²，不是机械能J。θ为模态方向，物理驻波角β=θ/2，机体角度标定还需要Bryan因子B。

`p103_verify`重建注释模型并与原V10.1参考进行三工况逐拍对比；另验证独立端口试验台和模型重载。Python `check_delivery.py`检查核心代码在去除新增注释和前缀替换后与原文件完全一致，并静态核对SLX中文注释、来源哈希和交付文件。重新生成SLX会改变内部元数据，需重新审阅后封存。

`create_cn_sources.py`是源文件注释生成器，输入哈希见 `evidence/source_hashes.json`；重新运行会覆盖本目录生成的注释源文件，人工编辑前应先提交。运行demo只更新内存模型，不保存覆盖交付SLX。全部表头数值仍为合成值，不当作厂家参数。
