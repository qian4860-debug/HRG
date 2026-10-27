"""Seal this document release only after successful documentation validation."""
from pathlib import Path
import argparse
import hashlib
import json
from inventory import ROOT,HERE

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--seal',action='store_true')
    args=parser.parse_args()
    result=json.loads((HERE/'validation.json').read_text(encoding='utf-8'))
    assert result['pass_'],'Document validation must pass before sealing'
    target=HERE/'manifest.json'
    paths=[p for p in HERE.rglob('*') if p.is_file() and p!=target and '__pycache__' not in p.parts]
    paths.append(ROOT/'全角HRG从零到当前_完整推导与验证总书.md')
    coverage=json.loads((HERE/'coverage.json').read_text(encoding='utf-8'))
    source_identities=[]
    for row in coverage['rows']:
        raw=(ROOT/row['path']).read_bytes()
        assert hashlib.sha256(raw).hexdigest() in (row['sha256'],row['git_sha256']),row['path']
        assert hashlib.sha256(raw.replace(b'\r\n',b'\n')).hexdigest()==row['normalized_sha256'],row['path']
        source_identities.append({k:row[k] for k in ('path','sha256','git_sha256','normalized_sha256')})
    for branch in ('literature_v7','literature_v8_research','literature_zotero_research','identifiability_v9'):
        paths.append(ROOT/'HRG_WA_simulink'/branch/'evidence/manifest.json')
    hashes={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(set(paths))}
    data=dict(date='2026-10-27',scope='Complete book, compilation tools, source MD and sealed-model identities',
              sha256=hashes,source_md=source_identities)
    if args.seal:target.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    else:assert json.loads(target.read_text(encoding='utf-8'))==data,'Changed or unsealed book dependency'
    print(json.dumps(dict(pass_=True,dependencies=len(hashes)+len(source_identities),document_checks=len(result['checks']))))

if __name__=='__main__':main()
