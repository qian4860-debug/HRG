"""Project only HRG bibliographic coverage; private complete inventory stays local."""
from pathlib import Path
import argparse
import json

ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'HRG_WA_simulink/layered/_work/zotero_bridge'
PUBLIC=ROOT/'research/zotero_integration_20261024'
SKILL=Path('C:/Users/11725/.codex/skills/ic-reference-library')

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--install-links',action='store_true');args=parser.parse_args()
    live=json.loads((WORK/'live_inventory.json').read_text(encoding='utf-8'))
    source=json.loads((PUBLIC/'hrg_pdf_sources.json').read_text(encoding='utf-8'))
    root=next(c['key'] for c in live['collections'] if c['data']['name']=='全角陀螺' and not c['data'].get('parentCollection'))
    parents={i['key']:i for i in live['items'] if root in i['data'].get('collections',[]) and i['data']['itemType']!='attachment'}
    held={f['parent']:f['key'] for f in live['files'] if f.get('parent')}
    # First 17 original Zotero PDFs: exact bytes and available attachment links,
    # not automatic reading or a claim that other D: sources are unavailable.
    original={r['attachment_key'] for r in source['records']}
    rows=[]
    for key,item in parents.items():
        d=item['data'];attachment=held.get(key)
        rows.append(dict(key=key,title=d.get('title',''),doi=d.get('DOI',''),date=d.get('date',''),
            item_type=d['itemType'],original_pdf=attachment if attachment in original else None,
            reading_evidence='See source reading ledger' if attachment in original else 'Bibliography only in this projection; local D: match not inferred'))
    rows.sort(key=lambda r:(r['date'],r['title']))
    value=dict(date='2026-10-24',hrg_bibliographic_records=len(rows),
        with_original_zotero_pdf=sum(bool(r['original_pdf']) for r in rows),
        boundary='HRG collection projection only; neither a complete Scholar roster nor scientific reading of every record',records=rows)
    (PUBLIC/'hrg_bibliographic_coverage.json').write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    lines=['# Zotero全角陀螺书目覆盖表','','只列全角陀螺集合的书目条目，不列私人库其余领域。附件导入、题录关联和科学审读分开计数；这里未关联附件的题录可能仍在D盘有全文，不推断为无全文。', '',
        '|年份|题名|DOI|原17份附件关联|','|---|---|---|---|']
    for r in rows:
        cells=[r['date'],r['title'],r['doi'],r['original_pdf'] or '本表尚未建立关联']
        lines.append('|'+ '|'.join(str(x).replace('|','/').replace('\n',' ') for x in cells)+'|')
    (PUBLIC/'hrg_bibliographic_coverage.md').write_text('\n'.join(lines)+'\n',encoding='utf-8',newline='\n')
    if args.install_links:
        summary=json.loads((PUBLIC/'summary.json').read_text(encoding='utf-8'))
        assert summary['status']=='verified'
        snippet=('\nZotero现用个人库：[完整本地题录与分类索引](zotero-library-20261024.md)。2026-10-24通过官方API登记'
            +str(len(live['items']))+'条目、'+str(len(live['files']))+'个可访问文件附件；D盘'
            +str(summary['source_unique_files'])+'份不同全角文件已在Zotero集合中核验，索引不代表全文逐式阅读。\n')
        for name in ('full-library.md','hrg-whole-angle.md'):
            p=SKILL/'references'/name;text=p.read_text(encoding='utf-8')
            if 'zotero-library-20261024.md' not in text:p.write_text(text.rstrip()+'\n'+snippet,encoding='utf-8',newline='\n')
    print(json.dumps({k:v for k,v in value.items() if k!='records'},ensure_ascii=True))

if __name__=='__main__':main()
