"""Acquire the selected piezo-HRG reading list from public sources.

Keep original PDFs outside Git. No credentials, cookies, access-control bypass,
or replacement of existing source files. Acquisition is not scientific review.
"""
from __future__ import annotations

import argparse
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
import unicodedata
import urllib.parse
import urllib.request

logging.getLogger('pypdf').setLevel(logging.ERROR)
ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / 'research/piezo_search_20261029'
LIBRARY = Path('D:/学习资料/资料/全角陀螺/压电专题_20261029')
SOURCE_LIBRARY = LIBRARY.parent
MAX_BYTES = 60 * 1024 * 1024
SEEDS = {
 'P01': ['https://transducer-research-foundation.org/technical_digests/HiltonHead_2014/hh2014_0391.pdf'],
 'P03': ['https://scholars.lib.ntu.edu.tw/bitstreams/eabdb572-42fc-43a8-a4c3-0dce9884849c/download'],
 'P05': ['https://bpb-us-e2.wpmucdn.com/faculty.sites.uci.edu/dist/e/700/files/2023/04/Piezo_actuation_IEEE_Inertial_2023_final_corrected_V2.pdf'],
 'P06': ['https://bpb-us-e2.wpmucdn.com/faculty.sites.uci.edu/dist/e/700/files/2025/05/PLANS_2025_Non_metallized_HRG_V4.pdf'],
 'P13': ['https://engineering.purdue.edu/oxidemems/papers/TUFFC2012_Shaping.pdf'],
 'P21': ['https://journals.sagepub.com/doi/pdf/10.1177/1045389X9000100305'],
}
DOIS = {
 'P14': '10.1115/1.2892008', 'P19': '10.1006/mssp.2001.1458',
 'P23': '10.1177/1045389X9000100102', 'P27': '10.1109/TAC.1978.1101785',
 'P29': '10.1103/PhysRev.53.90', 'P30': '10.1243/PIME_PROC_1986_200_128_02',
}
PATENTS = {'P09':'CN104197917A','P10':'CN105547272A','P11':'CN106017450B'}


def norm(value):
    return re.sub(r'[^a-z0-9\u3400-\u9fff]', '', unicodedata.normalize('NFKC', html.unescape(value)).lower())


def save(path, obj):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, ensure_ascii=False, indent=2)+'\n', encoding='utf-8', newline='\n')


def fetch(url, proxy):
    if urllib.parse.urlsplit(url).scheme not in {'https', 'http'}:
        raise ValueError('Only public HTTP(S) resources are accepted')
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({'http':proxy,'https':proxy}) if proxy else urllib.request.ProxyHandler())
    req = urllib.request.Request(url, headers={'User-Agent':'HRG-reference-acquisition/1.0', 'Accept':'application/pdf,application/json,text/html;q=0.8'})
    with opener.open(req, timeout=25) as resp:
        data = resp.read(MAX_BYTES+1)
        if len(data)>MAX_BYTES: raise ValueError('Resource exceeds download size limit')
        return data, resp.geturl(), resp.headers.get('Content-Type','')


def inspect_pdf(data):
    if not data.lstrip().startswith(b'%PDF-'): raise ValueError('Not PDF bytes (possibly access or error page)')
    if b'%%EOF' not in data[-8192:]: raise ValueError('Missing final PDF EOF')
    from pypdf import PdfReader
    try:
        r = PdfReader(io.BytesIO(data)); pages=len(r.pages)
        head='\n'.join(r.pages[i].extract_text() or '' for i in range(min(2,pages)))
        tail=r.pages[-1].extract_text() or ''
        parser='pypdf'
    except Exception:
        import pdfplumber
        with pdfplumber.open(io.BytesIO(data)) as r:
            pages=len(r.pages)
            head='\n'.join(r.pages[i].extract_text() or '' for i in range(min(2,pages)))
            tail=r.pages[-1].extract_text() or ''
        parser='pdfplumber'
    if pages<2: raise ValueError('Single-page resource requires manual full-text review')
    return dict(pages=pages, parser=parser, head=head, tail_characters=len(tail), sha256=hashlib.sha256(data).hexdigest(), bytes=len(data))


def title_matches(title, head):
    title=re.sub(r'^(?:a|an|the)\s+','',title,flags=re.I)
    t=norm(title);h=norm(head[:2000])
    if t in h: return True
    # Long titles may include hyphenation or line extraction damage.
    words=re.findall(r'[A-Za-z]{4,}',title.lower())
    if len(words)>=5:
        hits=sum(norm(w) in h for w in words)
        return hits/len(words)>=.93 and len(t)>30 and t[:20] in h
    return False


def local_identity(title, patent, path, info, head, known):
    """A title mentioned in another document is not evidence of possession."""
    if any(norm(title)==norm(k) for k in known):
        return 'previous_verified_manifest_title_and_sha256'
    if patent and path.stem==patent:
        return 'existing_patent_filename_and_pdf_structure'
    named=len(norm(title))>=16 and norm(title)[:60] in norm(path.stem)
    if named and title_matches(title,head):
        return 'filename_and_opening_title'
    return None


