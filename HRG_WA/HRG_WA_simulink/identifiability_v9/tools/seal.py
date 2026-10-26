"""Verify or explicitly seal every acceptance dependency in this branch."""
from pathlib import Path
import argparse
import hashlib
import json

ROOT=Path(__file__).resolve().parents[1]
REPO=ROOT.parents[1]
def main():
    p=argparse.ArgumentParser();p.add_argument('--seal',action='store_true');args=p.parse_args()
    if args.seal:
        for f in ROOT.rglob('*'):
            if f.is_file() and f.suffix in ('.m','.py','.md','.json','.csv','.txt'):
                b=f.read_bytes();n=b.replace(b'\r\n',b'\n')
                if b!=n:f.write_bytes(n)
    result=json.loads((ROOT/'evidence/verification.json').read_text(encoding='utf-8'))
    core=json.loads((ROOT/'evidence/core_study.json').read_text(encoding='utf-8'))
    rf=json.loads((ROOT/'evidence/rf_study.json').read_text(encoding='utf-8'))
    delivery=json.loads((ROOT/'evidence/delivery.json').read_text(encoding='utf-8'))
    assert result['pass_'] and core['pass'] and rf['pass'] and delivery['pass']
    assert rf['reopenedCompiled'] and rf['scopes']==21 and rf['spectra']==16 and rf['spectrumRateError']==0
    assert len(delivery['models'])==3 and all(m['reopenedCompiled'] for m in delivery['models'])
    target=ROOT/'evidence/manifest.json'
    paths=[f for f in ROOT.rglob('*') if f.is_file() and f!=target and '__pycache__' not in f.parts]
    dependencies=[ROOT.parent/f'{name}/evidence/manifest.json' for name in ('literature_v7','literature_v8_research','literature_zotero_research')]
    paths+=dependencies
    hashes={f.relative_to(REPO).as_posix():hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(paths)}
    if args.seal:target.write_text(json.dumps(dict(date='2026-10-26',sha256=hashes),indent=2)+'\n',encoding='utf-8',newline='\n')
    else:assert json.loads(target.read_text(encoding='utf-8'))['sha256']==hashes,'Changed or unsealed acceptance artifact'
    print(json.dumps(dict(pass_=True,sealed_dependencies=len(hashes),independent_checks=len(result['checks']))))
if __name__=='__main__':main()
