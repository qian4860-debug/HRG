"""Collect first-level references, resolve public metadata and acquire public PDFs.

No browser cookies, credentials, CAPTCHA solving or paywall bypass. Source PDFs
are read only. Download bytes live in the local reference library; code, citation
edges and acquisition evidence are versioned separately in the HRG project.
"""
from __future__ import annotations

import argparse
import copy
from collections import Counter
from concurrent.futures import ThreadPoolExecutor, as_completed
import difflib
import hashlib
import html
import io
import json
import logging
from pathlib import Path
import re
import threading
import time
import unicodedata
import urllib.parse
import urllib.request

from pypdf import PdfReader

logging.getLogger('pypdf').setLevel(logging.ERROR)
PROJECT=Path(__file__).resolve().parents[1]
REPORT=PROJECT/'research/literature_acquisition_20261023'
WORK=PROJECT/'HRG_WA_simulink/layered/_work/literature_download'
CATALOG=PROJECT/'HRG_WA_simulink/layered/evidence/literature_comparison/comparison_catalog.json'
DEFAULT_LIBRARY=Path('D:/学习资料/资料/全角陀螺/引用文献_20261023')
PAPER_IDS={'L002','L003','L006','L033','L035','L038','L039','L048','L050',
 'L052','L053','L054','L055','L056','L057','L058','L059','L061','L062',
 'L063','L064','L065','L070','L071','L072','L073'}
LOCK=threading.Lock()


def save(path,data):
    path.parent.mkdir(parents=True,exist_ok=True)
    content=json.dumps(data,ensure_ascii=False,indent=2)+'\n'
    temp=path.with_name(path.name+f'.{threading.get_ident()}.tmp')
    for attempt in range(4):
        try:
            temp.write_text(content,encoding='utf-8',newline='\n')
            temp.replace(path)
            return
        except OSError:
            if attempt==3:raise
            time.sleep(.15*(attempt+1))


def digest(data):
    return hashlib.sha256(data).hexdigest()


def norm(text):
    text=unicodedata.normalize('NFKC',html.unescape(text)).lower()
    return re.sub(r'[^a-z0-9\u3400-\u9fff]','',text)


def clean_doi(text):
    text=urllib.parse.unquote(text).strip().rstrip('.,;)]}')
    text=re.sub(r'^https?://(?:dx\.)?doi\.org/','',text,flags=re.I)
    text=re.sub(r'\.\((?:19|20)\d{2}.*$','',text)
    return text.lower()


def dois(text):
    text=unicodedata.normalize('NFKC',text)
    text=re.sub(r'(10\.)\s+(\d{4,9})',r'\1\2',text)
    text=re.sub(r'(10\.1016/j\.)\s+',r'\1',text,flags=re.I)
    text=re.sub(r'(10\.\d{4,9}/[^\s]*[-/])\s+(?=[a-zA-Z0-9])',r'\1',text)
    return sorted({clean_doi(x) for x in re.findall(r'10\.\d{4,9}/[^\s<>"\[\]]+',text,re.I)})


def guess_title(raw):
    raw=re.sub(r'\s+',' ',raw).strip()
    prefix=re.split(r'\[[JCDMP]/?[A-Z]*\]',raw,flags=re.I)[0]
    if re.search(r'[\u3400-\u9fff]',prefix):
        bits=re.split(r'[.。]\s*',prefix,maxsplit=1)
        if len(bits)>1 and len(bits[1])>7:return bits[1].strip()
    # Initials immediately before a substantial title word; retain raw text if ambiguous.
    matches=list(re.finditer(r'\.\s+(?=[A-Z][a-z]{2})',prefix))
    if matches:
        tail=prefix[matches[0].end():]
        if '[' not in raw:
            tail=re.split(r'\.\s+(?=[A-Z])',tail,maxsplit=1)[0]
        if len(tail)>12:return tail.strip(' .')
    return prefix.strip(' .')[:300]


def pdf_pages(path,tail_only=False):
    try:
        reader=PdfReader(path)
        total=len(reader.pages)
        start=max(0,total-20) if tail_only else 0
        return total,[(n+1,reader.pages[n].extract_text() or '') for n in range(start,total)],'pypdf'
    except Exception:
        import pdfplumber
        with pdfplumber.open(path) as reader:
            total=len(reader.pages);start=max(0,total-20) if tail_only else 0
            return total,[(n+1,reader.pages[n].extract_text() or '') for n in range(start,total)],'pdfplumber'


