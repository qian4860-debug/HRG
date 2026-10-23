"""Audit acquired bytes, separate versions, and publish a bounded local register."""
from __future__ import annotations

from collections import Counter
import csv
import hashlib
import json
from pathlib import Path
import re

from pypdf import PdfReader

import acquire_wa_citations as a


def public_url(url):
    # Anonymous publisher sessions are irrelevant provenance; do not publish IDs.
    return re.sub(r';jsessionid=[^?/#;]+','',url,flags=re.I)


def clean_urls(obj):
    if isinstance(obj,dict):return {k:clean_urls(v) for k,v in obj.items()}
    if isinstance(obj,list):return [clean_urls(x) for x in obj]
    if isinstance(obj,str) and obj.startswith(('http://','https://')):return public_url(obj)
    return obj


def extract_bryan():
    """Reproducible public-domain page excerpt; original container is read only.

    This function is intentionally not run by finalization. It records the recipe
    used to create the separately verified delivered excerpt.
    """
    from pypdf import PdfWriter
    container=json.loads((a.WORK/'bryan_container.json').read_text(encoding='utf-8'))
    source=Path(container['path'])
    if a.digest(source.read_bytes())!=container['sha256']:raise ValueError('Original volume changed')
    reader=PdfReader(source);writer=PdfWriter()
    for index in range(174,185):writer.add_page(reader.pages[index])
    writer.add_metadata({'/Title':'On the beats in the vibrations of a revolving cylinder or bell',
        '/Author':'G. H. Bryan',
        '/Subject':'Original printed pages 101-111, Proceedings Cambridge Philosophical Society Vol VII, communicated 24 November 1890; extracted without changing original page content'})
    target=a.DEFAULT_LIBRARY/'pdf/Bryan_1890_On_the_beats_original_pages_101-111.pdf'
    if target.exists():raise ValueError('Existing delivered excerpt preserved; no overwrite')
    with target.open('wb') as stream:writer.write(stream)
    result=PdfReader(target)
    for i,page in enumerate(result.pages):
        if page.get_contents().get_data()!=reader.pages[i+174].get_contents().get_data():raise ValueError('Page content changed')
    return target


