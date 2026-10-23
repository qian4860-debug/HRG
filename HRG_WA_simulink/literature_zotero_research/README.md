# Zotero原文复核与V7精简探索

这是V7/V8之后的独立研究目录，保留已验收模型及哈希。首先阅读[新增原文逐式补充](docs/source_formula_updates.md)，并结合[机械到电路到算法的主推导](../literature_v8_research/docs/mechanics_to_algorithms.md)。

`tools/quantization_audit.py`使用独立坐标变换、误差展开和真实相干ADC算例，检查印刷式、参考面及谐波归因；输出`evidence/quantization_audit.json`和方位扫描CSV。它不是原论文完整仿真的复现，也不是实际电路或全闭环验收。

Zotero导入和私人题录索引的准备/完成状态见工程`research/zotero_integration_20261024/summary.json`，不是以文件出现在本目录推定已导入。全部17份附件已提取的事实与逐式阅读深度分开登记；尚未逐式检查的原文不据此升级状态。