def extract():
    cat=json.loads(CATALOG.read_text(encoding='utf-8-sig'))
    source_rows=[]; refs={}; existing=[]
    for row in cat['local']:
        path=Path(row['paths'][0])
        if row['id'] not in PAPER_IDS:continue
        record=dict(id=row['id'],path=path.as_posix(),sha256=row['sha256'],name=row['name'])
        try:
            if row['id'] in {'L052','L056','L058','L059','L061'}:
                import pdfplumber
                with pdfplumber.open(path) as reader:
                    total=len(reader.pages)
                    pages=[]
                    for n in range(max(0,total-3),total):
                        page=reader.pages[n]
                        left=page.crop((0,0,page.width/2,page.height)).extract_text() or ''
                        right=page.crop((page.width/2,0,page.width,page.height)).extract_text() or ''
                        pages.append((n+1,left+'\n'+right))
                parser='pdfplumber_two_columns'
            else:total,pages,parser=pdf_pages(path,True)
            record.update(pages=total,parser=parser)
            # Head text is used only for DOI/title matching to already-held originals.
            try:
                r=PdfReader(path);head='\n'.join(r.pages[n].extract_text() or '' for n in range(min(2,len(r.pages))))
            except Exception:head=''
            existing.append(dict(source_id=row['id'],path=path.as_posix(),sha256=row['sha256'],
                                 name=row['name'],title=row.get('title',''),head=head[:18000],dois=dois(head)))
            eligible=[(p,t) for p,t in pages if total<40 or p>total*.6]
            start=None
            for idx,(p,t) in enumerate(eligible):
                hits=list(re.finditer(r'(?im)^\s*(参\s*考\s*文\s*献(?:[（(]References[）)])?|R\s*EFERENCES|bibliography)\s*[:：]?\s*$',t))
                for hit in hits:
                    after=t[hit.end():]
                    following='\n'.join(x[1] for x in eligible[idx+1:idx+3])
                    if re.search(r'(\[\s*\d+\s*\]|(?m:^\s*\d+\.))\s*\S',after+'\n'+following) or row['id']=='L003':
                        start=(idx,hit.end());break
                if start:break
            if start is None:
                record.update(status='reference_heading_not_extracted',references=0)
                source_rows.append(record);print(row['id'],record['status'],flush=True);continue
            idx,offset=start
            text='\n'.join(f'\n@@PDFPAGE:{p}@@\n'+(t[offset:] if j==idx else t)
                           for j,(p,t) in enumerate(eligible) if j>=idx)
            bracketed=list(re.finditer(r'\[\s*(\d{1,3})\s*\]\s*(?=\S)',text))
            matches=bracketed if len(bracketed)>2 else list(re.finditer(r'(?m)^\s*(\d{1,3})\.\s+(?=\S)',text))
            author_year=False
            if row['id']=='L003':
                matches=list(re.finditer(r"(?m)^(?=[A-Z][A-Za-z’'-]+,\s)",text))
                author_year=True
            seen=set();count=0
            for n,m in enumerate(matches):
                raw=text[m.end():matches[n+1].start() if n+1<len(matches) else len(text)]
                raw=re.split(r'(?im)^(?:Disclaimer/Publisher|作者简介|攻读|致\s*谢|Acknowledgments)',raw)[0]
                pg=[int(x) for x in re.findall(r'@@PDFPAGE:(\d+)@@',text[:m.start()])]
                raw=re.sub(r'@@PDFPAGE:\d+@@','',raw)
                raw=re.sub(r'(?im)^\s*(?:万方数据|参考文献|东南大学硕士学位论文|哈尔滨工业大学硕士学位论文|\d{1,3})\s*$','',raw)
                raw=re.sub(r'\s+',' ',raw).strip()
                if len(raw)<18:continue
                title=guess_title(raw); ds=dois(raw)
                key='doi:'+ds[0] if ds else 'title:'+norm(title)
                edge=dict(source=row['id'],reference_number=n+1 if author_year else int(m.group(1)),
                          pdf_page=pg[-1] if pg else eligible[idx][0],raw=raw)
                localkey=edge['reference_number']
                if localkey in seen:continue
                seen.add(localkey)
                if key not in refs:
                    marker=re.search(r'\[([JCDMP])(?:/[A-Z]+)?\]',raw,re.I)
                    refs[key]=dict(key=key,title=title,doi=ds[0] if ds else None,
                        kind=marker.group(1).upper() if marker else 'unknown',citations=[],status='unresolved')
                refs[key]['citations'].append(edge);count+=1
            record.update(status='references_extracted',references=count,
                reference_pdf_start=eligible[idx][0],reference_labels=sorted({x['reference_number'] for r in refs.values() for x in r['citations'] if x['source']==row['id']}))
            source_rows.append(record);print(row['id'],'references',count,flush=True)
        except Exception as exc:
            record.update(status='source_parse_failed',error=str(exc),references=0)
            source_rows.append(record);print(row['id'],'FAILED',str(exc)[:120],flush=True)
    # Explicitly requested foundational originals, even if citation extraction fails.
    for author,title,year in [
      ('Bryan, G. H.','On the beats in the vibrations of a revolving cylinder or bell',1890),
      ('Lynch, D. D.','Vibratory gyro analysis by the method of averaging',1995),
      ('Lynch, D. D.','Coriolis Vibratory Gyros',1998)]:
        key='title:'+norm(title)
        ref=refs.setdefault(key,dict(key=key,title=title,doi=None,kind='J' if year==1890 else 'C',citations=[],status='unresolved'))
        ref.update(priority=True,author=author,year=year)
    rows=sorted(refs.values(),key=lambda x:(not x.get('priority'),-len(x['citations']),x['key']))
    for n,r in enumerate(rows,1):r['id']=f'R{n:04d}'
    save(REPORT/'sources.json',dict(date='2026-10-23',scope='First-level reference lists of 26 catalogued whole-angle/closely-related academic papers and theses; books/patents/manuals are not seed papers',sources=source_rows))
    save(REPORT/'references.json',rows)
    save(WORK/'existing_local.json',existing)
    print('UNIQUE',len(rows),'EDGES',sum(len(x['citations']) for x in rows),flush=True)


