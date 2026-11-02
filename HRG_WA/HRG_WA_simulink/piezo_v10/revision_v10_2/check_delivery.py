"""Portable delivery integrity; --seal is an explicit reviewed operation."""
from pathlib import Path
import argparse,hashlib,json
HERE=Path(__file__).resolve().parent;OLD=HERE.parent/'revision_v10_1'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def snapshot():
    return {p.relative_to(HERE).as_posix():sha(p) for p in sorted(HERE.rglob('*')) if p.is_file() and p.suffix in {'.py','.m','.md','.json','.png','.slx'} and p.name!='manifest.json' and '__pycache__' not in p.parts}
def checks():
    for name,count in [('results.json',18),('independent_results.json',6)]:
        c=json.loads((HERE/'evidence'/name).read_text())['checks'];assert len(c)==count and all(v is True for v in c.values()),name
    old=json.loads((OLD/'manifest.json').read_text(encoding='utf-8'))
    for n,h in old['files'].items():assert sha(OLD/n)==h,('V10.1 dependency changed',n)
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--seal',action='store_true');args=parser.parse_args();checks()
    if args.seal:
        for p in HERE.rglob('*'):
            if p.is_file() and p.suffix in {'.m','.py','.md','.json'}:
                b=p.read_bytes();n=b.replace(b'\r\n',b'\n')
                if b!=n:p.write_bytes(n)
        m=dict(date='2026-11-02',files=snapshot(),v10_1_manifest_sha256=sha(OLD/'manifest.json'),
               scope='24 recorded structural checks. No physical parameter or control algorithm change. Reference source not redistributed.')
        (HERE/'manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    m=json.loads((HERE/'manifest.json').read_text(encoding='utf-8'));assert snapshot()==m['files'];assert sha(OLD/'manifest.json')==m['v10_1_manifest_sha256']
    print('PASS: 18 MATLAB + 6 independent structural checks; sealed library/system/bench; all V10.1 dependency bytes preserved')
if __name__=='__main__':main()
