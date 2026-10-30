"""Check sealed V10.1 bytes, recorded checks and preserved legacy seals."""
from pathlib import Path
import hashlib, json

HERE=Path(__file__).resolve().parent; ROOT=HERE.parents[2]
COUNTS={'calibration_results.json':6,'multiload_results.json':6,
        'temperature_results.json':4,'budget_results.json':4,
        'independent_measurement_results.json':15,'independent_envelope_results.json':6,
        'discretization_results.json':2,'contract_results.json':6,
        'measurement_results.json':25,'research_results.json':16,
        'matlab_temperature_results.json':5}
SUFFIXES={'.py','.m','.json','.csv','.md','.slx','.png'}

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def files():
    return {p.relative_to(HERE).as_posix():sha(p) for p in sorted(HERE.rglob('*'))
            if p.is_file() and p.suffix in SUFFIXES and p.name!='manifest.json' and '__pycache__' not in p.parts}

def evidence():
    for name,count in COUNTS.items():
        r=json.loads((HERE/'evidence'/name).read_text(encoding='utf-8')); c=r['checks']
        assert len(c)==count and all(v is True for v in c.values()),name
    r=json.loads((HERE/'evidence/matlab_all_results.json').read_text())
    for suite,name in [('discretization','discretization_results.json'),('contracts','contract_results.json'),
                       ('measurement','measurement_results.json'),('research','research_results.json'),
                       ('temperature','matlab_temperature_results.json')]:
        assert r[suite]==json.loads((HERE/'evidence'/name).read_text()),suite

def main():
    m=json.loads((HERE/'manifest.json').read_text(encoding='utf-8'))
    actual=files();assert actual==m['files'],[k for k in set(actual)|set(m['files']) if actual.get(k)!=m['files'].get(k)]
    for name,h in m['preserved_legacy'].items():assert sha(ROOT/name)==h,name
    evidence()
    assert m['checks_total']==sum(COUNTS.values())==95
    print('PASS: V10.1 sealed files, 95 recorded checks, two SLX models and preserved legacy seals/books')

if __name__=='__main__':main()