class Network:
    def __init__(self,proxy):
        self.proxy=proxy

    def get(self,url,limit=40_000_000,timeout=25):
        if not url.startswith(('https://','http://')):raise ValueError('HTTP(S) only')
        op=urllib.request.build_opener(urllib.request.ProxyHandler({'http':self.proxy,'https':self.proxy}) if self.proxy else urllib.request.ProxyHandler())
        req=urllib.request.Request(url,headers={'User-Agent':'HRG-WA-Literature-Research/1.0 (personal academic reference acquisition)','Accept':'application/pdf,application/json,text/html;q=0.9,*/*;q=0.5'})
        with op.open(req,timeout=timeout) as resp:
            data=resp.read(limit+1)
            if len(data)>limit:raise ValueError('Download size limit exceeded')
            return data,resp.geturl(),resp.headers.get('Content-Type','')

    def json(self,url):
        data,_,_=self.get(url,8_000_000)
        return json.loads(data)


def cached_json(net,url):
    p=WORK/'metadata_cache'/(digest(url.encode())+'.json')
    if p.exists():return json.loads(p.read_text(encoding='utf-8'))
    value=net.json(url);save(p,value);return value


def title_score(title,raw):
    n=norm(title);r=norm(raw)
    if len(n)<14:return 0.
    if n in r:return 1.
    return difflib.SequenceMatcher(None,n,r,autojunk=False).find_longest_match().size/len(n)


def compatibility_error(row,metadata):
    raw=' '.join(c['raw'] for c in row.get('citations',[]))
    kind=metadata.get('type','')
    if (row.get('kind')=='D' or re.search(r'\b(?:ph\.?d\.?|thesis|dissertation)\b',raw,re.I)) and kind not in ['dissertation','thesis']:
        return 'Cited thesis/dissertation versus a different publication type with the same title'
    years=[int(x) for x in re.findall(r'\b(?:18|19|20)\d{2}\b',raw)]
    year=metadata.get('year')
    if year and years and min(abs(int(year)-y) for y in years)>1:
        return 'Publication year differs by more than one year from every year in the citation'
    return None


def crossref_resolve(row,net):
    if row.get('doi'):
        try:
            message=cached_json(net,'https://api.crossref.org/works/'+urllib.parse.quote(clean_doi(row['doi']),safe=''))['message']
            return message,1.,'cited_doi'
        except Exception:
            pass # A broken/mistyped printed DOI is not a reason to skip title search.
    raw=row['citations'][0]['raw'] if row['citations'] else row['title']
    raw=re.sub(r'(?<=[a-z])(?=[A-Z])',' ',raw)
    query=urllib.parse.urlencode({'query.bibliographic':raw[:600],'rows':3})
    items=cached_json(net,'https://api.crossref.org/works?'+query)['message']['items']
    scored=[(title_score(' '.join(x.get('title',[])),raw),x) for x in items]
    scored.sort(key=lambda x:x[0],reverse=True)
    score,item=next(((s,x) for s,x in scored if not compatibility_error(row,dict(type=x.get('type'),year=x.get('issued',{}).get('date-parts',[[None]])[0][0]))),(0.,{}))
    if score<.82:raise ValueError(f'No confident bibliographic match (best title score {score:.3f})')
    return item,score,'bibliographic_title_match'


