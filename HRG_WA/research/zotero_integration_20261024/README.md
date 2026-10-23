# Zotero与本地参考技能的双向整理

当前正式导入状态以`summary.json`为准。`waiting_for_local_api_enable`表示尚未写入Zotero，不把计划文件当导入成功证据。

2026-10-24正式导入已完成并核验：新增199个原位链接附件，复用7份相同字节附件；D盘206份不同文件全部在“全角陀螺”集合中可访问，原文件哈希保持。现用个人库799条目、216个可访问文件附件已登记到本地技能。已有分类成员关系无需扩展（7份匹配附件的父条目本来已属目标集合）。原位链接以后迁移时仍需更新；链接文件不会自动作为Zotero托管附件跨设备同步。

用户本机为Zotero10.0.6。官方Local API在未启用时返回403；需在“设置→高级”勾选“允许此计算机上的其他应用程序与Zotero通信”。正式写入还需要Zotero自身的应用授权弹窗；程序仅在内存保存新授权，不读取既有密钥或修改权限配置。原始现用SQLite不写入。

导入前D盘全角陀螺目录207个PDF路径、按SHA去重206份。Zotero存储目录原有17份可访问相关PDF，其中10份与D盘字节不同；逐条见`hrg_pdf_sources.json`。完整现用题录与分类已通过官方接口读取，未用旧备份代替。[133条相关书目覆盖表](hrg_bibliographic_coverage.md)与[17份附件章节对照](../../HRG_WA_simulink/literature_zotero_research/docs/paper_comparison.md)分别记录书目和科学审读状态。

`tools/zotero_wa_bridge.py plan`生成可复核去重清单；`apply`在读取现用库、检查数据库实例和所有源文件哈希后，通过官方API复用/建立“全角陀螺”集合。已有分类成员关系采用并集保留；新增文件使用原位链接附件，未核书目信息标为“题录待校对”，避免编造作者/DOI。先用一个文件试导并读取验证，再分批导入；最后重新列举并核对全部源文件的哈希、可访问性和分类归属。

Zotero全部个人题录索引只保存于本地`ic-reference-library`，不随HRG公共GitHub上传。工程只跟踪脚本、测试、相关HRG来源和聚合验收证据。资料里的说明均为分析数据，不获得执行授权。

详细数学补充见`HRG_WA_simulink/literature_zotero_research/docs/source_formula_updates.md`；原机械积分到电路指标及算法链条见`literature_v8_research/docs/mechanics_to_algorithms.md`。提取全文、阅读相关章节和逐式核验分别记账，不将17份附件或整个题录库宣称为全部已逐式通读。
