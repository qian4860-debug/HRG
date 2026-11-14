"""审计 savedrecs (1).ris 是否含 ADC / Pipeline / SAR 证据。

结论用于判断“用 RIS 全体文件评判 Pipeline ADC 选题”是否成立。
只做题录与摘要关键词分诊，不等同于全文阅读或论文质量判断。
"""
from __future__ import annotations

import hashlib
import json
import re
from collections import Counter
from pathlib import Path

RIS = Path(r"G:\学习资料\资料\全角陀螺\savedrecs (1).ris")

# 记录型标签；ADC 相关词用边界，避免 reservoir/oscillator 等误命中。
PATTERNS = {
    "adc": r"(?<![A-Za-z])(?:ADC|ADCs)(?![A-Za-z])|analog[-\s]?to[-\s]?digital",
    "sar": r"(?<![A-Za-z])SAR(?![A-Za-z])|successive[-\s]?approximation",
    "pipeline": r"pipeline(?:d|s)?",
    "sigma_delta": r"sigma[-\s]?delta|delta[-\s]?sigma|Σ[-\s]?Δ",
    "cmos": r"(?<![A-Za-z])CMOS(?![A-Za-z])|0\.18\s*(?:um|µm|μm)|180\s*nm|FDSOI|FD-SOI",
    "calibration": r"calibrat|trim(?:ming)?|compensat",
    "ai": r"neural network|deep learning|machine learning|\bLSTM\b|\bPINN\b|gaussian process",
}


def read_records(path: Path) -> list[dict[str, list[str]]]:
    """解析 RIS；保留多行字段，并在 ER 处收束记录。"""
    records: list[dict[str, list[str]]] = []
    current: dict[str, list[str]] | None = None
    field: str | None = None
    for line in path.read_text(encoding="utf-8-sig").splitlines():
        match = re.match(r"^([A-Z0-9]{2})  -(?: (.*))?$", line)
        if match:
            field, content = match.groups()
            if field == "TY":
                current = {}
            if current is not None:
                if field == "ER":
                    records.append(current)
                    current = None
                else:
                    current.setdefault(field, []).append(content or "")
        elif line.strip() and current is not None and field:
            current[field][-1] += " " + line.strip()
    return records


def title_of(record: dict[str, list[str]]) -> str:
    for tag in ("TI", "T1", "CT", "BT"):
        if record.get(tag):
            return " ".join(record[tag]).strip()
    return ""


def text_of(record: dict[str, list[str]]) -> str:
    return " ".join(value for values in record.values() for value in values)


def main() -> None:
    records = read_records(RIS)
    types = Counter(record["TY"][0] for record in records if record.get("TY"))
    counts = {}
    hits = {}
    for name, pattern in PATTERNS.items():
        matched = [i for i, record in enumerate(records, 1) if re.search(pattern, text_of(record), re.I)]
        counts[name] = len(matched)
        hits[name] = matched
    # 只打印 ADC/SAR/Pipeline 的命中，便于人工复核误命中。
    details = []
    for name in ("adc", "sar", "pipeline", "sigma_delta"):
        for i in hits[name]:
            record = records[i - 1]
            details.append(
                {
                    "row": i,
                    "keyword": name,
                    "title": title_of(record),
                    "year": " ".join(record.get("PY") or record.get("DA") or []),
                }
            )
    raw = RIS.read_bytes()
    out = {
        "source": RIS.name,
        "sha256": hashlib.sha256(raw).hexdigest(),
        "records": len(records),
        "types": dict(sorted(types.items())),
        "fields": {
            "title": sum(bool(title_of(record)) for record in records),
            "abstract": sum(bool(record.get("AB") or record.get("N2")) for record in records),
            "doi": sum(bool(record.get("DO")) for record in records),
        },
        "keyword_counts": counts,
        "adc_related_hits": details,
        "scope": "题录/摘要关键词分诊；不等于全文检索或论文质量判断。",
        "verdict": (
            "当前 RIS 只有 999 条题录，没有 AB/KW 字段；ADC/SAR/Sigma-Delta 命中为 0，"
            "pipeline 仅命中一条清洗设备专利。它不能评判 Pipeline ADC 的学术新颖性；"
            "且当前 SHA256 与既有 ris_screen_summary.json 记录的 7e1d3f... 不一致，"
            "此前声称的 913 条摘要/282 条校准命中无法由当前文件复现。"
        ),
    }
    path = Path(__file__).with_name("ris_adc_audit.json")
    path.write_text(json.dumps(out, indent=2, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps(out, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