def enrich(args):
    rows=json.loads((REPORT/'references.json').read_text(encoding='utf-8'))
    net=Network(args.proxy)
    todo=[r for r in rows if not r.get('resolved') and r.get('kind') not in ['M','P']]
    if args.limit:todo=todo[:args.limit]
    def work(row):
        try:
            msg,score,method=crossref_resolve(row,net)
            row['resolved']=dict(doi=clean_doi(msg['DOI']),title=' '.join(msg.get('title',[])),
                 type=msg.get('type'),year=msg.get('issued',{}).get('date-parts',[[None]])[0][0],
                 match_method=method,title_match_score=score,
                 links=msg.get('link',[]),landing=msg.get('resource',{}).get('primary',{}).get('URL') or msg.get('URL'),
                 license=msg.get('license',[]))
            row['doi']=row['resolved']['doi'];row['status']='metadata_resolved'
        except Exception as e:row['resolution_error']=str(e)[:300]
        return row
    by_id={r['id']:r for r in rows}
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        for n,f in enumerate(as_completed([pool.submit(work,copy.deepcopy(r)) for r in todo]),1):
            r=f.result()
            with LOCK:
                by_id[r['id']].update(r)
                save(REPORT/'references.json',rows)
            if n%20==0 or r.get('priority'):print('RESOLVED',n,'/',len(todo),r['id'],r['status'],r.get('doi'),flush=True)
    print('RESOLVED TOTAL',sum(bool(r.get('resolved')) for r in rows),flush=True)


def candidates(row):
    urls=[]
    urls.extend(x['url'] for x in row.get('manual_urls',[]))
    ds=row.get('doi') or ''
    # Open publisher endpoint patterns, identified by DOI journal code.
    match=re.fullmatch(r'10\.3390/(s|mi|act|sym|math|ma|nano)(\d{1,2})\d{2}(\d{4,6})',ds)
    if match:
        prefix,vol,article=match.groups()
        journal={'s':'sensors','mi':'micromachines','act':'actuators','sym':'symmetry','math':'mathematics','ma':'materials','nano':'nanomaterials'}[prefix]
        stem=f'{journal}-{int(vol):02d}-{int(article):05d}'
        urls.append(f'https://mdpi-res.com/d_attachment/{journal}/{stem}/article_deploy/{stem}.pdf')
    if ds.startswith('10.1038/'):
        urls.append('https://www.nature.com/articles/'+ds.split('/',1)[1]+'.pdf')
    if ds.startswith('10.1186/'):
        urls.append('https://link.springer.com/content/pdf/'+ds+'.pdf')
    resolved=row.get('resolved',{})
    for link in resolved.get('links',[]):
        if link.get('content-type')=='application/pdf' or '.pdf' in link.get('URL','').lower():urls.append(link['URL'])
    for u in [resolved.get('landing'),('https://doi.org/'+ds) if ds else None]:
        if u:urls.append(u)
    return list(dict.fromkeys(urls))


