"""Acquire the supplied Scholar export, preserving row identities and reading boundaries.

Uses public HTTP resources and the official Zotero local API only. Full texts,
personal inventory and extracted text remain local, outside public Git.
"""
from pathlib import Path
import argparse, collections, hashlib, html, json, re, sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from urllib.parse import urljoin, urlsplit, quote, urlencode
from difflib import SequenceMatcher
from acquire_piezo_hrg import fetch, inspect_pdf, norm, title_matches
import import_zotero_bibliography as zi
from zotero_wa_bridge import LocalAPI, attachment_path

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'research/scholar_piezo_20261029'
WORK=ROOT/'HRG_WA_simulink/layered/_work/scholar_piezo_20261029'
LIB=Path('D:/学习资料/资料/全角陀螺/Scholar压电专题_20261029')
SOURCE=Path('C:/Users/11725/Downloads/data_2026-10-29_12-24-02.json')
PROXY='http://127.0.0.1:7897'
BATCH='Scholar压电半球_2026-10-29_203条'

def save(p,v):
    p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def collect():
    if (OUT/'manifest.json').exists():raise RuntimeError('Batch already initialized; do not overwrite its acquisition/review history')
    rows=json.loads(SOURCE.read_text(encoding='utf-8-sig')); fingerprint=sha(SOURCE)
    WORK.mkdir(parents=True,exist_ok=True)
    (WORK/'source_original.json').write_bytes(SOURCE.read_bytes())
    save(WORK/'source.json',rows)
    held=[]
    for p in LIB.parent.rglob('*.pdf'):
        try:
            info=inspect_pdf(p.read_bytes()); held.append((p,info))
        except Exception:pass
    save(WORK/'local_pdf_index.json',[dict(path=p.as_posix(),**i) for p,i in held])
    records=[]
    for n,r in enumerate(rows,1):
        title=r.get('title',''); good=zi.valid_title(title) and '…' not in title and '...' not in title
        found=None
        for p,i in held:
            # A title in the references is insufficient: require filename plus opening title.
            if good and len(norm(title))>=30 and norm(title)[:55] in norm(p.stem) and title_matches(title,i['head']):
                found=(p,i);break
        rec=dict(row=n,source_id=r['id'],title=title,url=r.get('href',''),year=r.get('year',''),keyword=r.get('keyword',''),
                 status='not_obtained',attempts=[],reading_status='not_read',identity_complete=good)
        if found:
            p,i=found;rec.update(status='existing_fulltext',path=p.as_posix(),**{k:v for k,v in i.items() if k!='head'})
        records.append(rec)
    save(OUT/'manifest.json',dict(source_sha256=fingerprint,source_records=len(rows),records=records))
    print('Rows:',len(rows),'local matches:',sum(r['status']=='existing_fulltext' for r in records),flush=True)

def acquire(r):
    if r['status']!='not_obtained' or not r['identity_complete']:return r
    u=r['url']; candidates=list(r.get('public_pdf_candidates',[]))+([u] if u.startswith('http') else [])
    if 'nature.com/articles/' in u:candidates.insert(0,u.split('?')[0]+'.pdf')
    if 'mdpi.com/' in u:candidates.insert(0,u.rstrip('/')+'/pdf')
    if 'iopscience.iop.org/article/' in u:candidates.insert(0,u.removesuffix('/meta').rstrip('/')+'/pdf')
    tried=set()
    for u in candidates:
        if u in tried:continue
        tried.add(u)
        try:
            data,final,kind=fetch(u,PROXY)
            if not data.lstrip().startswith(b'%PDF-'):
                txt=data.decode('utf-8','replace')
                # Only explicit publisher/repository fulltext metadata, no guessed access tokens.
                for tag in re.findall(r'<meta\b[^>]+>',txt,re.I):
                    if re.search(r'(citation_pdf_url|DC\.identifier\.uri)',tag,re.I):
                        m=re.search(r'content=["\']([^"\']+)',tag,re.I)
                        if m:
                            v=urljoin(final,html.unescape(m[1]))
                            if v not in tried:candidates.append(v)
                r['attempts'].append(dict(url=u,result='landing_page_no_validated_pdf'))
                if len(tried)>=4:break
                continue
            info=inspect_pdf(data)
            if not title_matches(r['title'],info.pop('head')):
                r['attempts'].append(dict(url=u,result='opening_title_not_confirmed'));continue
            name=re.sub(r'[<>:"/\\|?*]','_',r['title'])[:130]
            path=LIB/'pdf'/f"S{r['row']:03d}_{name}.pdf"
            path.parent.mkdir(parents=True,exist_ok=True)
            if path.exists():assert sha(path)==info['sha256']
            else:path.write_bytes(data)
            r.update(status='downloaded_fulltext',path=path.as_posix(),source_url=u,final_url=final,**info)
            break
        except Exception as e:r['attempts'].append(dict(url=u,error=str(e)))
    return r