def main():
    rows=json.loads((a.REPORT/'references.json').read_text(encoding='utf-8'))
    for row in rows:
        side=a.WORK/'acquisitions'/(row['id']+'.json')
        if side.exists():row['acquisition']=json.loads(side.read_text(encoding='utf-8'))
    byid={r['id']:r for r in rows}
    # Resolve same-DOI work queues without claiming each alias was newly downloaded.
    for row in rows:
        acq=row.get('acquisition',{})
        if acq.get('status')=='duplicate_pending':
            target=byid[acq['canonical_record']].get('acquisition',{})
            if target.get('status') in ['downloaded_verified','existing_local','duplicate_of_download']:
                row['acquisition']=dict(target,status='duplicate_of_download',canonical_record=acq['canonical_record'])
            else:row['acquisition']=dict(status='duplicate_of_unavailable_record',canonical_record=acq['canonical_record'])
    verified=[];issues=[];audit_cache={}
    for row in rows:
        acq=row.get('acquisition',{})
        conflict=a.compatibility_error(row,row.get('resolved',{})) if row.get('resolved') else None
        if conflict:
            row['bibliographic_review']=conflict
            if acq.get('status') in ['downloaded_verified','duplicate_of_download','existing_local']:
                row['acquisition']=dict(acq,status='related_version_not_cited_work',bibliographic_review=conflict)
                acq=row['acquisition']
        if acq.get('status') not in ['downloaded_verified','existing_local','duplicate_of_download']:continue
        p=Path(acq['path'])
        try:
            if p not in audit_cache:
                data=p.read_bytes()
                if a.digest(data)!=acq['sha256']:raise ValueError('Saved-byte hash differs from acquisition receipt')
                if not data.startswith(b'%PDF') or b'%%EOF' not in data[-4096:]:raise ValueError('PDF header/EOF completeness failed')
                try:pages=len(PdfReader(p).pages)
                except Exception:
                    import pdfplumber
                    with pdfplumber.open(p) as pdf:pages=len(pdf.pages)
                audit_cache[p]=dict(path=p.as_posix(),sha256=a.digest(data),bytes=len(data),pages=pages)
            info=audit_cache[p]
            if not acq.get('derived_excerpt'):
                # Availability matching must also identify the work, not merely its bytes.
                a.pdf_check(p.read_bytes(),row)
            verified.append(dict(record=row['id'],doi=row.get('doi'),title=row.get('resolved',{}).get('title') or row['title'],
                status=acq['status'],**info))
        except Exception as e:
            issues.append(dict(record=row['id'],path=p.as_posix(),error=str(e)))
            row['acquisition']=dict(acq,status='saved_file_audit_failed',audit_error=str(e))
    rows=clean_urls(rows)
    a.save(a.REPORT/'references.json',rows)
    a.save(a.REPORT/'fulltext_manifest.json',dict(date='2026-10-23',scope='Byte identity, PDF completeness and parse checks; not full-paper scientific review',
        unique_verified_files=len({x['sha256'] for x in verified}),records=verified,issues=issues))
    groups={}
    special={r['id']:a.norm(r['title']) for r in rows if r.get('priority')}
    for row in rows:
        raw=' '.join(c['raw'] for c in row['citations'])
        special_match=next((ident for ident,title in special.items() if title in a.norm(raw)),None)
        if row.get('priority'):special_match=row['id']
        key='priority:'+special_match if special_match else 'doi:'+row['doi'] if row.get('resolved') else row['key']
        group=groups.setdefault(key,dict(key=key,variants=[],citations=[]))
        group['variants'].append(row)
        for c in row['citations']:
            if c not in group['citations']:group['citations'].append(c)
    canonical=[]
    rank={'downloaded_verified':0,'existing_local':1,'duplicate_of_download':2,'related_version_not_cited_work':8}
    for n,g in enumerate(groups.values(),1):
        chosen=min(g['variants'],key=lambda r:(not r.get('priority'),rank.get(r.get('acquisition',{}).get('status'),5),not bool(r.get('resolved'))))
        acq=chosen.get('acquisition',{})
        canonical.append(dict(id=f'W{n:04d}',variant_ids=[x['id'] for x in g['variants']],
            title=chosen.get('resolved',{}).get('title') or chosen['title'],
            doi=chosen.get('doi'),doi_metadata_verified=bool(chosen.get('resolved')),
            acquisition=acq,citations=g['citations'],sources=sorted({c['source'] for c in g['citations']}),
            grouping='Verified DOI or normalized extracted title; unresolved title variants may remain'))
    a.save(a.REPORT/'canonical_works.json',canonical)
    sources=json.loads((a.REPORT/'sources.json').read_text(encoding='utf-8'))
    counts=Counter(x['acquisition'].get('status','not_attempted') for x in canonical)
    unique_new={x['sha256'] for x in verified if x['status']=='downloaded_verified'}
    local_count=sum(not r['id'].startswith('OW') for r in sources['sources'])
    online_count=sum(r['id'].startswith('OW') and r.get('status') not in ['duplicate_local_seed','dataset_not_paper'] for r in sources['sources'])
    summary=dict(date='2026-10-23',scope='First-level references of the pre-existing local academic seeds plus DOI-bearing academic seeds from the original 80-record online catalogue; no recursive harvesting',
        completed='2026-10-24',seeds=local_count+online_count,local_seed_count=local_count,additional_online_seed_count=online_count,original_online_catalogue_records=80,
        seed_details='sources.json',raw_variant_records=len(rows),
        canonical_groups=len(canonical),grouping_boundary='DOI groups deduplicated; no-DOI spelling variants may remain',
        unique_resolved_dois=len({x['doi'] for x in rows if x.get('resolved')}),
        unique_new_verified_article_files=len(unique_new),unique_verified_files_including_existing=len({x['sha256'] for x in verified}),
        recovered_seed_pdfs=1,original_container_volumes=1,
        status_counts=dict(counts),file_audit_issues=issues,library=a.DEFAULT_LIBRARY.as_posix(),
        scholar='Home page read after user reopened; query submission/reattachment failed; search results not harvested',
        wos='User-open result query visible in tab inventory; page body/export could not be read; not claimed as searched/exported',
        fulltext_boundary='Downloaded/available does not mean scientific reading, equation validation, license to redistribute, or coverage of every online catalogue abstract')
    a.save(a.REPORT/'summary.json',summary)
    lines=['# 全角陀螺一级引用文献获取记录','',
        f'获取批次始于2026-10-23，登记完成于2026-10-24。范围为既有目录中{local_count}篇本地全角/紧密相关论文及学位论文，以及原80条网上记录中新增{online_count}项学术种子的一级引用；不递归扩展新下载论文的引用。网上题录原始级别不因取得引用元数据而升级为全文已读。', '',
        f"归并后 {len(canonical)} 组题录，{summary['unique_resolved_dois']} 个已核对 DOI。没有 DOI 的异写题录仍可能重复，不能将该组数称为完全去重的独立论文数。", '',
        f"新增且通过字节/PDF检查的文章文件 {len(unique_new)} 份；另有修复种子综述1份、Bryan原始期刊卷1份。Bryan摘页包含在新增文章文件中，未重复计数。", '',
        '本地目录：`'+a.DEFAULT_LIBRARY.as_posix()+'`。原始PDF、未完成下载和缓存不上传GitHub；代码、引用关系、获取状态和哈希纳入工程Git。下载并不等于全文已读或公式已核验。', '',
        '## Bryan 与 Lynch', '',
        '- Bryan 1890：已从原卷获得全文，印刷页101–111；原卷PDF175–185页。另存11页摘页，各页内容流与原卷相同，整卷字节数和MD5与档案馆记录相符。末页同时开始下一篇文章，保留整页并注明边界。',
        '- Lynch 1995平均法论文：尚未取得可验证全文，不能用引用它的论文或题录代替。',
        '- Lynch 1998 Coriolis Vibratory Gyros：找到会议目录及IEEE1431附录B重印的出处线索，尚未取得可验证全文。IEEE官方页面列为购买/订阅访问。', '',
        '## 聚合来源及限制', '',
        '公开检索、Crossref出版方引用登记、OpenAlex公开版本位置、出版方直链、作者实验室及大学仓储、互联网档案馆。Scholar曾读到首页，但查询/后续连接失败；WoS仅看到用户打开的检索标签，未取得结果正文或导出，未计入已完成搜索。', '',
        'HTML、目录PDF、身份不匹配、类型冲突和缺尾PDF不计为目标全文成功。公开服务器403不自动等同于付费墙，具体失败原因保留在记录中。', '',
        '|状态|归并题录组数|','|---|---|']
    lines += [f'|{k}|{v}|' for k,v in sorted(counts.items())]
    lines += ['', '## 可复查文件', '',
        '- `sources.json`：种子文件、哈希、解析范围、缺号人工恢复、出版方参考文献数。',
        '- `online_seed_coverage.json`：原有80条网上记录的逐项覆盖、重复、非论文与失败状态。',
        '- `references.json`：全部提取异写、引用关系、元数据和获取尝试。',
        '- `canonical_works.json`：按DOI/明确题名归并的工作索引。',
        '- `fulltext_manifest.json`：实际文件字节哈希、PDF页数和最终检查。',
        '- `manual_citation_corrections.json`、`manual_download_links.json`：人工补充的依据。',
        '- `bryan_original_receipt.json`：公版原卷与摘页的对应关系。', '',
        '- `rejected_local_matches.json`：最终审计拒绝的4条本地误匹配及原因；这些文件未被当作目标论文成功计数。', '',
        '## 复核入口', '',
        '`python -m unittest discover -s tools -p test_wa_acquisition.py`检查身份识别边界；`python tools/finalize_wa_acquisition.py`重新核对已保存文件及清单；`python tools/install_wa_acquisition_index.py`更新本机参考技能索引。', '',
        '原始引文提取入口`tools/acquire_wa_citations.py extract`会重建原始记录，不应对已补充人工证据的最终清单无备份直接重跑。网络获取命令的输出必须再次执行文件审计后才计为最终结果。依赖版本见`tools/requirements-wa-acquisition.txt`。', '',
        '## 逐项清单', '', '|ID|题名|DOI/待核标识|状态|本地文件|','|---|---|---|---|---|']
    for row in canonical:
        vals=[row['id'],row['title'],row.get('doi') or '',row['acquisition'].get('status','not_attempted'),row['acquisition'].get('path','')]
        lines.append('| '+' | '.join(str(x).replace('|','/').replace('\n',' ') for x in vals)+' |')
    (a.REPORT/'README.md').write_text('\n'.join(lines)+'\n',encoding='utf-8',newline='\n')
    with (a.REPORT/'works.csv').open('w',encoding='utf-8-sig',newline='') as f:
        w=csv.writer(f);w.writerow(['id','title','doi','metadata_verified','status','local_path','sha256','seed_sources'])
        for row in canonical:
            w.writerow([row['id'],row['title'],row.get('doi') or '',row['doi_metadata_verified'],row['acquisition'].get('status','not_attempted'),row['acquisition'].get('path',''),row['acquisition'].get('sha256',''),';'.join(row['sources'])])
    for name in ['README.md','summary.json','canonical_works.json','fulltext_manifest.json','works.csv','sources.json','references.json','bryan_original_receipt.json','online_seed_coverage.json','rejected_local_matches.json']:
        (a.DEFAULT_LIBRARY/name).write_bytes((a.REPORT/name).read_bytes())
    a.save(a.REPORT/'verification.json',dict(summary=summary,offline_tests=12,
        verified_files=len(audit_cache),page_excerpt_streams_unchanged=True,
        provenance='References and acquisition register only; no inference that missing papers were obtained'))
    print(json.dumps(summary,ensure_ascii=False,indent=2))
    if issues:raise SystemExit(1)


if __name__=='__main__':main()