def augment(args):
    """Use public publisher-deposited references of the same seed papers only."""
    rows=json.loads((REPORT/'references.json').read_text(encoding='utf-8'))
    source_doc=json.loads((REPORT/'sources.json').read_text(encoding='utf-8'))
    local=json.loads((WORK/'existing_local.json').read_text(encoding='utf-8'))
    corrections=REPORT/'manual_citation_corrections.json'
    if corrections.exists():
        for entry in json.loads(corrections.read_text(encoding='utf-8'))['entries']:
            title=guess_title(entry['raw']);key='title:'+norm(title)
            target=next((x for x in rows if x['key']==key or title_score(title,' '.join(c['raw'] for c in x['citations']))==1),None)
            if target is None:
                target=dict(id=f'R{len(rows)+1:04d}',key=key,title=title,doi=None,kind='unknown',citations=[],status='unresolved')
                rows.append(target)
            if not any(c['source']==entry['source'] and c['reference_number']==entry['reference_number'] for c in target['citations']):
                target['citations'].append(dict(entry,provenance='manual recovery of missing numeric marker in extracted PDF reference text'))
            sr=next(x for x in source_doc['sources'] if x['id']==entry['source'])
            sr['manually_recovered_labels']=sorted(set(sr.get('manually_recovered_labels',[])+[entry['reference_number']]))
    replacement=WORK/'L062_replacement.json'
    if replacement.exists():
        record=json.loads(replacement.read_text(encoding='utf-8'))
        p=PdfReader(record['path']);head=p.pages[0].extract_text() or ''
        local=[x for x in local if x['source_id']!='L062']
        local.append(dict(source_id='L062',path=record['path'],sha256=record['sha256'],
                          name='Recent Advances in MEMS-Based 3D Hemispherical Resonator Gyroscope',
                          title='Recent Advances in MEMS-Based 3D Hemispherical Resonator Gyroscope',head=head,dois=[record['doi']]))
    net=Network(args.proxy);bydoi={x['doi']:x for x in rows if x.get('doi')};additions=0
    parents=list(local);online_coverage=[]
    if args.include_online:
        catalog=json.loads(CATALOG.read_text(encoding='utf-8-sig'))
        held={d for seed in local for d in seed['dois']}
        for record_online in catalog['online']:
            rec=dict(id=record_online['id'],url=record_online.get('url'),title=record_online.get('title'),level=record_online.get('level'))
            key=record_online.get('key','')
            if key.startswith('doi:'):
                doi=clean_doi(key[4:]);rec['doi']=doi
                known_alias={'W035':'L061','W036':'L059'}.get(record_online['id'])
                if known_alias:
                    rec.update(status='already_covered_by_local_seed',local_source=known_alias,matching='Existing catalogue correspondence; Chinese publisher DOI absent from Crossref')
                    alias=next((x for x in source_doc['sources'] if x['id']=='O'+record_online['id']),None)
                    if alias:alias.update(status='duplicate_local_seed',duplicate_of=known_alias)
                elif doi.startswith('10.17632/'):
                    rec['status']='dataset_DOI_not_academic_seed_paper'
                    ds_source=next((x for x in source_doc['sources'] if x['id']=='O'+record_online['id']),None)
                    if ds_source:ds_source.update(status='dataset_not_paper',kind='dataset')
                elif doi in held:rec['status']='already_covered_by_local_seed'
                else:
                    ident='O'+record_online['id']
                    if not any(x['id']==ident for x in source_doc['sources']):
                        source_doc['sources'].append(dict(id=ident,kind='online_seed_metadata',doi=doi,
                            catalogue_title=record_online.get('title'),url=record_online.get('url'),
                            status='publisher_references_pending',original_reading_level=record_online.get('level'),
                            boundary='Publisher-deposited first-level references; no claim of seed full-text reading'))
                    parents.append(dict(source_id=ident,dois=[doi],head='',online=True))
                    rec['status']='publisher_reference_lookup_requested'
                    held.add(doi)
            else:rec['status']='non_DOI_record_patent_background_or_needs_identification_not_silently_assumed_paper'
            online_coverage.append(rec)
    for seed in parents:
        for ds in seed['dois'][:3]:
            try:
                msg=cached_json(net,'https://api.crossref.org/works/'+urllib.parse.quote(ds,safe=''))['message']
                if not seed.get('online') and title_score(' '.join(msg.get('title',[])),seed['head'][:12000])<.85:continue
                ref_list=msg.get('reference',[])
                sr=next(x for x in source_doc['sources'] if x['id']==seed['source_id'])
                sr['publisher_reference_count']=len(ref_list);sr['publisher_reference_doi']=ds
                if seed.get('online'):
                    sr.update(status='publisher_references_retrieved' if ref_list else 'publisher_metadata_has_no_reference_list',title=' '.join(msg.get('title',[])))
                    next(x for x in online_coverage if 'O'+x['id']==seed['source_id'])['status']=sr['status']
                if seed['source_id']=='L062':
                    sr.update(status='references_recovered_from_publisher_metadata',replacement_pdf=seed['path'],replacement_sha256=seed['sha256'],replacement_pages=record['pages'])
                for j,ref in enumerate(ref_list,1):
                    doi=clean_doi(ref['DOI']) if ref.get('DOI') else None
                    raw=ref.get('unstructured') or '. '.join(str(ref[k]) for k in ['author','year','article-title','journal-title','volume','first-page','DOI'] if ref.get(k))
                    if not raw:continue
                    if doi in bydoi:
                        target=bydoi[doi]
                        if any(x['source']==seed['source_id'] for x in target['citations']):continue
                    else:
                        title=ref.get('article-title') or guess_title(raw)
                        key='doi:'+doi if doi else 'title:'+norm(title)
                        target=next((x for x in rows if x['key']==key),None)
                        if target is None:
                            target=dict(id=f'R{len(rows)+1:04d}',key=key,title=title,doi=doi,kind='unknown',citations=[],status='unresolved')
                            rows.append(target);additions+=1
                            if doi:bydoi[doi]=target
                        if any(x['source']==seed['source_id'] and x['raw']==raw for x in target['citations']):continue
                    target['citations'].append(dict(source=seed['source_id'],reference_number='publisher:'+str(ref.get('key',j)),
                        pdf_page=None,raw=raw,provenance='Crossref reference deposit of the same seed paper',parent_doi=ds))
                print('PUBLISHER REFERENCES',seed['source_id'],len(ref_list),flush=True)
                break
            except Exception as e:
                print('PARENT LOOKUP',seed['source_id'],str(e)[:90],flush=True)
                if seed.get('online'):
                    sr=next(x for x in source_doc['sources'] if x['id']==seed['source_id'])
                    sr.update(status='publisher_reference_lookup_failed',error=str(e)[:250])
                    cr=next(x for x in online_coverage if 'O'+x['id']==seed['source_id'])
                    cr.update(status='publisher_reference_lookup_failed',error=str(e)[:250])
    save(REPORT/'references.json',rows);save(REPORT/'sources.json',source_doc)
    save(WORK/'existing_local.json',local)
    if args.include_online:save(REPORT/'online_seed_coverage.json',online_coverage)
    print('ADDED RECORDS',additions,'TOTAL',len(rows),flush=True)


