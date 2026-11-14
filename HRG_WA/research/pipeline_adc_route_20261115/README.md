# Pipeline ADC 选题审计 · 2026-11-15

本目录只放可复现证据，结论写在 `DSH_md/31` 与 `DSH_md/32`。

| 文件 | 用途 |
|---|---|
| `adc_budget.py` / `adc_budget.json` | 6.8 kHz、5.44 MS/s、1 Vpp、800 点/窗下的量化/kT/C/角度噪声、SAR 时序、Pipeline OTA、时间戳相位、参考电荷与 FOM 一阶预算 |
| `pipeline_corpus.csv` | 本机 `资料/全角陀螺/pipeline` 中 24 篇 ADC 文献的工艺、速率、位数、SNDR、功耗、架构、校准与对本系统的相关性 |
| `ris_adc_audit.py` / `ris_adc_audit.json` | 对 `savedrecs (1).ris` 的题录/摘要关键词审计；记录当前 SHA256、字段完整性与 ADC/SAR 命中数 |

## 关键边界

1. 当前 `savedrecs (1).ris` 只有 999 条题录，`AB` 与 `KW` 字段为 0，ADC/SAR 命中为 0；不能用来评判 Pipeline ADC 的学术新颖性。
2. 当前 RIS 的 SHA256 为 `617a47f...`，与 `research/wa_paper_routes_20261114/ris_screen_summary.json` 记录的 `7e1d3f...` 不一致。此前“913 条摘要、282 条校准命中、2000 条 savedrecs (2)/(3)”无法由当前工作区复现，引用前必须恢复原始文件并核对哈希。
3. `adc_budget.py` 是一阶筛选，不是晶体管级后仿；角度噪声用 `theta=0` 附近的 `sigma_IQ/(2a)` 近似，正式预算应用系统模型雅可比与逐帧重放。
