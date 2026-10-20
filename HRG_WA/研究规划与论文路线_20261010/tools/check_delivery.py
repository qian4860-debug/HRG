from pathlib import Path
import hashlib
import json
import re

REPORT = Path(__file__).resolve().parent.parent
E = REPORT / 'evidence'
checks = {}
expected = [
    '00_总览与阅读指南.md', '01_已有研究工作与证据审计.md',
    '02_全角陀螺技术进展_截至20261010.md', '03_创新候选与已有文献对照.md',
    '04_小论文选题与实验设计.md', '05_2025中科院分区与附件期刊匹配.md',
    '06_博士研究路线与阶段验收.md', '07_网页版GPT讨论继承与结论差异.md',
    '08_参考文献与检索记录.md', '09_本轮验证与交付检查.md',
]
texts = {}
for name in expected:
    p = REPORT / name
    assert p.is_file(), name
    text = p.read_text(encoding='utf-8')
    assert len(text) > 500 and '\ufffd' not in text, name
    assert text.count('```') % 2 == 0, name
    texts[name] = text
checks['markdown_files'] = {name: len(text) for name, text in texts.items()}
references = texts['08_参考文献与检索记录.md']
for name, text in texts.items():
    for ref in re.findall(r'\bR(\d+)\b', text):
        assert re.search(r'\| R' + ref + r' \|', references), (name, ref)
for line in references.splitlines():
    match = re.match(r'\| (R\d+) \| (.*?) \| (10\.[^ ]+) \|', line)
    if not match:
        continue
    number, description, doi = match.groups()
    p = E / 'web' / (doi.replace('/', '_') + '.json')
    assert p.exists(), (number, doi)
    work = json.loads(p.read_text(encoding='utf-8'))['message']
    title = work['title'][0]
    assert description.startswith(title), (number, description, title)
checks['reference_title_doi_alignment'] = True
inventory = json.loads((E / 'source_inventory.json').read_text(encoding='utf-8'))
changed = []
missing = []
for record in inventory:
    p = Path(record['path'])
    if not p.exists():
        missing.append(str(p))
    elif hashlib.sha256(p.read_bytes()).hexdigest() != record['sha256']:
        changed.append(str(p))
assert not changed and not missing, {'changed': changed, 'missing': missing}
checks['original_files_hash_unchanged'] = len(inventory)
summary = json.loads((E / 'current_validation_summary.json').read_text(encoding='utf-8'))
assert not any(k.endswith('Error') for k in summary)
assert summary['baseline']['locked'] and not summary['baseline']['faulted']
assert summary['ab']['validation']['pass']
assert summary['ab']['validation']['systematicImprovementFraction'] > 0.9
checks['matlab_executed'] = summary['matlabVersion']
checks['matlab_ab_pass'] = True
def read_log(p):
    data = p.read_bytes()
    return data.decode('utf-16' if data.startswith(b'\xff\xfe') else 'utf-8-sig')
sensor = read_log(E / 'rtl_sensor_if' / 'simulation_console.txt')
raw = read_log(E / 'rtl_raw_frontend' / 'simulation_console.txt')
assert 'HRG_SENSOR_IF_TB PASS' in sensor
assert 'Final mode             : 2' in raw and '0x00000000' in raw
checks['sensor_rtl_tb_pass'] = True
checks['raw_rtl_completed_but_performance_not_pass'] = True
assert '待' in texts['05_2025中科院分区与附件期刊匹配.md']
assert '尚未继承' in texts['07_网页版GPT讨论继承与结论差异.md']
checks['limitations_explicit'] = True
checks['status'] = 'PASS'
(E / 'delivery_check.json').write_text(json.dumps(checks, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(checks, ensure_ascii=False, indent=2))