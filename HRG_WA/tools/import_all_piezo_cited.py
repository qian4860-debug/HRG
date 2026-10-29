"""Screen accessible PDF opening pages and their publisher-deposited citations.
Automated relevance screening, never a claim that every paper was read.
"""
from pathlib import Path
import json,re,hashlib,sys
from concurrent.futures import ThreadPoolExecutor,as_completed
from pypdf import PdfReader
from acquire_piezo_hrg import norm
from import_v10_cited import get,resolve
import import_zotero_bibliography as imp
from import_scholar_151910 import BatchAPI
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'research/all_piezo_cited_20261029';WORK=ROOT/'HRG_WA_simulink/layered/_work/all_piezo_cited'
def relevant(t):
 t=t.lower()
 return bool(re.search(r'hemispher|micro.hrg|whole.angle|rate.integrat|piezo|vibratory gyro|electrode.shap|modal sensor|modal actuator',t))
def parent(p):
 try:
  r=PdfReader(p);head='\n'.join((x.extract_text() or '') for x in r.pages[:2])
  text=head[:2200].lower()
  if not (relevant(text) and re.search('gyro|hemispher|electrode.shap|modal sensor|modal actuator',text)):return None
  ds=list(dict.fromkeys(re.findall(r'10\.\d{4,9}/[A-Za-z0-9._()/-]+',head[:2400])))
  for doi in ds[:2]:
   try:
    d=get(doi.rstrip('.'));title=' '.join(d.get('title',[]))
    if len(norm(title))>20 and norm(title) in norm(head[:2400]):return dict(path=str(p),doi=d['DOI'],title=title,reference=d.get('reference',[]),basis='opening_pages_and_DOI_title_match_not_full_reading')
   except Exception:pass
 except Exception:pass
 return None
def main():
 OUT.mkdir(parents=True,exist_ok=True);WORK.mkdir(parents=True,exist_ok=True)
 paths=list(Path('D:/学习资料/资料/全角陀螺').rglob('*.pdf'))+list(Path('C:/Users/11725/Zotero/storage').rglob('*.pdf'))
 unique={}
 for p in paths:
  try:unique.setdefault(hashlib.sha256(p.read_bytes()).hexdigest(),p)
  except OSError:pass
 parents={};print('Unique accessible PDF byte objects:',len(unique),flush=True)
 with ThreadPoolExecutor(max_workers=4) as pool:
  for f in as_completed([pool.submit(parent,p) for p in unique.values()]):
   d=f.result()
   if d:parents.setdefault(d['doi'].lower(),d)
 imp.save(OUT/'parents.json',dict(scanned_pdf_objects=len(unique),parents=list(parents.values()),boundary='Automated opening-page screening; unresolved/scanned-only PDFs are not covered; no exhaustive relevance claim'))
 matched={str(Path(d['path']).resolve()) for d in parents.values()}
 imp.save(OUT/'coverage.json',dict(boundary='Unmatched is not proof of irrelevance',files=[dict(sha256=h,path=str(p),status='matched_parent' if str(p.resolve()) in matched else 'not_selected_or_unresolved_not_proven_irrelevant') for h,p in unique.items()]))
 edges=[]
 for d in parents.values():
  for n,r in enumerate(d['reference'],1):edges.append(dict(parent_doi=d['doi'],index=n,citation=r))
 dois={r['citation'].get('DOI') for r in edges if r['citation'].get('DOI')};meta={}
 with ThreadPoolExecutor(max_workers=4) as pool:
  futures={pool.submit(resolve,{'DOI':doi}):doi for doi in dois}
  for f in as_completed(futures):meta[futures[f]]=f.result()
 rows=[];selected=[];pending=[]
 for e in edges:
  r=e['citation'];d=meta.get(r.get('DOI'),{});title=' '.join(d.get('title',[])) or r.get('article-title') or r.get('unstructured','')
  if not title or not relevant(title):pending.append(e);continue
  doi=d.get('DOI') or r.get('DOI');yr=r.get('year','')
  if d.get('published',{}).get('date-parts'):yr=d['published']['date-parts'][0][0]
  key=hashlib.sha256((e['parent_doi']+':'+str(e['index'])).encode()).hexdigest()[:24]
  rows.append(dict(id=key,title=title,year=yr,author=r.get('author',''),href='https://doi.org/'+doi if doi else '',keyword='Automated relevance screening; cited by '+e['parent_doi']+' reference '+str(e['index']),page='',pos=e['index'],citations=''))
  selected.append(dict(**e,resolved_title=title,relevance='Title-screened direct or methodological candidate; not scientifically adjudicated'))
 imp.save(OUT/'selected_edges.json',selected);imp.save(WORK/'unselected_or_unresolved.json',pending)
 source=WORK/'references.json';imp.save(source,rows)
 lib=Path('D:/学习资料/资料/全角陀螺/压电全角引文扩展_20261029');lib.mkdir(parents=True,exist_ok=True)
 for name in ['parents.json','selected_edges.json']:(lib/name).write_bytes((OUT/name).read_bytes())
 (lib/'references.json').write_bytes(source.read_bytes())
 print('Parents',len(parents),'reference occurrences',len(edges),'selected',len(rows),'pending/unselected',len(pending),flush=True)
 imp.WORK=WORK;imp.PUBLIC=OUT;imp.DATE='2026-10-29';imp.BATCH='压电全角_跨全文一级引文_20261029';imp.LocalAPI=BatchAPI
 sys.argv=[sys.argv[0],str(source),'--apply'];imp.main()
 (lib/'summary.json').write_bytes((OUT/'summary.json').read_bytes())
 (lib/'coverage.json').write_bytes((OUT/'coverage.json').read_bytes())
 print('Verified bibliography import complete; no new PDF acquisition claimed',flush=True)
if __name__=='__main__':main()
