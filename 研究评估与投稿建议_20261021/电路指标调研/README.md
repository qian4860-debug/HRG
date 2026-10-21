# 电路指标调研入口

- [调研结论与模块指标](调研结论与模块指标.md)：器件、电极、速率/带宽推导、180 nm 架构和模块指标建议。
- [从表头模型推导电路指标](从表头模型推导电路指标.md)：机电端口模型、角度误差预算、模块指标反推与下一步建模顺序。
- [24 条来源与阅读边界](sources.json)：WoS/IEEE、万方公开记录、论文、专利、厂商与论坛分别登记。
- [可修改的预算假设](provisional_spec.json)：包含明确未确认项，不是板卡参数或验收配置。
- [计算结果](budget_results.json)：当前与候选数字链的频响、延迟、抖动、PLL 路径和电极模态矩阵。
- `bandwidth_budget.py`：Python 标准库频域预算模型；`test_bandwidth_budget.py`：8 项物理/数值检查。
- [附件来源与原字节哈希](evidence/user_sources.json)：附件复制件仅本地保存，页图和文字提取可用于复核。

执行：在本目录运行 `python bandwidth_budget.py` 和 `python -m unittest -v test_bandwidth_budget.py`。

本批次以“独立研究预算”交付，没有改当前已验收的 MATLAB/RTL。尚未完成接入完整时域闭环、真实电极/高压网络仿真或板上性能验收。所有推荐数值都必须结合真实采样时钟、载波和表头参数再冻结。