def records():
    rows=json.loads((REPORT/'citation_edges.json').read_text(encoding='utf-8'))['records']
    out=[]
    for row in rows:
        text=row['entry_markdown']; title=re.search(r'\*\*(.*?)\*\*',text).group(1)
        if row['id']=='P03': title=title.split(' / ')[0]
        ds=re.findall(r'10\.\d{4,9}/[A-Za-z0-9./_()-]+',text)
        doi=DOIS.get(row['id']) or (ds[0].rstrip('.') if ds else None)
        if row['id']=='P22':doi=None  # Historical metadata conflict, resolve independently.
        out.append(dict(id=row['id'],title=title,doi=doi,entry_markdown=text,
                        status='not_obtained',attempts=[],reading_status='not_scientifically_reviewed'))
    return out


def existing_inventory():
    registered={}
    for manifest in SOURCE_LIBRARY.rglob('*manifest*.json'):
        if LIBRARY in manifest.parents: continue
        try:
            data=json.loads(manifest.read_text(encoding='utf-8-sig'))
            for r in data.get('records',[]):
                if r.get('path') and r.get('title') and r.get('sha256'):
                    registered.setdefault(Path(r['path']).as_posix(),[]).append(r)
        except (ValueError,OSError,AttributeError): pass
    result=[]
    for p in SOURCE_LIBRARY.rglob('*.pdf'):
        if LIBRARY in p.parents: continue
        try:
            info=inspect_pdf(p.read_bytes());head=info.pop('head')
            known=[r['title'] for r in registered.get(p.as_posix(),[]) if r['sha256']==info['sha256']]
            result.append((p,info,head,known))
        except Exception: pass
    return result


def acquire(row, inventory, proxy, extra):
    sid=row['id']; title=row['title']; patent=PATENTS.get(sid)
    for p,info,head,known in inventory:
        identity=local_identity(title,patent,p,info,head,known)
        if identity:
            row.update(status='existing_fulltext',path=p.as_posix(),**info,
                       identity_basis=identity)
            return row
    candidates=list(SEEDS.get(sid,[]))+extra.get(sid,[])
    # Public patent page links are explicit publisher-provided download targets.
    if patent:
        u=f'https://patents.google.com/patent/{patent}/zh'
        try:
            data,_,_=fetch(u,proxy)
            m=re.search(r'<meta\s+name="citation_pdf_url"\s+content="([^"]+)"',data.decode('utf-8','replace'))
            if m:candidates.append(html.unescape(m[1]))
        except Exception as exc:row['attempts'].append(dict(url=u,error=str(exc)))
    doi=row.get('doi')
    if not doi and sid in {'P16','P17','P22'}:
        query='https://api.crossref.org/works?'+urllib.parse.urlencode({'query.title':title,'rows':3})
        try:
            data,_,_=fetch(query,proxy)
            matches=json.loads(data)['message']['items']
            row['crossref_title_candidates']=[dict(title=x.get('title'),doi=x.get('DOI')) for x in matches]
            for x in matches:
                candidate=' '.join(x.get('title',[]))
                if difflib.SequenceMatcher(None,norm(candidate),norm(title)).ratio()>=.90:
                    doi=x['DOI'];row['doi']=doi;row['doi_basis']='Crossref title match';break
        except Exception as exc:row['attempts'].append(dict(url=query,error=str(exc)))
    if doi:
        oa='https://api.openalex.org/works/https://doi.org/'+urllib.parse.quote(doi,safe='')
        try:
            data,_,_=fetch(oa,proxy); meta=json.loads(data)
            row['openalex_title']=meta.get('title')
            if difflib.SequenceMatcher(None,norm(meta.get('title','')),norm(title)).ratio()>=.83:
                for loc in meta.get('locations',[]):
                    if loc.get('is_oa') and loc.get('pdf_url'):candidates.append(loc['pdf_url'])
            else:row['attempts'].append(dict(url=oa,error='Metadata title mismatch; candidates rejected'))
        except Exception as exc:row['attempts'].append(dict(url=oa,error=str(exc)))
        cross='https://api.crossref.org/works/'+urllib.parse.quote(doi,safe='')
        try:
            data,_,_=fetch(cross,proxy);meta=json.loads(data)['message']
            row['crossref_metadata']={k:meta.get(k) for k in ['DOI','title','author','published','container-title','volume','issue','page','link']}
            for link in meta.get('link',[]):
                if link.get('content-type')=='application/pdf' and link.get('URL'):candidates.append(link['URL'])
        except Exception as exc:row['attempts'].append(dict(url=cross,error=str(exc)))
    for url in dict.fromkeys(candidates):
        try:
            data,final,ctype=fetch(url,proxy)
            # A normal public landing page may identify its PDF via citation metadata.
            if not data.lstrip().startswith(b'%PDF-') and 'html' in ctype:
                page=data.decode('utf-8','replace')
                m=re.search(r'<meta[^>]+name=["\']citation_pdf_url["\'][^>]+content=["\']([^"\']+)',page,re.I)
                if m:
                    final=urllib.parse.urljoin(final,html.unescape(m[1]));data,final,ctype=fetch(final,proxy)
            info=inspect_pdf(data);head=info.pop('head')
            matched=title_matches(title,head)
            if not matched and not (patent and patent in final):
                raise ValueError('PDF identity not confirmed in opening pages')
            slug=re.sub(r'[<>:"/\\|?*\x00-\x1f]','_',title)[:135].strip(' .')
            dest=LIBRARY/'pdf'/f'{sid}_{slug}.pdf'
            dest.parent.mkdir(parents=True,exist_ok=True)
            if dest.exists() and hashlib.sha256(dest.read_bytes()).hexdigest()!=info['sha256']:
                raise ValueError('Existing destination differs; refusing overwrite')
            if not dest.exists():dest.write_bytes(data)
            row.update(status='downloaded_fulltext',path=dest.as_posix(),source_url=url,final_url=final,
                       identity_basis='title_in_first_two_pages' if matched else 'official_patent_pdf_link',**info)
            return row
        except Exception as exc:row['attempts'].append(dict(url=url,error=str(exc)))
    row['next_action']='Find authorized full text through institution, author repository, or publisher; no access barrier bypass attempted'
    return row