def download():
    m=json.loads((OUT/'manifest.json').read_text(encoding='utf-8'))
    result=[]
    with ThreadPoolExecutor(max_workers=4) as pool:
        for f in as_completed([pool.submit(acquire,r) for r in m['records']]):
            r=f.result();result.append(r)
            print(r['row'],r['status'],flush=True)
            m['records']=sorted(result,key=lambda x:x['row']);save(WORK/'download_progress.json',m)
    m['records']=sorted(result,key=lambda x:x['row']);m['counts']=dict(collections.Counter(r['status'] for r in result))
    save(OUT/'manifest.json',m);save(LIB/'manifest.json',m)

def extract():
    from pypdf import PdfReader
    m=json.loads((OUT/'manifest.json').read_text(encoding='utf-8'));pages={}
    for r in m['records']:
        if not r.get('path'):continue
        p=Path(r['path']);h=sha(p);target=WORK/'text'/f'{h}.json'
        if not target.exists():
            try:
                reader=PdfReader(p);text=[page.extract_text() or '' for page in reader.pages]
            except Exception:
                import pdfplumber
                with pdfplumber.open(p) as pdf:text=[page.extract_text() or '' for page in pdf.pages]
            save(target,dict(path=p.as_posix(),sha256=h,pages=text))
        d=json.loads(target.read_text(encoding='utf-8'))
        pages[h]=len(d['pages']);r['text_extraction_pages']=len(d['pages'])
        r['reading_status']='text_extracted_not_yet_scientifically_read'
    m['distinct_extracted_pdfs']=len(pages);m['extracted_pages']=sum(pages.values())
    save(OUT/'manifest.json',m);print('Extracted:',len(pages),sum(pages.values()),flush=True)

def zotero():
    zi.WORK=WORK;zi.PUBLIC=OUT;zi.DATE='2026-10-29';zi.BATCH=BATCH
    sys.argv=[sys.argv[0],str(SOURCE),'--apply'];zi.main()
    attach()

def attach():
    api=LocalAPI();api.request('/api/')
    items=api.request('/api/users/0/items?includeTrashed=0')
    resolved=json.loads((WORK/'resolved.json').read_text(encoding='utf-8'))
    bysource={r['source_id']:r['key'] for r in resolved}
    m=json.loads((OUT/'manifest.json').read_text(encoding='utf-8'))
    existing=set()
    for i in items:
        if i['data'].get('itemType')=='attachment':
            p=attachment_path(i)
            if p and p.is_file():existing.add((i['data'].get('parentItem'),sha(p)))
    create=[];expected=set()
    for r in m['records']:
        if not r.get('path'):continue
        key=bysource[r['source_id']];pair=(key,r['sha256']);expected.add(pair)
        if pair in existing:continue
        existing.add(pair)
        create.append(dict(itemType='attachment',linkMode='linked_file',path=r['path'],parentItem=key,
            title=Path(r['path']).name,contentType='application/pdf',tags=[{'tag':'压电专题全文_20261029'}]))
    if create:api.write_many('/api/users/0/items',create)
    after=api.request('/api/users/0/items?includeTrashed=0');actual=set()
    for i in after:
        if i['data'].get('itemType')=='attachment':
            p=attachment_path(i)
            if p and p.is_file():actual.add((i['data'].get('parentItem'),sha(p)))
    assert expected<=actual
    save(OUT/'attachment_receipt.json',dict(created=len(create),verified_parent_hash_pairs=len(expected),all_paths_accessible=True))
    print('Attachment verification:',len(expected),'created',len(create),flush=True)

def audit():
    """Opening-page manual identity decisions; never delete rejected source bytes."""
    m=json.loads((OUT/'manifest.json').read_text(encoding='utf-8'))
    idx=json.loads((WORK/'local_pdf_index.json').read_text(encoding='utf-8'))
    for r in m['records']:
        # Manually checked opening-page identity (not filename similarity).
        if r['row'] in (7,47) and not r.get('path'):
            candidates=[p for p in idx if norm(r['title']) in norm(p['head'][:1400])]
            assert len(candidates)==1
            d=candidates[0]
            r.update(**{k:v for k,v in d.items() if k!='head'},status='existing_fulltext',identity_basis='manually_reviewed_opening_title')
        if r['row'] in (10,174) and r.get('path'):
            r['rejected_candidate_path']=r.pop('path')
            r['rejected_candidate_sha256']=r.pop('sha256')
            r['status']='not_obtained'
            r['identity_rejection']='Different article with generic title overlap' if r['row']==10 else 'Conference programme containing talk title, not target full text'
            r['reading_status']='candidate_identity_rejected'
        if r['row']==192:r['resource_type']='Continuing education course, not journal paper'
    m['counts']=dict(collections.Counter(r['status'] for r in m['records']))
    valid={r['sha256']:r['text_extraction_pages'] for r in m['records'] if r.get('path') and r.get('text_extraction_pages')}
    m['distinct_extracted_pdfs']=len(valid);m['extracted_pages']=sum(valid.values())
    save(OUT/'manifest.json',m)
    print(m['counts'],m['extracted_pages'])

