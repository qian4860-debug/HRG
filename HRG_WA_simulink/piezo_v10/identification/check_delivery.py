from pathlib import Path
import json,hashlib,sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 a=json.loads((HERE/'identification_results.json').read_text());b=json.loads((HERE/'matlab_identification_checks.json').read_text())
 assert len(a['checks'])==5 and all(a['checks'].values())
 assert len(b['checks'])==4 and all(b['checks'].values())
 p=json.loads((HERE/'identified_profile.json').read_text())
 assert p['status']=='synthetic_identification_only'
 assert all(p[k] is None for k in ['bryan_factor','drive_voltage_limit_V','displacement_limit_m'])
 book=ROOT/'V10压电表头_无厂家参数的测试辨识与回填方案.md'
 files=[p for p in HERE.iterdir() if p.is_file() and p.name!='manifest.json']+[book]
 values={p.relative_to(ROOT).as_posix():sha(p) for p in files}
 manifest=HERE/'manifest.json'
 if '--seal' in sys.argv:manifest.write_text(json.dumps(values,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
 else:
  expected=json.loads(manifest.read_text(encoding='utf-8'));assert expected==values
 print('PASS: 5 identification and 4 MATLAB replay checks; missing independent limits remain null')
if __name__=='__main__':main()
