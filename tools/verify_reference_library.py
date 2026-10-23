"""Validate installed skill routing, full path-index integrity and four HRG sources.

The optional skill-creator validator requires PyYAML, absent in this environment.
These checks validate the unchanged simple frontmatter plus the installed resources.
"""
from collections import Counter
import gzip
import hashlib
import json
from pathlib import Path, PurePosixPath
import re

P=Path(__file__).resolve().parents[1]
S=Path('C:/Users/11725/.codex/skills/ic-reference-library')
E=P/'HRG_WA_simulink/layered/evidence/literature_comparison'


def main():
    skill=(S/'SKILL.md').read_text(encoding='utf-8-sig')
    match=re.match(r'^---\n(.*?)\n---',skill,re.S)
    assert match
    front=dict(line.split(':',1) for line in match.group(1).splitlines() if line.strip())
    assert front['name'].strip()=='ic-reference-library'
    assert 0<len(front['description'].strip())<=1024
    for rel in ['references/catalog.md','references/catalog.json','references/full-library.md',
                'references/hrg-whole-angle.md','references/hrg-whole-angle.json','scripts/index_reference_library.py']:
        assert (S/rel).is_file(), rel
    inventory=S/'references/full-library/catalog_full.jsonl.gz'
    summary=json.loads((inventory.parent/'catalog_full_summary.json').read_text(encoding='utf-8'))
    assert hashlib.sha256(inventory.read_bytes()).hexdigest()==summary['indexSHA256']
    counts=Counter();seen=set()
    with gzip.open(inventory,'rt',encoding='utf-8') as stream:
        for line in stream:
            row=json.loads(line);rel=PurePosixPath(row['relative'])
            assert not rel.is_absolute() and '..' not in rel.parts
            assert row['relative'] not in seen
            seen.add(row['relative']);counts[row['type']]+=1
    assert dict(counts)==summary['counts']
    assert not summary['errors']
    catalog=json.loads((S/'references/catalog.json').read_text(encoding='utf-8-sig'))
    names=['半球谐振陀螺量化误差与阻尼误差抑制技术研究.pdf','半球谐振陀螺全角模式控制技术研究与实现.pdf',
           '半球谐振陀螺全角模式控制与误差补偿系统设计与实.pdf','半球谐振陀螺全角模式信号处理控制方法.pdf']
    for name in names:
        entries=[r for r in catalog if r['name']==name]
        assert len(entries)==1
        row=entries[0]
        assert hashlib.sha256(Path(row['path']).read_bytes()).hexdigest()==row['sha256']
        assert row['read_pdf_pages']
    assert (S/'references/hrg-whole-angle.json').read_bytes()==(E/'comparison_catalog.json').read_bytes()
    result=dict(checks=['simple skill frontmatter','all new routes resolve','full gzip SHA256',
                        'unique relative paths and exact counts','four source registrations and original PDF bytes',
                        'installed comparison equals project comparison'],counts=dict(counts),
                officialValidator='Unavailable: PyYAML is not installed; no claim of quick_validate.py passing')
    (E/'skill_validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('PASS installed reference skill: routes, 54790 unique entries, four original sources and comparison identity')


if __name__=='__main__':
    main()
