from pathlib import Path
import json,csv,hashlib,math,re
from build_book import content,namespace,OLD

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]


def main():
    m=json.loads((HERE/'manifest.json').read_text(encoding='utf-8'))
    for key in ['files','preserved_previous_files']:
        for name,digest in m[key].items():assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==digest,name
    full,core,chapters=content()
    assert (ROOT/m['book']).read_text(encoding='utf-8')==full
    assert (ROOT/m['core']).read_text(encoding='utf-8')==core
    assert sorted(map(int,re.findall(r'<a id="C(\d{2})"></a>',core)))==list(range(1,25))
    for i,name in enumerate(OLD):
        prefix='V5_' if i==5 else f'H{i+1}_'
        assert namespace((ROOT/name).read_text(encoding='utf-8'),prefix) in full,name
    for x in json.loads((HERE/'sources.json').read_text(encoding='utf-8'))['sources']:
        assert hashlib.sha256(Path(x['path']).read_bytes()).hexdigest()==x['sha256'],x['id']
    for x in json.loads((HERE/'new_archives.json').read_text(encoding='utf-8')):
        assert hashlib.sha256(Path(x['library_path']).read_bytes()).hexdigest()==x['sha256']
    for x in json.loads((HERE/'archive_documents.json').read_text(encoding='utf-8')):
        if x.get('library_path'):assert hashlib.sha256(Path(x['library_path']).read_bytes()).hexdigest()==x['sha256']
    py=json.loads((HERE/'circuit_checks.json').read_text(encoding='utf-8'));assert py['total']==py['passed']==45
    ml=json.loads((HERE/'matlab_circuit_checks.json').read_text(encoding='utf-8'));assert ml['total']==8 and all(ml['checks'].values())
    with (HERE/'circuit_trace.csv').open(encoding='utf-8',newline='') as f:rows=list(csv.DictReader(f))
    seen={}
    for row in rows:
        assert row['id'] not in seen
        for key,value in json.loads(row['operands']).items():assert key in seen and seen[key]==value
        seen[row['id']]=float(row['value']);assert math.isfinite(seen[row['id']])
    assert len(rows)==53 and seen==json.loads((HERE/'circuit_example.json').read_text(encoding='utf-8'))['values']
    assert '待厂家或实测确认' in core and '不是已全文阅读' in core
    # No source PDF/archive or extracted verbatim page cache enters delivery.
    assert all(Path(p).suffix not in {'.pdf','.zip','.rar','.png'} for p in m['files'])
    print('PASS: 24 canonical nodes, seven full historical volumes, 45 Python + 8 MATLAB checks, 53 circuit trace nodes, source hashes and prior release bytes')


if __name__=='__main__':main()
