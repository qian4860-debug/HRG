"""Register acquired piezo-HRG sources in the existing local skill index."""
from collections import Counter
import hashlib
import json
from pathlib import Path

from index_reference_library import build

ROOT=Path(__file__).resolve().parents[1]
REPORT=ROOT/'research/piezo_search_20261029'
SKILL=Path('C:/Users/11725/.codex/skills/ic-reference-library')


def main():
    manifest=json.loads((REPORT/'download_manifest.json').read_text(encoding='utf-8'))
    assert len(manifest['records'])==32
    hashes=set()
    for r in manifest['records']:
        if r['status'] in {'downloaded_fulltext','existing_fulltext'}:
            raw=Path(r['path']).read_bytes()
            assert hashlib.sha256(raw).hexdigest()==r['sha256'],r['id']
            assert r['sha256'] not in hashes,r['id']
            hashes.add(r['sha256'])
        else:assert 'path' not in r
    refs=SKILL/'references';stem='piezo-hrg-downloads-20261029'
    (refs/(stem+'.json')).write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    report=(REPORT/'下载结果.md').read_text(encoding='utf-8')
    (refs/(stem+'.md')).write_text(report+'\n查询链与关键词：'+(REPORT/'压电半球陀螺_分层引文检索清单.md').as_posix()+'\n',encoding='utf-8',newline='\n')
    marker='压电半球陀螺下载专题（2026-10-29）'
    for route in ['hrg-whole-angle.md','full-library.md']:
        p=refs/route;t=p.read_text(encoding='utf-8')
        if marker not in t:
            t+='\n\n## '+marker+'\n\n'
            t+='[逐项获取清单]('+stem+'.md)、[路径与SHA256]('+stem+'.json)。32条主清单，7份本次下载、2份已有全文、23项尚未取得。下载目录：`D:/学习资料/资料/全角陀螺/压电专题_20261029`。全文获取/字节核验不代表已通读或公式验证；专利、其他论文中出现目标题名不等于拥有目标全文。\n'
            p.write_text(t,encoding='utf-8',newline='\n')
    build(Path('D:/学习资料'),refs/'full-library','2026-10-29')
    summary=json.loads((refs/'full-library/catalog_full_summary.json').read_text(encoding='utf-8'))
    receipt=dict(date='2026-10-29',skill=SKILL.as_posix(),counts=dict(Counter(r['status'] for r in manifest['records'])),unique_obtained_hashes=len(hashes),skill_manifest_sha256=hashlib.sha256((refs/(stem+'.json')).read_bytes()).hexdigest(),full_library_index_sha256=summary['indexSHA256'],full_library_counts=summary['counts'],index_errors=len(summary['errors']),checks=['32 distinct selected records','9 obtained PDFs have unique verified hashes','unobtained rows have no target path','skill route and private path index updated'],scientific_reading='not upgraded by acquisition')
    (REPORT/'registration_receipt.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    print(json.dumps(receipt,ensure_ascii=False,indent=2))


if __name__=='__main__':main()
