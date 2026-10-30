# 三篇经典全文增补与第五版总书

主书：[第五版](../../压电全角验证总书第五版_三篇经典文献贯通.md)。承接第四版Lynch46组演算，新增Ragot32组原编号、Jeanroy9组原编号和Rozelle8个本书推演节点。原PDF不复制进公开工程；原位路径、SHA256与阅读范围见sources.json。

依次运行verify_addendum.py、worked_example.py；MATLAB执行verify_addendum_matlab；再运行build_book.py和check_delivery.py。Python需要NumPy，MATLAB检查不依赖Simulink。所有证据采用LF，Git中保存同一字节。构建器读取旧书但不修改旧书。

新增38项Python、9项MATLAB、66计算节点。包括印刷式符号/半角/负耗散反例；通过表示独立推导自洽，不表示这些印刷关系全部正确。没有Ragot32–34，也没有Rozelle“原式号”。V10优化建议与已实现模型分开说明。
