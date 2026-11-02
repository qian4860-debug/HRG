"""Independent display-value arithmetic and delivery byte checks."""
from pathlib import Path
import argparse,hashlib,json
import numpy as np
HERE=Path(__file__).resolve().parent;OLD=HERE.parent/'revision_v10_2_cn'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def checks():
    r=json.loads((HERE/'evidence/quality_results.json').read_text());v=json.loads((HERE/'evidence/verification.json').read_text())
    assert len(v['checks'])==9 and all(v['checks'].values())
    assert all(r['checks'].values())
    f=np.genfromtxt(HERE/'evidence/quality_frames.csv',delimiter=',',names=True);t=f['source_center_s'];h=(t>.48)&(f['valid']==1)
    assert len(t)==800 and np.all(np.diff(t)>0)
    assert abs(np.sqrt(np.mean(f['body_angle_error_deg'][h]**2))-r['metrics']['angle_rms_deg'])<1e-12
    assert abs(np.mean(f['energy_normalized'][h])-r['normalized_energy_mean'])<1e-12
    assert abs(np.sqrt(np.mean(f['quadrature'][h]**2))-r['quadrature_RMS'])<1e-12
    assert abs(np.sqrt(np.mean(f['PLL_detector'][h]**2))-r['PLL_detector_RMS'])<1e-12
    for name,target in [('window_us',975),('center_offset_us',487.5),('publication_delay_us',25)]:assert np.max(abs(f[name]-target))<1e-6
    old=json.loads((OLD/'manifest.json').read_text(encoding='utf-8'))
    for name,hsh in old['files'].items():assert sha(OLD/name)==hsh,name
def snapshot():
    return {p.relative_to(HERE).as_posix():sha(p) for p in sorted(HERE.rglob('*')) if p.is_file() and p.suffix in {'.m','.py','.md','.json','.csv','.txt','.html','.png','.slx'} and p.name!='manifest.json' and '__pycache__' not in p.parts}
def main():
    a=argparse.ArgumentParser();a.add_argument('--seal',action='store_true');args=a.parse_args();checks()
    if args.seal:
        for p in HERE.rglob('*'):
            if p.is_file() and p.suffix in {'.m','.py','.md','.json','.csv','.txt','.html'}:
                b=p.read_bytes();n=b.replace(b'\r\n',b'\n')
                if b!=n:p.write_bytes(n)
        m={'date':'2026-11-02','files':snapshot(),'dependency_manifest':sha(OLD/'manifest.json')}
        (HERE/'manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    m=json.loads((HERE/'manifest.json').read_text(encoding='utf-8'));assert snapshot()==m['files'];assert sha(OLD/'manifest.json')==m['dependency_manifest']
    print('PASS: nine MATLAB checks, independent frame/score/unit arithmetic, quality artifacts and original CN bytes')
if __name__=='__main__':main()
