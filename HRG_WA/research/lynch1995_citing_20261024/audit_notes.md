# 核对边界与更正

该日期的发现快照保持稳定编号；重新运行discover不会覆盖已有题录。补充链接按稳定ID登记于public_pdf_supplements.json；下载缓存必须同时匹配DOI与题名，不能仅凭LC编号复用。

- 初始人工补充中将能量补偿论文的DOI误写为10.3390/s20133677。实际该DOI是无线传感器网络论文；它的文件身份虽然匹配该DOI，却没有目标引用关系。已移出用户参考专题目录，仅在忽略的临时工作目录留存；不能计入被引全文。正确能量补偿论文DOI为10.3390/s20123549，原库已有文件已在清单登记。
- Fiber-optic gyro versus coriolis vibratory one的PDF身份核验通过，但参考文献指向Lynch与Matthews 1996；未找到目标1995论文，已移出该专题目录，保持“候选引用未确认”。
- 旧登记中Coriolis Vibratory Gyros曾指向另一篇High-quality-factor MEMS论文。当前强制正文首页题名区域匹配，将该错误关联拒绝；另一篇论文以其实际题名单独登记。旧版已封存登记保持原始字节，本次不静默修改历史。
- 部分已持有学位论文的封面与解析器不能通过当前统一首页核验，标为local_present_needs_parse_or_identity_review。文件存在和引用题录证据仍登记，不能将它们称为“本地缺失”，也不把它们计为当前核验全文。
- 67条OpenAlex全文关键词命中只是候选，包含一条明显无关的营销论文题录；该项未取得且未计为被引。关键词命中不等于引文图中的一条边。
- 下载仅使用公开出版方与大学库链接，未取得的原因逐URL记录。Scholar完整题录尚未读取，无法计算覆盖率。没有把受限页面的HTML、会议目录、错误论文、已有文件或未核引用关系的候选计入新增成功全文。

复核：Python需pypdf；运行`tools/acquire_lynch1995_citing.py report --install`复核原文件并生成摘要，`tools/install_lynch1995_register.py`更新本地技能专题与私人目录。后者只对本机路径适用，私人目录不上传GitHub。离线回归见`tests/test_lynch_citing.py`。
