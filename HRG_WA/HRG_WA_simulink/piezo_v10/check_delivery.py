from pathlib import Path
import hashlib,json
V=Path(__file__).resolve().parent;ROOT=V.parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 m=json.loads((V/'manifest.json').read_text(encoding='utf-8'))
 for name,h in m['files'].items():assert sha(ROOT/name)==h,name
 assert sha(ROOT/'压电全角总书第三版_原理到V10实现.md')==m['book_sha256']
 for name,h in m['previous_books'].items():assert sha(ROOT/name)==h,name
 r=json.loads((V/'evidence/results.json').read_text());assert len(r['checks'])==15 and all(r['checks'].values())
 r=json.loads((V/'evidence/independent_checks.json').read_text());assert all(c['passed'] for c in r['checks'].values())
 for s in json.loads((V/'sources.json').read_text(encoding='utf-8')):assert sha(Path(s['path']))==s['sha256']
 print('PASS: sealed sources/model/evidence/book; 15 MATLAB and 6 independent checks; previous books unchanged')
if __name__=='__main__':main()
