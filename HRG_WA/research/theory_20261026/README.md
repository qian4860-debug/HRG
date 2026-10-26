# 新增文献后的理论优化：学术推导与通俗解释

主文：[derivation_academic_and_intuitive.md](derivation_academic_and_intuitive.md)。18节，包含逐步公式、变量/单位、数值代入、适用条件及通俗解释。

阅读顺序建议：

1. 初次理解工作原理：第3–6节，先分清三个角，再看两个振子、电容、IQ。
2. 理解优化原因：第7–12节，重点是检测误差如何污染阻尼估计、跨模式可辨识性、偏置参考和相位泄漏。
3. 从需求确定电路参数：第13–15节，工作振幅、噪声/ADC/DAC预算、启动与PI/PLL。
4. 需要实施时看第16节分层验证计划；第17节是原文印刷式的一个独立核对例子。

`sources.json`区分一篇本地完整PDF的相关章节阅读与三篇出版方摘要/预览。新增365条题录不代表365份全文已读；本轮没有取得那三篇的完整正文。

`check_derivations.py`独立复算13组公式/反例，输出`derivation_checks.json`；原V7、V8、WZ封存字节逐项保持。所有示例均非实物表头标定，未进行新的RF/Simulink/长期噪声仿真。本轮交付理论与验证脚本，分层建模实施计划不算已经完成。

```powershell
python research/theory_20261026/check_derivations.py
```

原20节完整推导与运行记录仍在`HRG_WA_simulink/literature_v8_research`；上一轮增量模型在`literature_zotero_research`。本轮以新目录继续版本管理，避免改动已验收文件。