def pdf_check(data,row):
    if not data.lstrip().startswith(b'%PDF'):raise ValueError('Not PDF bytes')
    r=PdfReader(io.BytesIO(data));pages=len(r.pages)
    if pages<2:raise ValueError('One-page file requires manual full-text review')
    first=r.pages[0].extract_text() or ''
    text='\n'.join(r.pages[i].extract_text() or '' for i in range(min(4,pages)))
    if pages<=6 and re.search(r'\bCONTENTS\b',text[:2500],re.I):raise ValueError('Contents-only PDF, not article full text')
    ds=row.get('doi');expected=row.get('resolved',{}).get('title') or row['title']
    score=title_score(expected,text)
    doi_match=bool(ds and ds in dois(first[:15000]))
    if not doi_match and score<.80:raise ValueError(f'PDF identity not verified (title score {score:.3f})')
    return dict(pages=pages,sha256=digest(data),bytes=len(data),identity='doi' if doi_match else 'title',title_score=score)


def download(args):
    rows=json.loads((REPORT/'references.json').read_text(encoding='utf-8'))
    manual_file=REPORT/'manual_download_links.json'
    manual=json.loads(manual_file.read_text(encoding='utf-8')) if manual_file.exists() else []
    for row in rows:
        cached=WORK/'acquisitions'/(row['id']+'.json')
        if cached.exists():row['acquisition']=json.loads(cached.read_text(encoding='utf-8'))
        links=[x for x in manual if x.get('doi')==row.get('doi') and x.get('doi') or x.get('id')==row['id']]
        if links:row['manual_urls']=links
    local=json.loads((WORK/'existing_local.json').read_text(encoding='utf-8'))
    net=Network(args.proxy);library=args.library
    bydoi={d:r for r in local for d in r['dois']}
    downloaded_by_doi={r.get('doi'):r['acquisition'] for r in rows if r.get('doi') and r.get('acquisition',{}).get('status')=='downloaded_verified'}
    todo=[];scheduled={}
    for row in rows:
        if args.only_ids and row['id'] not in args.only_ids.split(','):continue
        if row.get('acquisition',{}).get('status') in ['downloaded_verified','downloaded_verified_container','existing_local','duplicate_of_download']:continue
        if row.get('resolved') and compatibility_error(row,row['resolved']):
            row['acquisition']=dict(status='needs_bibliographic_version_review',reason=compatibility_error(row,row['resolved']));continue
        if row.get('kind') in ['M','P']:
            row['acquisition']=dict(status='nonpaper_reference_not_downloaded');continue
        match=bydoi.get(row.get('doi'))
        if not match:
            wanted=row.get('resolved',{}).get('title') or row['title']
            match=next((x for x in local if title_score(wanted,x['head'][:10000])>=.96),None)
        if match:
            row['acquisition']=dict(status='existing_local',path=match['path'],sha256=match['sha256'],source_id=match['source_id']);continue
        if row.get('doi') in downloaded_by_doi:
            row['acquisition']=dict(downloaded_by_doi[row['doi']],status='duplicate_of_download');continue
        if args.new_only and row.get('acquisition',{}).get('status')=='fulltext_unavailable_from_checked_sources':
            tried={x.get('url') for x in row['acquisition'].get('attempts',[])}
            if not any(u not in tried for u in candidates(row)):continue
        if row.get('doi') in scheduled:
            row['acquisition']=dict(status='duplicate_pending',canonical_record=scheduled[row['doi']]);continue
        if candidates(row):
            todo.append(row)
            if row.get('doi'):scheduled[row['doi']]=row['id']
        else:row['acquisition']=dict(status='needs_search_no_verified_identifier')
    if args.limit:todo=todo[:args.limit]
    if not args.isolated:save(REPORT/'references.json',rows)
    else:
        for row in rows:
            if row.get('acquisition'):save(WORK/'acquisitions'/(row['id']+'.json'),row['acquisition'])
    def work(row):
        attempts=[];queue=candidates(row);seen=set();tries=0
        if row.get('doi') and args.openalex:
            try:
                oa=cached_json(net,'https://api.openalex.org/works/https://doi.org/'+row['doi'])
                locations=oa.get('locations',[])
                preferred=[x.get('pdf_url') for x in locations if x.get('is_oa') and x.get('pdf_url')]
                queue[:0]=list(dict.fromkeys(preferred))[:5]
                row['openalex_id']=oa.get('id')
            except Exception as e:attempts.append(dict(source='OpenAlex',result='lookup_failed',error=str(e)[:180]))
        if row.get('manual_urls'):queue[:0]=[x['url'] for x in row['manual_urls']]
        while queue and tries<args.max_candidates:
            url=queue.pop(0)
            if url in seen:continue
            seen.add(url);tries+=1
            try:
                data,final,ctype=net.get(url)
                if data.lstrip().startswith(b'%PDF'):
                    info=pdf_check(data,row)
                    title=row.get('resolved',{}).get('title') or row['title']
                    name=re.sub(r'[^\w\u3400-\u9fff .-]','_',title)[:115].strip(' .')
                    path=library/'pdf'/f"{row['id']}_{name}.pdf"
                    path.parent.mkdir(parents=True,exist_ok=True)
                    if path.exists() and digest(path.read_bytes())!=info['sha256']:raise ValueError('Existing target differs; preserved without overwrite')
                    path.write_bytes(data)
                    row['acquisition']=dict(status='downloaded_verified',path=path.as_posix(),url=url,final_url=final,
                                            date='2026-10-23',**info,attempts=attempts)
                    return row
                text=data.decode('utf-8','replace')
                # Only explicit PDF links from the article landing page; no private APIs.
                links=[]
                for tag in re.findall(r'<meta\b[^>]+>',text,re.I):
                    if re.search(r'citation_pdf_url',tag,re.I):
                        m=re.search(r'content\s*=\s*[\"\']([^\"\']+)',tag,re.I)
                        if m:links.append(html.unescape(m.group(1)))
                for href in re.findall(r'href\s*=\s*[\"\']([^\"\']+)[\"\']',text,re.I):
                    if '.pdf' in href.lower() and not any(x in href.lower() for x in ['supp','citation','cover']):links.append(html.unescape(href))
                queue[:0]=[urllib.parse.urljoin(final,x) for x in links[:3] if urllib.parse.urljoin(final,x) not in seen]
                attempts.append(dict(url=url,final_url=final,result='HTML_or_nonPDF',pdf_links=len(links)))
            except Exception as e:attempts.append(dict(url=url,result='failed',error=str(e)[:220]))
        row['acquisition']=dict(status='fulltext_unavailable_from_checked_sources',attempts=attempts)
        return row
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        for n,f in enumerate(as_completed([pool.submit(work,r) for r in todo]),1):
            r=f.result()
            with LOCK:
                save(WORK/'acquisitions'/(r['id']+'.json'),r['acquisition'])
                if not args.isolated:save(REPORT/'references.json',rows)
            if r['acquisition']['status']=='downloaded_verified' or n%20==0:
                print('PDF',n,'/',len(todo),r['id'],r['acquisition']['status'],flush=True)
    print('ACQUISITION',dict(Counter(r.get('acquisition',{}).get('status','not_attempted') for r in rows)),flush=True)


