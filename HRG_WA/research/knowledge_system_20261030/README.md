# 从结构到电路的全知识体系

- [完整版总书](../../压电全角陀螺_结构到电路全知识体系总书.md)：现行主线、经典全文演算和七份历史总书/教材全部文字。
- [核心阅读版](../../压电全角陀螺_全知识体系核心阅读版.md)：24个新推导节点、经典第五版及历史文件导航，便于日常阅读。
- [资料覆盖表](library_coverage.md)：224条教材/讲义等候选及新增运放包61条文档项；阅读与获取状态分别记录。

以用户确认的压电表头为基础，压电驱动/检测端口的具体实现仍是研究工况，不能从此前条件性提问推定厂家确认。全书区分原文、独立推演、旧版本、模型实际功能和未实现建议。新增教材PDF与压缩包存D盘资料库，仅登记路径/SHA，不上传公共GitHub。

复算：运行verify_circuits.py（45项）、worked_circuits.py（53节点），MATLAB执行verify_circuits_matlab（8项）；运行register_sources.py刷新选读/覆盖表，再build_book.py和check_delivery.py。构建仅需已跟踪MD/JSON，不依赖临时提取缓存；来源字节验收需要本机登记的D盘原文。Python需要NumPy/pypdf，MATLAB检查不使用工艺PDK。

三篇经典增补另见../classics_addendum_20261030，38项Python+9项MATLAB，原编号41组。旧Lynch/模型验收保持原字节；本轮不修改SLX、RTL和旧参数。代码、计算表、测试、来源、总书和manifest全部Git管理。
