from pathlib import Path
import csv
import json
import hashlib
import re
import math
from build_book import content

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]


def main():
    manifest=json.loads((HERE/'manifest.json').read_text(encoding='utf-8'))
    for key in ['files','preserved_previous_files']:
        for name,digest in manifest[key].items():assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==digest,name
    book=(ROOT/manifest['book']).read_text(encoding='utf-8');assert book==content()[0]
    for prefix,expected in [('L',list(range(1,47))),('R',list(range(1,32))+[35]),('J',list(range(1,10))),('Z',list(range(1,9)))]:
        assert sorted(map(int,re.findall(r'<a id="'+prefix+r'(\d{2})"></a>',book)))==expected,prefix
    assert book.count(r'\[')==book.count(r'\]')
    for item in json.loads((HERE/'sources.json').read_text(encoding='utf-8'))['sources']:
        assert hashlib.sha256(Path(item['path']).read_bytes()).hexdigest()==item['sha256']
    py=json.loads((HERE/'checks.json').read_text(encoding='utf-8'));assert py['passed']==py['total']==38
    ml=json.loads((HERE/'matlab_checks.json').read_text(encoding='utf-8'));assert ml['total']==9 and all(ml['checks'].values())
    with (HERE/'worked_trace.csv').open(encoding='utf-8',newline='') as f:rows=list(csv.DictReader(f))
    seen={}
    for row in rows:
        assert row['id'] not in seen
        for key,value in json.loads(row['operands']).items():assert key in seen and seen[key]==value
        value=float(row['value']);assert math.isfinite(value);seen[row['id']]=value
    assert len(rows)==66
    worked=json.loads((HERE/'worked_example.json').read_text(encoding='utf-8'));assert seen==worked['values']
    print('PASS: fifth book, 41 new original groups + 8 editorial nodes, 38 Python + 9 MATLAB checks, 66 trace nodes; previous release bytes preserved')


if __name__=='__main__':main()
