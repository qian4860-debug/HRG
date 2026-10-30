from pathlib import Path
import hashlib
import json
import re
import csv
import math
import numpy as np
from build_book import content
from verify_classics import slow

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]


def main():
    manifest=json.loads((HERE/'manifest.json').read_text(encoding='utf-8'))
    for kind in ['files','preserved_previous_files']:
        for name,digest in manifest[kind].items():
            assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==digest,name
    book=(ROOT/manifest['book']).read_text(encoding='utf-8')
    assert book==content()[0]
    assert len(re.findall(r'<a id="L\d{2}"></a>',book))==46
    eq=json.loads((HERE/'equation_map.json').read_text(encoding='utf-8'))
    assert sorted(x['original_equation'] for x in eq)==list(range(1,47))
    for s in json.loads((HERE/'sources.json').read_text(encoding='utf-8'))['sources']:
        assert hashlib.sha256(Path(s['path']).read_bytes()).hexdigest()==s['sha256']
    py=json.loads((HERE/'checks.json').read_text(encoding='utf-8'));ml=json.loads((HERE/'matlab_checks.json').read_text(encoding='utf-8'))
    assert py['passed']==py['total']==36 and all(v['passed'] for v in py['checks'].values())
    assert len(ml['checks'])==4 and all(ml['checks'].values())
    assert '未取得正文' in book and '有符号' in book and '协变量' in book
    assert book.count(r'\[')==book.count(r'\]')
    with (HERE/'worked_trace.csv').open(encoding='utf-8-sig',newline='') as f:rows=list(csv.DictReader(f))
    assert len(rows)==96
    seen={}
    for row in rows:
        assert row['id'] not in seen
        for key,value in json.loads(row['operands']).items():
            assert key in seen and math.isclose(seen[key],value,rel_tol=1e-15,abs_tol=1e-15)
        seen[row['id']]=float(row['value'])
    worked=json.loads((HERE/'worked_example.json').read_text(encoding='utf-8'));p=worked['inputs']
    F=np.array(worked['fixed_force_real'])+1j*np.array(worked['fixed_force_imag'])
    sd,ed=slow(p['a'],p['q'],p['theta'],p['delta'],F,p['w'],p['decay'],p['damping'],p['split'],p['td'],p['tw'],p['k'],p['omega'],p['phidot'])
    assert np.max(abs(np.r_[sd,ed]-[worked[k] for k in ['a_dot','q_dot','theta_dot','delta_dot','E_dot','Q_dot']]))<1e-12
    print('PASS: 46 equation groups, 36 NumPy + 4 MATLAB checks, 96 scalar trace nodes, source bytes, book assembly and preserved previous books/model')


if __name__=='__main__':main()
