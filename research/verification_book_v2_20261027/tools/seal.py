"""Version only this V2 book and its reproduction dependencies."""
from pathlib import Path
import argparse,hashlib,json

HERE=Path(__file__).resolve().parents[1];ROOT=HERE.parents[1]
def main():
    p=argparse.ArgumentParser();p.add_argument('--seal',action='store_true');args=p.parse_args()
    delivery=json.loads((HERE/'evidence/delivery.json').read_text(encoding='utf-8'))
    assert delivery['pass_'] and delivery['python_checks']==145 and delivery['matlab_checks']==12
    target=HERE/'manifest.json'
    paths=[f for f in HERE.rglob('*') if f.is_file() and f!=target and '__pycache__' not in f.parts]
    paths+=[ROOT/'全角HRG验证总书第二版_逐行推导与复算.md',ROOT/'全角HRG从零到当前_完整推导与验证总书.md',ROOT/'research/complete_book_20261027/manifest.json']
    for name in ('literature_v7','literature_v8_research','literature_zotero_research','identifiability_v9'):
        paths.append(ROOT/'HRG_WA_simulink'/name/'evidence/manifest.json')
    hashes={f.relative_to(ROOT).as_posix():hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(set(paths))}
    data=dict(date='2026-10-27',scope='V2 derivation and scalar ODE verification; not RF/RTL rerun',sha256=hashes)
    if args.seal:target.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    else:assert json.loads(target.read_text(encoding='utf-8'))==data,'Changed or unsealed V2 dependency'
    print(json.dumps(dict(pass_=True,dependencies=len(hashes))))
if __name__=='__main__':main()