def annotate():
    """Add explicit screening boundaries to Zotero, never replace bibliography."""
    api=LocalAPI();api.request('/api/')
    items=api.request('/api/users/0/items?includeTrashed=0');bykey={i['key']:i for i in items}
    rows=json.loads((OUT/'relevance_review.json').read_text(encoding='utf-8'))['records']
    resolved=json.loads((WORK/'resolved.json').read_text(encoding='utf-8'))
    mapping={r['source_id']:r['key'] for r in resolved}
    grouped={}
    for r in rows:grouped.setdefault(mapping[r['source_id']],[]).append(r)
    updates=[];notes=[];marker='HRG_PIEZO_REVIEW_20261029'
    existing={i['data'].get('parentItem') for i in items if marker in i['data'].get('note','')}
    for key,rs in grouped.items():
        old=bykey[key];tags=list(old['data'].get('tags',[]));known={t['tag'] for t in tags}
        new=['压电专题_逐条相关性初筛']
        if any('RETRACTED' in r['title'].upper() for r in rs):new+=['撤稿题录_不可作设计依据']
        if any(r['title']=='标题不可用' for r in rs):new+=['题名待补全']
        for t in new:
            if t not in known:tags.append({'tag':t})
        if tags!=old['data'].get('tags',[]):updates.append(dict(key=key,version=old['version'],tags=tags))
        if key not in existing:
            body='<p>'+marker+'</p><p>检索初筛不等于全文通读。以下只记录明确的阅读证据。</p>'
            for r in rs:body+='<p>'+html.escape(f"S{r['row']:03d}：{r['reading_status']}；{r['reviewed_pages']}；{r['reason']}")+'</p>'
            notes.append(dict(itemType='note',parentItem=key,note=body,tags=[{'tag':marker}]))
    if updates:api.write_many('/api/users/0/items',updates)
    if notes:api.write_many('/api/users/0/items',notes)
    final=api.request('/api/users/0/items?includeTrashed=0')
    held={i['data'].get('parentItem') for i in final if marker in i['data'].get('note','')}
    assert set(grouped)<=held
    save(OUT/'review_note_receipt.json',dict(unique_parent_entries=len(grouped),notes_created=len(notes),all_parent_notes_verified=True))
    print('Review notes verified',len(grouped),flush=True)

def resolve_one(r):
    if r['status']!='not_obtained' or not r['identity_complete']:return r
    try:
        raw,_,_=fetch('https://api.crossref.org/works?'+urlencode({'query.title':r['title'],'rows':1}),PROXY)
        choices=json.loads(raw)['message']['items']
        if not choices:return r
        d=choices[0];title=' '.join(d.get('title',[]))
        if SequenceMatcher(None,norm(title),norm(r['title'])).ratio()<.97:return r
        r['verified_doi']=d['DOI'];r['metadata_title']=title
        links=[x['URL'] for x in d.get('link',[]) if x.get('content-type')=='application/pdf']
        try:
            raw,_,_=fetch('https://api.openalex.org/works/https://doi.org/'+quote(d['DOI'],safe='/'),PROXY)
            oa=json.loads(raw)
            links+=[x['pdf_url'] for x in oa.get('locations',[]) if x.get('is_oa') and x.get('pdf_url')]
        except Exception as e:r['openalex_error']=str(e)
        r['public_pdf_candidates']=list(dict.fromkeys(links))
        # Try only newly discovered public PDF endpoints, not the same failed page again.
        for u in r['public_pdf_candidates']:
            try:
                raw,final,_=fetch(u,PROXY);info=inspect_pdf(raw)
                if not title_matches(r['title'],info.pop('head')):continue
                name=re.sub(r'[<>:"/\\|?*]','_',r['title'])[:130]
                p=LIB/'pdf'/f"S{r['row']:03d}_{name}.pdf";p.parent.mkdir(parents=True,exist_ok=True)
                if p.exists():assert sha(p)==info['sha256']
                else:p.write_bytes(raw)
                r.update(status='downloaded_fulltext',path=p.as_posix(),source_url=u,final_url=final,**info)
                break
            except Exception as e:r['attempts'].append(dict(url=u,error=str(e)))
    except Exception as e:r['metadata_error']=str(e)
    return r

def resolve():
    m=json.loads((OUT/'manifest.json').read_text(encoding='utf-8'));result=[]
    with ThreadPoolExecutor(max_workers=4) as pool:
        for f in as_completed([pool.submit(resolve_one,r) for r in m['records']]):
            r=f.result();result.append(r)
            if r.get('verified_doi'):print(r['row'],r['status'],r['verified_doi'],flush=True)
            save(WORK/'resolve_progress.json',dict(records=sorted(result,key=lambda r:r['row'])))
    m['records']=sorted(result,key=lambda r:r['row']);m['counts']=dict(collections.Counter(r['status'] for r in result))
    save(OUT/'manifest.json',m)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['collect','download','extract','zotero','audit','resolve','annotate','attach']);args=p.parse_args()
    globals()[args.action]()
