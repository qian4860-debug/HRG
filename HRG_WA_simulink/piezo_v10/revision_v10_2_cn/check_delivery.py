from pathlib import Path
import argparse,hashlib,json,zipfile
HERE=Path(__file__).resolve().parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def code(s):return '\n'.join(x for x in s.splitlines() if x.strip() and not x.lstrip().startswith('%'))
def evidence():
    sources=json.loads((HERE/'evidence/source_hashes.json').read_text())
    for n,h in sources.items():assert sha(HERE.parent/n)==h,n
    count=0
    for p in HERE.glob('pcn_*.m'):
        old=HERE.parent/'revision_v10_1'/p.name.replace('pcn_','p101_')
        if old.exists():
            assert code(p.read_text(encoding='utf-8'))==code(old.read_text(encoding='utf-8').replace('p101_','pcn_')),p.name
            count+=1
    assert count==15
    r=json.loads((HERE/'evidence/results.json').read_text());assert len(r['checks'])==18 and all(r['checks'].values())
    for p in (HERE/'models').glob('*.slx'):
        with zipfile.ZipFile(p) as z:
            xml='\n'.join(z.read(n).decode('utf-8') for n in z.namelist() if n.startswith('simulink/systems/') and n.endswith('.xml'))
            assert 'Annotation' in xml and any('\u4e00'<=c<='\u9fff' for c in xml),p.name
    assert len(list((HERE/'models').glob('*.slx')))==3
def snapshot():
    return {p.relative_to(HERE).as_posix():sha(p) for p in sorted(HERE.rglob('*')) if p.is_file() and p.suffix in {'.m','.py','.md','.json','.slx','.png'} and p.name!='manifest.json' and '__pycache__' not in p.parts}
def main():
    a=argparse.ArgumentParser();a.add_argument('--seal',action='store_true');args=a.parse_args();evidence()
    if args.seal:
        for p in HERE.rglob('*'):
            if p.is_file() and p.suffix in {'.m','.py','.json','.md'}:
                raw=p.read_bytes();new=raw.replace(b'\r\n',b'\n')
                if raw!=new:p.write_bytes(new)
        (HERE/'manifest.json').write_text(json.dumps({'date':'2026-11-02','files':snapshot()},ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    assert snapshot()==json.loads((HERE/'manifest.json').read_text(encoding='utf-8'))['files']
    print('PASS: 15 comment-only core copies, 18 MATLAB checks, three Chinese-annotated SLX, preserved source hashes')
if __name__=='__main__':main()
