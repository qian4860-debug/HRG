"""Recover a verified subset of papers citing Lynch 1995; never call it Scholar's full set.

Public publisher/repository downloads only. Existing PDFs remain in place; no
credentials, cookies, paywall bypass or recursive reference-list downloads.
"""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed
from collections import Counter
import argparse
import hashlib
import html
import io
import json
import re
import shutil
import subprocess
import sys
import urllib.parse
import acquire_wa_citations as shared
from pypdf import PdfReader

ROOT=Path(__file__).resolve().parents[1]
REPORT=ROOT/'research/lynch1995_citing_20261024'
WORK=ROOT/'HRG_WA_simulink/layered/_work/lynch1995_citing'
LIB=Path('D:/学习资料/资料/全角陀螺/Lynch1995_被引文献_20261024')
OLD=ROOT/'research/literature_acquisition_20261023'
SCHOLAR='https://scholar.google.com/scholar?cites=15957943393310504435&as_sdt=2005&sciodt=0,5&hl=zh-CN&scioq=%22Vibratory+gyro+analysis+by+the+method+of+averaging%22'
NEEDLE=shared.norm('Vibratory gyro analysis by the method of averaging')
WEB_DOIS=['10.3390/s111211761','10.3390/s20010295','10.3390/s140305254',
 '10.3390/s19071690','10.3390/s19132928','10.3390/s25185888',
 '10.1038/s41378-024-00787-1','10.33577/2312-4458.8.2013.81-88',
 '10.33577/2312-4458.18.2018.18-25','10.33577/2312-4458.10.2014.78-82',
 '10.3390/s20123549','10.3390/s90805952','10.3390/s130810123',
 '10.1109/jsen.2013.2269797','10.18372/1990-5548.34.5717']
REPOSITORIES=[
 ('Analysis and compensation of imperfection effects in piezoelectric vibratory gyroscopes',
  'https://vtechworks.lib.vt.edu/bitstreams/6361c75b-1915-423c-9db8-afea681201de/download'),
 ('Integrated inertial measurement units using',
  'https://repository.gatech.edu/bitstreams/45c6e787-2894-4171-8e0d-79c105c6b4fa/download'),
 ('High-performance micromachined vibratory rate and rate-integrating gyroscopes',
  'https://deepblue.lib.umich.edu/bitstream/2027.42/91440/2/jycho_2.pdf'),
]

