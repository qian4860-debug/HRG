"""逐条筛查 RIS 题录与摘要，输出可复核的分类，不复制摘要正文。"""
from collections import Counter, defaultdict
import csv
import hashlib
import json
from pathlib import Path
import re
import sys

RULES = {
    "whole_angle": r"whole[ -]angle|rate[ -]integrating|rate integration|angle measuring mode|force.to.rebalance",
    "resonant_gyro": r"hemispher.{0,25}(?:gyro|resonator)|coriolis vibratory|vibrating.{0,24}gyro|resonator gyro|microshell|gytrix",
    "piezo": r"piezoelectric|piezo.electric|gytrix|quartz",
    "calibration": r"calibrat|compensat|trimm|mode.match|parameter identif|estimat|observer|phase error",
    "ai": r"neural network|deep learning|machine learning|\blstm\b|\bpinn\b|gaussian process|physics.informed",
    "switching": r"time[ -]division|multiplex|mode revers|mode switch|switching transien|feedthrough|charge injection|virtual rotat",
    "temperature": r"temperatur|therm(al|o)|warm.up|preheat",
    "space": r"spacecraft|satellite|aerospace|\borbit|radiation|vacuum|space environment",
    "disturbance": r"external vibration|linear vibration excitation|random vibration|shock|oscillatory rotat|thermal cycling|fault|disturbance|start.up|restart",
    "circuit": r"readout circuit|interface circuit|\b(?:adc|dac|asic)\b|charge amplif|cmos|\bfd.soi\b|\b180\s*nm\b",
}


def records(data):
    """保留多行字段，检查每条记录的起止标签。"""
    current = None
    field = None
    for line in data.splitlines():
        match = re.match(r"^([A-Z0-9]{2})  -(?: (.*))?$", line)
        if match:
            field, content = match.groups()
            if field == "TY":
                assert current is None
                current = defaultdict(list)
            assert current is not None
            if field == "ER":
                yield current
                current = None
            else:
                current[field].append(content or "")
        elif line.strip() and current is not None:
            current[field][-1] += " " + line.strip()
    assert current is None


def main(source, directory):
    raw = source.read_bytes()
    rows, bucket = [], {}
    count = Counter()
    for i, fields in enumerate(records(raw.decode("utf-8-sig")), 1):
        kind = fields["TY"][0]
        title = next((" ".join(fields[tag]).strip() for tag in ("TI", "T1", "CT", "BT")
                      if any(value.strip() for value in fields[tag])), "")
        abstract = next((" ".join(fields[tag]).strip() for tag in ("AB", "N2")
                         if any(value.strip() for value in fields[tag])), "")
        doi = " ".join(fields["DO"]).strip().lower()
        uid = " ".join(fields["AN"])
        if not uid:
            uid = " ".join(fields["PN"] or fields["U1"])
        metadata = " ".join([title, abstract] + fields["KW"] + fields["DE"] + fields["ID"])
        tags = {key for key, pattern in RULES.items() if re.search(pattern, metadata, re.I)}
        topical = bool({"whole_angle", "resonant_gyro"} & tags)
        a = topical and bool({"calibration", "ai", "switching"} & tags)
        b = topical and bool({"temperature", "space", "disturbance"} & tags)
        bin_name = ("AB" if a and b else "A" if a else "B" if b else
                    "gyro_context" if topical else "other")
        key = doi or uid or re.sub(r"\W+", "", title.casefold())
        duplicate = bucket.setdefault(key, i) if key else i
        rows.append(dict(row=i, type=kind, year=" ".join(fields["PY"] or fields["DA"]),
                         title=title, doi=doi, accession=uid,
                         has_abstract=bool(abstract), tags=";".join(sorted(tags)),
                         keyword_group=bin_name, first_matching_row=duplicate))
        count.update({f"type:{kind}": 1, f"screen:{bin_name}": 1, "records": 1,
                      "title": bool(title), "abstract": bool(abstract), "doi": bool(doi),
                      "identifier_repeat": duplicate != i})
        count.update(f"keyword:{tag}" for tag in tags)
    assert rows and len(rows) == len(re.findall(rb"^ER  -", raw, re.M))
    directory.mkdir(parents=True, exist_ok=True)
    with (directory / "ris_screen.csv").open("w", encoding="utf-8", newline="") as out:
        writer = csv.DictWriter(out, fieldnames=list(rows[0]), lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    stats = {"source": source.name, "sha256": hashlib.sha256(raw).hexdigest(),
             "scope": "keyword triage on RIS metadata, not full text or paper-type verdict",
             "counts": dict(sorted(count.items()))}
    (directory / "ris_screen_summary.json").write_text(
        json.dumps(stats, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps(stats, indent=2))


if __name__ == "__main__":
    main(Path(sys.argv[1]), Path(sys.argv[2]))
