from pathlib import Path
import json,hashlib,sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 r=json.loads((HERE/'evidence/results.json').read_text());assert len(r['checks'])==8 and all(r['checks'].values())
 independent=json.loads((HERE/'evidence/independent_checks.json').read_text());assert len(independent)==6 and all(v['passed'] for v in independent.values())
 p=json.loads((HERE/'evidence/parameters.json').read_text());assert not any(k in p for k in ['mass','theta_s','theta_d','amp']);assert p['B']==[] and p['Omega']==0
 for s in json.loads((HERE/'sources.json').read_text(encoding='utf-8')):assert sha(Path(s['path']))==s['sha256']
 files=[p for p in HERE.rglob('*') if p.is_file() and p.name!='manifest.json' and '__pycache__' not in p.parts]
 files += [ROOT/'V10优化研究_缺少表头参数时的电荷域闭环.md',HERE.parent/'p10_adc_sfun.m',HERE.parent/'verify_independent.py',HERE.parent/'identification/identified_profile.json']
 values={p.relative_to(ROOT).as_posix():sha(p) for p in files};manifest=HERE/'manifest.json'
 if '--seal' in sys.argv:manifest.write_text(json.dumps(values,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
 else:assert json.loads(manifest.read_text(encoding='utf-8'))==values
 print('PASS: 8 MATLAB/Simulink + 6 independent checks; electrical states, no physical head parameters')
if __name__=='__main__':main()
