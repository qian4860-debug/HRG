# 经典文献逐式演算与验证

主书：[总书第四版](C:/Users/11725/Desktop/HRG_WA/压电全角验证总书第四版_经典文献逐式演算.md)。源码章节在 `chapters/`，每组原式都有唯一 `L01`–`L46` 锚点；`equation_map.json` 将原式、PDF页、扫描印刷页、源码章节和锚点对应。

本轮完整审读的是用户提供的九页 Lynch 平均法扫描。其他五项推荐文献的搜索/获取/阅读边界见 `sources.json`。原文 PDF 保存在 D 盘资料库，公共 GitHub 仅包含引用、哈希、独立推导、脚本与合成证据。

复现顺序：

1. `verify_classics.py`：36项数学检查；128组矩阵/标量/二次量交叉比较。
2. `worked_example.py`：仅用Python标准库，重新计算96个标量节点并输出JSON/CSV。
3. MATLAB运行 `verify_classics_matlab`：4项独立矩阵指数、导数与PI检查。
4. `build_book.py`：确定性合成第四版并生成源文件/旧版哈希清单。
5. `check_delivery.py`：检查公式覆盖、原文身份、书稿组装、计算流水、证据和旧版本字节。

`register_sources.py` 为本机资料库管理工具，需要用户原文件及本地公开下载缓存；它不会被接受为数学验证。正常复算不需要运行它，也不需要Zotero写库授权。完整私人Zotero匹配结果、PDF抽取文本和页面图只存Git忽略的 `_work/`。

本轮没有修改V10控制器、Simulink模型或此前总书；没有进行新的实物/RTL/全系统Simulink性能验收。原式39短轴符号、原式30的不变量统称等问题均给出条件或反例，不据此否定整篇原文。