def write_reports(outpath):
    manifest=json.loads(outpath.read_text(encoding='utf-8'))
    manifest['counts']=dict(Counter(r['status'] for r in manifest['records']))
    save(outpath,manifest)
    save(LIBRARY/'download_manifest.json',manifest)
    lines=['# 压电半球陀螺文献获取结果','', '日期：2026-10-29。全文获取与结构/题名核验不表示科学内容已通读或公式已验证。', '',
           '统计：'+ '；'.join(f'{k}={v}' for k,v in manifest['counts'].items())+'。', '',
           '| ID | 题名 | 状态 | 本地路径/下一步 |','| --- | --- | --- | --- |']
    labels={'downloaded_fulltext':'本次下载全文','existing_fulltext':'复用已有全文','not_obtained':'尚未取得全文'}
    for r in manifest['records']:
        if r.get('path'):
            detail=f"[{Path(r['path']).name}]({r['path']})"
        else:
            errors=' '.join(x.get('error','') for x in r['attempts'])
            reason='未找到公开全文附件'
            if '403' in errors:reason='HTTP403：机构访问或站点访问限制'
            elif '401' in errors:reason='HTTP401：需访问授权'
            elif '500' in errors:reason='下载服务器HTTP500错误'
            elif 'SSL' in errors:reason='公开链接连接失败，需另找可用来源'
            if r.get('doi'):reason+=f"；[DOI入口](https://doi.org/{r['doi']})"
            detail=reason+'；详细尝试见download_manifest.json'
        lines.append(f"| {r['id']} | {r['title']} | {labels[r['status']]} | {detail} |")
    (REPORT/'下载结果.md').write_text('\n'.join(lines)+'\n',encoding='utf-8',newline='\n')
    (LIBRARY/'README.md').write_text('\n'.join(lines)+'\n',encoding='utf-8',newline='\n')
    print(json.dumps(manifest['counts'],ensure_ascii=False),flush=True)


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--proxy');ap.add_argument('--ids',nargs='*');ap.add_argument('--rescan',action='store_true');ap.add_argument('--report-only',action='store_true')
    args=ap.parse_args();outpath=REPORT/'download_manifest.json'
    if args.report_only:
        write_reports(outpath);return
    previous=json.loads(outpath.read_text(encoding='utf-8'))['records'] if outpath.exists() else []
    old={r['id']:r for r in previous};rows=records()
    if not args.rescan:
        rows=[old.get(r['id'],r) for r in rows]
    extra_path=REPORT/'download_sources.json';extra=json.loads(extra_path.read_text(encoding='utf-8')) if extra_path.exists() else {}
    inv=existing_inventory();print('Existing valid PDFs scanned:',len(inv),flush=True)
    selected=[r for r in rows if (not args.ids or r['id'] in args.ids) and r['status'] not in {'existing_fulltext','downloaded_fulltext'}]
    with ThreadPoolExecutor(max_workers=4) as pool:
        fs={pool.submit(acquire,r,inv,args.proxy,extra):r for r in selected}
        for f in as_completed(fs):
            r=f.result();old[r['id']]=r;print(r['id'],r['status'],r.get('pages',''),flush=True)
            current=[old.get(x['id'],x) for x in rows]
            save(outpath,dict(date='2026-10-29',scope='Acquisition and opening-page identity/PDF validation only; not full scientific review',library=LIBRARY.as_posix(),counts=dict(Counter(x['status'] for x in current)),records=current))
    write_reports(outpath)


if __name__=='__main__':main()
