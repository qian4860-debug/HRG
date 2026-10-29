"""Import first-level references of the six V10 core papers, retaining citation edges."""
from pathlib import Path
import json,sys,hashlib
from concurrent.futures import ThreadPoolExecutor
from urllib.parse import quote
from acquire_piezo_hrg import fetch
import import_zotero_bibliography as imp
from import_scholar_151910 import BatchAPI
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'research/v10_cited_20261029';WORK=ROOT/'HRG_WA_simulink/layered/_work/v10_cited'
def get(doi):return json.loads(fetch('https://api.crossref.org/works/'+quote(doi,safe=''),'http://127.0.0.1:7897')[0])['message']
def resolve(r):
 try:
  if r.get('DOI'):return get(r['DOI'])
 except Exception:pass
 return {}
def main():
 OUT.mkdir(parents=True,exist_ok=True);WORK.mkdir(parents=True,exist_ok=True)
 sources=json.loads((ROOT/'HRG_WA_simulink/piezo_v10/sources.json').read_text(encoding='utf-8'));edges=[];errors=[]
 for s in sources:
  doi=s.get('doi') or '10.1038/s41598-020-80885-y'
  try:
   data=get(doi)
   for n,r in enumerate(data.get('reference',[]),1):edges.append(dict(parent_doi=doi,reference_index=n,citation=r))
  except Exception as e:errors.append(dict(parent_doi=doi,error=str(e)))
 imp.save(OUT/'citation_edges.json',dict(scope='Publisher-deposited first-level citations of six V10 core papers; not all 808 Scholar records or recursive citation closure',edges=edges,errors=errors))
 with ThreadPoolExecutor(max_workers=4) as pool:metadata=list(pool.map(resolve,[e['citation'] for e in edges]))
 rows=[]
 for n,(e,d) in enumerate(zip(edges,metadata),1):
  r=e['citation'];title=' '.join(d.get('title',[])) or r.get('article-title') or '[待核对引文] '+r.get('unstructured',json.dumps(r,ensure_ascii=False))[:180]
  doi=d.get('DOI') or r.get('DOI');yr=r.get('year','')
  if d.get('published',{}).get('date-parts'):yr=d['published']['date-parts'][0][0]
  rows.append(dict(id='cited_'+hashlib.sha256((e['parent_doi']+':'+str(e['reference_index'])).encode()).hexdigest()[:20],title=title,year=yr,author=r.get('author',''),href='https://doi.org/'+doi if doi else '',keyword='Cited by '+e['parent_doi']+'; source reference '+str(e['reference_index']),page='',pos=n,citations=''))
 source=WORK/'references.json';imp.save(source,rows)
 library=Path('D:/学习资料/资料/全角陀螺/V10引用文献_20261029');library.mkdir(parents=True,exist_ok=True)
 imp.save(library/'citation_edges.json',dict(edges=edges,errors=errors));imp.save(library/'references.json',rows)
 imp.WORK=WORK;imp.PUBLIC=OUT;imp.DATE='2026-10-29';imp.BATCH='V10核心论文_一级引用_20261029';imp.LocalAPI=BatchAPI
 print('Citation rows prepared:',len(rows),flush=True)
 sys.argv=[sys.argv[0],str(source),'--apply'];imp.main()
 imp.save(library/'summary.json',json.loads((OUT/'summary.json').read_text(encoding='utf-8')))
 skill=Path('C:/Users/11725/.codex/skills/ic-reference-library/references');imp.save(skill/'v10-cited-20261029.json',dict(library=str(library),summary=json.loads((OUT/'summary.json').read_text(encoding='utf-8'))))
 print('Cited bibliography archived and verified',flush=True)
if __name__=='__main__':main()
