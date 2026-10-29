"""Register this batch in the local skill; keep full texts out of public Git."""
from pathlib import Path
import json
from scholar_piezo_batch import ROOT,OUT,LIB
from index_reference_library import build

SKILL=Path('C:/Users/11725/.codex/skills/ic-reference-library')

def main():
    m=json.loads((OUT/'manifest.json').read_text(encoding='utf-8'))
    LIB.mkdir(parents=True,exist_ok=True)
    for name in ['manifest.json','relevance_review.json','逐条相关性.md']:
        (LIB/name).write_bytes((OUT/name).read_bytes())
    data=dict(date='2026-10-29',source_records=203,counts=m['counts'],
        fulltext_reading_boundary='Not all full texts have been read; see reviewed pages per record',
        library=LIB.as_posix(),book=(ROOT/'压电式半球全角陀螺_逐步推导与文献审读.md').as_posix(),
        review=json.loads((OUT/'relevance_review.json').read_text(encoding='utf-8')))
    ref=SKILL/'references/scholar-piezo-20261029.json'
    ref.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    md=SKILL/'references/scholar-piezo-20261029.md'
    md.write_text('# Scholar压电半球专题（2026-10-29）\n\n'
        f"原始203条；获取统计：{m['counts']}。记录数不是不同作品数。全文获取、文本提取和科学审读严格分开；不宣称全部通读。\n\n"
        f"资料目录：`{LIB.as_posix()}`。逐条来源、SHA、PDF页码及阅读边界见同名JSON。\n\n"
        f"推导续篇：`{data['book']}`。含本构、机电互易、电负载反作用、全角进动及19项复算；不是新一次Simulink或实物验收。\n",encoding='utf-8')
    route=SKILL/'references/hrg-whole-angle.md';text=route.read_text(encoding='utf-8')
    marker='## Scholar压电半球逐条审读（2026-10-29）'
    if marker not in text:
        route.write_text(text+'\n\n'+marker+'\n\n[逐条相关性与阅读边界](scholar-piezo-20261029.md)。203条原始记录的初筛清单及压电推导续篇；不是全库通读声明。\n',encoding='utf-8')
    build(Path('D:/学习资料'),SKILL/'references/full-library','2026-10-29')
    (OUT/'library_registration.json').write_text(json.dumps(dict(registered=True,skill_topic=ref.as_posix(),
        library=LIB.as_posix(),original_pdfs_preserved=True),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

if __name__=='__main__':main()