def report(args):
    rows=json.loads((REPORT/'references.json').read_text(encoding='utf-8'))
    for row in rows:
        cached=WORK/'acquisitions'/(row['id']+'.json')
        if cached.exists():row['acquisition']=json.loads(cached.read_text(encoding='utf-8'))
    save(REPORT/'references.json',rows)
    sources=json.loads((REPORT/'sources.json').read_text(encoding='utf-8'))
    counts=Counter(r.get('acquisition',{}).get('status','not_attempted') for r in rows)
    summary=dict(date='2026-10-23',seed_sources=len(sources['sources']),
       sources_with_extracted_references=sum(x['status']=='references_extracted' for x in sources['sources']),
       unique_extraction_records=len(rows),citation_edges=sum(len(x['citations']) for x in rows),
       unique_resolved_dois=len({x['doi'] for x in rows if x.get('resolved')}),
       statuses=dict(counts),library=args.library.as_posix(),
       boundary='First-level citation extraction; bibliographic duplicates may remain when no DOI is resolved. Downloaded means PDF identity checked, not read/equivalence verified.')
    save(REPORT/'summary.json',summary)
    lines=['# 全角陀螺一级引用文献获取清单','',
      '原论文及参考资料保持原位。下载不表示全文已读或模型已核验；仅登记了一级引用，不递归抓取新下载论文的引用。', '',
      '数据统计：`summary.json`；源文献和解析状态：`sources.json`；完整引文、引用关系、DOI、来源及失败原因：`references.json`。', '',
      '本地全文目录：`'+args.library.as_posix()+'`。原始PDF不随工程源码上传；下载脚本、来源/哈希/检索状态纳入Git。', '',
      '|状态|记录数|','|---|---|']
    lines += [f'|{s}|{n}|' for s,n in sorted(counts.items())]
    lines += ['', '**计数边界：**记录数不等于独立论文篇数；没有DOI的题录可能保留同文异写。existing_local为已有文件，不能计为新下载；目录、HTML和未核身份PDF不能计为全文成功。', '',
              '|ID|题名|DOI|引用次数|获取状态/路径|','|---|---|---|---|---|']
    for row in rows:
        a=row.get('acquisition',{});title=row.get('resolved',{}).get('title') or row['title']
        vals=[row['id'],title,row.get('doi') or '',len(row['citations']),a.get('status','not_attempted')+' '+a.get('path','')]
        lines.append('| '+' | '.join(str(x).replace('|','/').replace('\n',' ') for x in vals)+' |')
    (REPORT/'README.md').write_text('\n'.join(lines)+'\n',encoding='utf-8',newline='\n')
    # Same bounded register beside the PDFs for local-library discovery.
    if args.install_register:
        args.library.mkdir(parents=True,exist_ok=True)
        for name in ['summary.json','references.json','sources.json','README.md']:
            data=(REPORT/name).read_bytes();target=args.library/name
            if target.exists() and target.read_bytes()==data:continue
            target.write_bytes(data)
    print(json.dumps(summary,ensure_ascii=False,indent=2))


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('command',choices=['extract','augment','enrich','download','report'])
    p.add_argument('--proxy',default='http://127.0.0.1:7897')
    p.add_argument('--library',type=Path,default=DEFAULT_LIBRARY)
    p.add_argument('--workers',type=int,default=4)
    p.add_argument('--limit',type=int,default=0)
    p.add_argument('--max-candidates',type=int,default=5)
    p.add_argument('--install-register',action='store_true')
    p.add_argument('--isolated',action='store_true',help='Write acquisition sidecars without changing an actively resolving master register')
    p.add_argument('--openalex',action='store_true',help='Query public OA locations in addition to publisher links')
    p.add_argument('--new-only',action='store_true',help='Skip failed records unless the metadata now exposes a new base URL')
    p.add_argument('--include-online',action='store_true',help='Also cover DOI-bearing academic seeds in the original 80-record online catalogue, without recursively adding new downloads as seeds')
    p.add_argument('--only-ids',default='',help='Comma-separated acquisition record IDs for focused source retries')
    a=p.parse_args()
    if a.workers<1 or a.workers>6:p.error('workers must be 1..6')
    {'extract':extract,'augment':augment,'enrich':enrich,'download':download,'report':report}[a.command](*([] if a.command=='extract' else [a]))