def load(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def save(p,x):shared.save(p,x)
def cache_matches(acquisition,row):
    return acquisition.get('requested_doi')==row.get('doi') and acquisition.get('requested_title')==row['title']

def cache_acquisition(row):
    row['acquisition'].update(requested_doi=row.get('doi'),requested_title=row['title'])
    save(WORK/'acquisitions'/(row['id']+'.json'),row['acquisition'])
def match_citation(raw):
    n=shared.norm(raw)
    # Explicit target title plus author; missing year stays visible in evidence.
    return NEEDLE in n and 'lynch' in n

def checked_pdf(data,row):
    info=shared.pdf_check(data,row)
    first=PdfReader(io.BytesIO(data)).pages[0].extract_text() or ''
    # A matching title/DOI in another paper's reference list is not identity.
    front=re.split(r'\babstract\b|(?m:^\s*1\.?\s+introduction\b)',first,maxsplit=1,flags=re.I)[0]
    expected=row.get('resolved',{}).get('title') or row['title']
    score=shared.title_score(expected,front[:4000])
    if score<.8:raise ValueError(f'First-page title region does not identify requested work ({score:.3f})')
    return dict(info,first_page_title_score=score)

def citation_pages(path):
    reader=PdfReader(path);proof=[]
    for j in range(max(0,len(reader.pages)-24),len(reader.pages)):
        text=reader.pages[j].extract_text() or ''
        n=shared.norm(text)
        if NEEDLE not in n:continue
        pos=n.index(NEEDLE);near=n[max(0,pos-120):pos+len(NEEDLE)+350]
        if 'lynch' in near and '1995' in near:
            proof.append(dict(method='PDF reference-page text match',pdf_page=j+1,
                target_title='Vibratory gyro analysis by the method of averaging',author='Lynch',year=1995))
    return proof

def discover(net):
    REPORT.mkdir(parents=True,exist_ok=True);WORK.mkdir(parents=True,exist_ok=True)
    if (REPORT/'records.json').exists():
        print('Existing dated discovery snapshot preserved; use a new dated register for a refreshed enumeration.',flush=True)
        return
    shared.WORK=WORK
    rows=[];bykey={}
    def add(title,doi=None,source=None,proof=None,held=None,urls=None):
        doi=shared.clean_doi(doi) if doi else None
        key='doi:'+doi if doi else 'title:'+shared.norm(title)
        if key not in bykey:
            row=dict(id=f'LC{len(rows)+1:04d}',title=title,doi=doi,discovery=[],citation_evidence=[],held=[],manual_urls=[])
            bykey[key]=row;rows.append(row)
        row=bykey[key]
        if source and source not in row['discovery']:row['discovery'].append(source)
        if proof and proof not in row['citation_evidence']:row['citation_evidence'].append(proof)
        if held and held not in row['held']:row['held'].append(held)
        for u in urls or []:
            if not any(x['url']==u for x in row['manual_urls']):row['manual_urls'].append(dict(url=u))
        return row
    refs=load(OLD/'references.json');sources={x['id']:x for x in load(OLD/'sources.json')['sources']}
    for ref in refs:
        for edge in ref['citations']:
            if not match_citation(edge['raw']):continue
            source=sources[edge['source']]
            doi=edge.get('parent_doi') or source.get('publisher_reference_doi') or source.get('doi')
            title=source.get('title') or source.get('name') or source.get('catalogue_title') or source['id']
            held={k:source[k] for k in ('path','sha256') if k in source}
            add(title,doi,dict(method='existing explicit reverse citation',source_id=source['id']),
                dict(method=edge.get('provenance','previous PDF reference extraction'),
                     source_id=source['id'],reference_number=edge['reference_number'],
                     pdf_page=edge.get('pdf_page'),raw=edge['raw']),held or None)
    # Scan only the previously verified bounded corpus, not the entire personal library.
    scanned=[]
    for rec in load(OLD/'fulltext_manifest.json')['records']:
        p=Path(rec['path'])
        try:
            assert hashlib.sha256(p.read_bytes()).hexdigest()==rec['sha256']
            checked_pdf(p.read_bytes(),dict(title=rec['title'],doi=rec.get('doi')))
            proof=citation_pages(p)
            scanned.append(dict(record=rec['record'],sha256=rec['sha256'],matched=bool(proof)))
            for item in proof:add(rec['title'],rec.get('doi'),dict(method='verified local PDF reverse search',record=rec['record']),item,
                                  dict(path=p.as_posix(),sha256=rec['sha256']))
        except Exception as ex:scanned.append(dict(record=rec['record'],error=str(ex)[:240]))
    save(REPORT/'local_scan.json',scanned)
    # Full-text keyword discovery is a candidate source, never a confirmed citation edge.
    query=urllib.parse.urlencode({'search':'"Vibratory gyro analysis by the method of averaging"','per-page':100})
    search_url='https://api.openalex.org/works?'+query
    try:
        data=shared.cached_json(net,search_url)
        save(REPORT/'public_search.json',dict(url=search_url,count=data['meta']['count'],returned=len(data['results']),
             boundary='Keyword candidates; not the Scholar citing set, not verified citation edges'))
        for x in data['results']:
            urls=[loc['pdf_url'] for loc in x.get('locations',[]) if loc.get('is_oa') and loc.get('pdf_url')]
            add(x['display_name'],x.get('doi'),dict(method='OpenAlex full-text keyword candidate',work=x['id']),urls=urls)
    except Exception as ex:save(REPORT/'public_search.json',dict(url=search_url,error=str(ex)))
    for doi in WEB_DOIS:add(doi,doi,dict(method='public primary-site search candidate',url='https://doi.org/'+doi))
    for title,url in REPOSITORIES:add(title,source=dict(method='public university repository search candidate',url=url),urls=[url])
    for row in rows:
        if not row['doi']:continue
        try:
            msg=shared.cached_json(net,'https://api.crossref.org/works/'+urllib.parse.quote(row['doi'],safe=''))['message']
            row['resolved']=dict(title=' '.join(msg.get('title',[])),doi=row['doi'],type=msg.get('type'),
                year=msg.get('issued',{}).get('date-parts',[[None]])[0][0],links=msg.get('link',[]),
                landing=msg.get('resource',{}).get('primary',{}).get('URL') or msg.get('URL'))
            row['title']=row['resolved']['title']
        except Exception as ex:row['metadata_error']=str(ex)[:240]
    save(REPORT/'records.json',rows)
    save(REPORT/'scope.json',dict(date='2026-10-24',requested_scholar_url=SCHOLAR,
         scholar_status='Browser tab visible but DOM reads time out; exact Scholar enumeration unavailable',
         target=dict(author='D. D. Lynch',title='Vibratory gyro analysis by the method of averaging',year=1995,pages='26–34'),
         relation='citing paper -> Lynch 1995, not references cited by Lynch',
         complete_scholar_set=False,boundary='Verified recoverable subset plus explicitly marked candidates'))
    print('DISCOVERY',len(rows),dict(Counter(bool(x['citation_evidence']) for x in rows)),flush=True)

def acquire(net,workers,retry_ids):
    rows=load(REPORT/'records.json');manifest=load(OLD/'fulltext_manifest.json')['records']
    shared.WORK=WORK
    supplements=REPORT/'public_pdf_supplements.json'
    for item in load(supplements) if supplements.exists() else []:
        row=next(r for r in rows if r['id']==item['id'])
        for url in item['urls']:
            if not any(x['url']==url for x in row['manual_urls']):row['manual_urls'].append(dict(url=url))
        row['discovery'].append(dict(method='verified public primary-site PDF link',source=item['source']))
    heldbydoi={x['doi']:x for x in manifest if x.get('doi')}
    def work(row):
        receipt=WORK/'acquisitions'/(row['id']+'.json')
        if row.get('acquisition',{}).get('status','').startswith('excluded_'):return row
        if receipt.exists() and row['id'] not in retry_ids:
            prior=load(receipt)
            if cache_matches(prior,row):row['acquisition']=prior;return row
        prior=row.get('acquisition',{})
        if row['id'] not in retry_ids and prior.get('status') in ('existing_local_verified','downloaded_verified'):
            p=Path(prior['path'])
            if p.exists() and checked_pdf(p.read_bytes(),row)['sha256']==prior['sha256']:
                cache_acquisition(row);return row
        attempts=list(row.get('acquisition',{}).get('attempts',[]))
        candidates=list(row['held'])
        if row.get('doi') in heldbydoi:candidates.append(heldbydoi[row['doi']])
        for h in candidates:
            p=Path(h['path'])
            try:
                data=p.read_bytes();info=checked_pdf(data,row)
                assert info['sha256']==h['sha256']
                proof=citation_pages(p)
                row['citation_evidence'].extend(x for x in proof if x not in row['citation_evidence'])
                row['acquisition']=dict(status='existing_local_verified',path=p.as_posix(),**info)
                cache_acquisition(row);return row
            except Exception as ex:attempts.append(dict(path=p.as_posix(),result='local identity rejected',error=str(ex)[:200]))
        # Discard any PDF-only edge inherited from a failed identity match in an
        # older register. Independently extracted seed/publisher edges remain.
        if candidates:
            row['citation_evidence']=[x for x in row['citation_evidence'] if x['method']!='PDF reference-page text match']
        queue=shared.candidates(row)
        if row.get('doi'):
            try:
                oa=shared.cached_json(net,'https://api.openalex.org/works/https://doi.org/'+row['doi'])
                queue[:0]=list(dict.fromkeys(x['pdf_url'] for x in oa.get('locations',[]) if x.get('is_oa') and x.get('pdf_url')))[:4]
            except Exception as ex:attempts.append(dict(source='OpenAlex',error=str(ex)[:200]))
        seen=set();tries=0
        while queue and tries<6:
            url=queue.pop(0)
            if url in seen:continue
            seen.add(url);tries+=1
            try:
                data,final,ctype=net.get(url,limit=80_000_000,timeout=18)
                if data.lstrip().startswith(b'%PDF'):
                    info=checked_pdf(data,row)
                    duplicate=next((x for x in manifest if x['sha256']==info['sha256']),None)
                    if duplicate:
                        p=Path(duplicate['path']);proof=citation_pages(p)
                        row['citation_evidence'].extend(x for x in proof if x not in row['citation_evidence'])
                        row['acquisition']=dict(status='existing_local_verified',path=p.as_posix(),**info,attempts=attempts,
                            duplicate_detected_after_public_fetch=url)
                        cache_acquisition(row);return row
                    safe=re.sub(r'[^\w\u3400-\u9fff .-]','_',row['title'])[:110].strip(' .')
                    p=LIB/'pdf'/f"{row['id']}_{safe}.pdf";p.parent.mkdir(parents=True,exist_ok=True)
                    if p.exists() and hashlib.sha256(p.read_bytes()).hexdigest()!=info['sha256']:raise ValueError('Existing target differs, preserved')
                    p.write_bytes(data);proof=citation_pages(p)
                    row['citation_evidence'].extend(x for x in proof if x not in row['citation_evidence'])
                    row['acquisition']=dict(status='downloaded_verified',date='2026-10-24',path=p.as_posix(),url=url,final_url=final,**info,attempts=attempts)
                    cache_acquisition(row);return row
                text=data.decode('utf-8','replace');links=[]
                for tag in re.findall(r'<meta\b[^>]+>',text,re.I):
                    if re.search('citation_pdf_url',tag,re.I):
                        m=re.search(r'content\s*=\s*[\"\']([^\"\']+)',tag,re.I)
                        if m:links.append(html.unescape(m.group(1)))
                links.extend(html.unescape(x) for x in re.findall(r'href\s*=\s*[\"\']([^\"\']+)[\"\']',text,re.I)
                             if '.pdf' in x.lower() and not any(s in x.lower() for s in ('supp','cover','citation')))
                queue[:0]=[urllib.parse.urljoin(final,x) for x in links[:3]]
                attempts.append(dict(url=url,final_url=final,result='non-PDF',pdf_links=len(links)))
            except Exception as ex:attempts.append(dict(url=url,error=str(ex)[:240]))
        row['acquisition']=dict(status='fulltext_unavailable_from_checked_sources',attempts=attempts)
        cache_acquisition(row);return row
    todo=[r for r in rows if not retry_ids or r['id'] in retry_ids]
    with ThreadPoolExecutor(max_workers=workers) as pool:
        for i,future in enumerate(as_completed(pool.submit(work,r) for r in todo),1):
            r=future.result();save(REPORT/'records.json',rows)
            print(i,len(rows),r['id'],r['acquisition']['status'],bool(r['citation_evidence']),flush=True)

def report(install=False):
    rows=load(REPORT/'records.json');verified=[]
    corrections=REPORT/'manual_metadata_corrections.json'
    for item in load(corrections) if corrections.exists() else []:
        row=next(r for r in rows if r['id']==item['id'])
        assert row['acquisition']['sha256']==item['sha256']
        row['title']=item['title'];row['metadata_correction']=item
    for row in rows:
        a=row.get('acquisition',{});p=Path(a.get('path',''))
        if a.get('status')=='fulltext_unavailable_from_checked_sources' and row['held']:
            a['status']='local_present_needs_parse_or_identity_review'
            a['boundary']='Local bytes exist; current parser/title check did not qualify them. Not a missing-file claim.'
        if a.get('status') in ('existing_local_verified','downloaded_verified'):
            info=checked_pdf(p.read_bytes(),row);assert info['sha256']==a['sha256']
            if not row['citation_evidence']:
                proof=citation_pages(p)
                row['citation_evidence'].extend(x for x in proof if x not in row['citation_evidence'])
            if a['status']=='downloaded_verified' and not row['citation_evidence']:
                # Keep unconfirmed research bytes out of the user's citing-paper
                # collection. Only files created by this batch may be moved.
                assert p.resolve().parent==(LIB/'pdf').resolve()
                assert p.name.startswith(row['id']+'_')
                dest=WORK/'unconfirmed_pdf'/p.name;dest.parent.mkdir(parents=True,exist_ok=True)
                if dest.exists():
                    assert hashlib.sha256(dest.read_bytes()).hexdigest()==a['sha256']
                    p.unlink()
                else:shutil.move(str(p),str(dest))
                a.update(status='candidate_pdf_citation_unconfirmed',path=dest.as_posix(),
                    removed_from_citing_library=True,
                    boundary='Identity verified but target citation not found; retained only in ignored work files')
                if row.get('doi')=='10.3390/s20133677':
                    a['status']='excluded_incorrect_manual_seed_doi'
                    a['reason']='Manual seed DOI was wrong. Intended energy-compensation article is 10.3390/s20123549, already present in this register.'
                continue
            cache_acquisition(row)
            verified.append(dict(id=row['id'],title=row['title'],doi=row['doi'],citation_confirmed=bool(row['citation_evidence']),**a))
    for row in rows:
        if row.get('acquisition'):cache_acquisition(row)
    save(REPORT/'records.json',rows)
    counts=dict(Counter(x.get('acquisition',{}).get('status','not_attempted') for x in rows))
    summary=dict(date='2026-10-24',records=len(rows),statuses=counts,
        confirmed_citing_records=sum(bool(x['citation_evidence']) for x in rows),
        confirmed_citing_fulltexts=sum(x['citation_confirmed'] for x in verified),
        new_confirmed_citing_fulltexts=sum(x['citation_confirmed'] and x['status']=='downloaded_verified' for x in verified),
        existing_confirmed_citing_fulltexts=sum(x['citation_confirmed'] and x['status']=='existing_local_verified' for x in verified),
        unique_confirmed_fulltext_hashes=len({x['sha256'] for x in verified if x['citation_confirmed']}),
        new_unique_confirmed_fulltext_hashes=len({x['sha256'] for x in verified if x['citation_confirmed'] and x['status']=='downloaded_verified'}),
        existing_unique_confirmed_fulltext_hashes=len({x['sha256'] for x in verified if x['citation_confirmed'] and x['status']=='existing_local_verified'}),
        unique_fulltext_hashes=len({x['sha256'] for x in verified}),
        complete_scholar_set=False,library=LIB.as_posix(),boundary='PDF identity checked and citation evidence recorded; not scientific full-text reading')
    save(REPORT/'summary.json',summary);save(REPORT/'fulltext_manifest.json',dict(date='2026-10-24',records=verified))
    lines=['# Lynch 1995 被引文献：可核实子集','','用户指定入口：[Scholar 被引列表]('+SCHOLAR+')。浏览器正文读取持续超时，尚未取得完整题录，不能声称本清单覆盖该页全部结果。', '',
       '方向为“后续文章引用Lynch 1995”。此前一级参考文献表只用于恢复这条反向关系，不把Lynch引用的文献混入。公开检索命中仅为候选，必须另有参考文献证据才记为确认被引。', '',
       '本地全文目录：`'+LIB.as_posix()+'`。已有文件保留原路径；本目录README及JSON清单构成专题入口。原PDF不上传GitHub。', '',
       '统计：'+json.dumps(summary,ensure_ascii=False), '',
       '|ID|题名|DOI|引用关系|全文状态/路径|','|---|---|---|---|---|']
    for r in rows:
        a=r.get('acquisition',{});proof='已确认' if r['citation_evidence'] else '候选，未确认'
        lines.append('| '+' | '.join(str(v).replace('|','/').replace('\n',' ') for v in
           (r['id'],r['title'],r['doi'] or '',proof,a.get('status','not_attempted')+' '+a.get('path','')))+' |')
    lines+=['','## 完整性与后续导入','','`records.json`逐条保存来源、参考文献页码/编号、公开全文URL、SHA256和失败原因。下载成功只代表文件身份核验，不等于公式已逐项阅读。', '',
      '取得Scholar导出的题录后，按DOI优先、题名/作者/年份复核合并；须记录页码范围/导出日期/总条数，处理题名异写、作者稿与正式版及缺失DOI，再逐条补齐未取得全文。当前Scholar覆盖率不可计算。']
    (REPORT/'README.md').write_text('\n'.join(lines)+'\n',encoding='utf-8',newline='\n')
    regression=subprocess.run([sys.executable,'-m','unittest','discover','-s',str(ROOT/'tests'),'-p','test_lynch_citing.py'],
                              capture_output=True,text=True,check=True)
    save(REPORT/'verification.json',dict(pass_=True,verified_files=len(verified),unique_hashes=summary['unique_fulltext_hashes'],
         offline_regression=regression.stderr.strip(),python_version=sys.version.split()[0],
         script_sha256=hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n',b'\n')).hexdigest(),
         shared_identity_checker_sha256=hashlib.sha256(Path(shared.__file__).read_bytes().replace(b'\r\n',b'\n')).hexdigest(),
         original_reference_register_sha256=hashlib.sha256((OLD/'references.json').read_bytes()).hexdigest()))
    if install:
        LIB.mkdir(parents=True,exist_ok=True)
        for name in ('README.md','records.json','summary.json','fulltext_manifest.json','scope.json','verification.json'):
            (LIB/name).write_bytes((REPORT/name).read_bytes())
    print(json.dumps(summary,ensure_ascii=True),flush=True)

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('command',choices=['discover','download','report'])
    p.add_argument('--proxy',default='http://127.0.0.1:7897');p.add_argument('--workers',type=int,default=5)
    p.add_argument('--retry-ids',default='',help='Retry only these comma-separated IDs, retaining previous attempts')
    p.add_argument('--install',action='store_true');args=p.parse_args();net=shared.Network(args.proxy)
    if args.command=='discover':discover(net)
    elif args.command=='download':acquire(net,args.workers,set(filter(None,args.retry_ids.split(','))))
    else:report(args.install)
