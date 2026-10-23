"""Build bounded corpus mapping and source/byte manifests; never alters sources."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SIMULINK_ROOT = ROOT.parent
CATALOG = SIMULINK_ROOT/'layered/evidence/literature_comparison/comparison_catalog.json'

SECTIONS = {
    'L002':'8.7 电极/驱动误差', 'L003':'8.8 频裂识别/物理调平',
    'L009':'8.12 观测非线性专利', 'L010':'8.12 压电换能专利',
    'L027':'8.12 分阶段标补', 'L030':'8.10 经典时空控制专利',
    'L032':'8.10 刚度/频率控制专利', 'L038':'8.9 检测跟踪闭环与TDM',
    'L039':'8.5 往返进动/FRP', 'L050':'8.4、8.6 参数辨识',
    'L052':'7.4；1–6 基线公式', 'L053':'7.3 数字实现与补偿',
    'L054':'7.2 PI/PR/PIR', 'L055':'8.6 误差分离',
    'L056':'8.6 通道全温误差', 'L057':'7.1；1–6、8.3–8.5',
    'L058':'8.1 载波 Kalman 解调', 'L059':'8.4 RLS',
    'L061':'8.2 行波/频率解调', 'L063':'8.3 阻尼死区',
    'L060':'8.12 控制电路实施例', 'L064':'8.10 电极矢量合成',
    'L069':'2.1 连续体投影背景', 'L071':'8.11 轴向非线性RIG',
}
ADDED_PAGES = {'L058':[4,5,6],'L071':[4,5,6]}
CORE_PAGES = {
    'L052':[2,3,4,5], 'L053':[55,56,57,58,59,62,63,64,65],
    'L054':[43,44,45,46], 'L057':[24,25,26,49,50,51,59,60,66,70],
    'L058':[1,2,3,4,5,6], 'L061':[2,3,4,5],
}


def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda:f.read(1024*1024),b''):
            h.update(block)
    return h.hexdigest()


def save(path,text):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(text,encoding='utf-8',newline='\n')


def cell(value):
    return str(value).replace('|',' / ').replace('\n',' ')


def main():
    cat=json.loads(CATALOG.read_text(encoding='utf-8-sig'))
    sources=[]
    for row in cat['local']:
        if row['id'] not in SECTIONS:
            continue
        source=Path(row['paths'][0])
        digest=sha(source)
        if digest != row['sha256']:
            raise RuntimeError(f"Source changed since catalog: {row['id']}")
        sources.append(dict(id=row['id'],title=row.get('title',row['name']),
            path=source.as_posix(),sha256=digest,
            catalog_evidence_level=row.get('level',row.get('evidenceLevel')),
            previously_recorded_pdf_pages=row.get('readPdfPages',[]),
            additionally_read_pdf_pages=ADDED_PAGES.get(row['id'],[]),
            key_comparison_pdf_pages=CORE_PAGES.get(row['id'],[]),
            comparison_section=SECTIONS[row['id']],
            scope='Selected formula pages; not a new claim that every page was read'))
    sources_data=dict(date='2026-10-23',catalog_sha256=sha(CATALOG),
        local_unique=len(cat['local']),online_records=len(cat['online']),
        scope='Formula comparison of selected full-text evidence; exhaustive record mapping with original reading levels preserved',
        local=sources,web=[dict(
            title='Identification and correction of phase delay errors for hemispherical resonator gyroscopes',
            url='https://www.nature.com/articles/s41598-025-86288-1',
            access='2026-10-23 primary publisher search excerpt, phase decomposition/equations 6-12; not complete new full-text review',
            use='Section 9.1 qualitative phase decomposition; coefficient in equation 57 derived independently')])
    save(ROOT/'evidence/sources.json',json.dumps(sources_data,ensure_ascii=False,indent=2)+'\n')
    lines=['# 全部已登记资料与逐式比较的对应表','',
        '日期：2026-10-23。原目录不改写；正文为 `formula_by_formula_comparison.md`。', '',
        f"覆盖 {len(cat['local'])} 项去重本地资料、{len(cat['online'])} 项网上记录。重合文献仍分别保留本地/W记录，不能把总和当成独立论文篇数。",'',
        '**证据边界：**原目录的阅读级别原样保留。只有正文点名、标页的内容进入逐式论证；“待逐式审查”不表示方法不存在或不重要。网上条目保留原始比较边界，不把标题/摘要提升为全文。', '',
        '级别常见值：sections=节选正文；fulltext=原目录记为全文证据；primary_sections=出版方正文节选；primary_abstract=出版方摘要；pending_fulltext=待正文；derived=二次整理；failed/metadata等按原值。即使是全文文件，也只对明确核对的公式作判断。', '',
        '## 本地资料逐项对应', '',
        '|ID|文献/名称|原证据级别；登记PDF页|本文落点/边界|原目录方法描述|',
        '|---|---|---|---|---|']
    for row in cat['local']:
        ident=row['id']
        level=row.get('level',row.get('evidenceLevel',''))
        pages=','.join(map(str,row.get('readPdfPages',[]))) or '无'
        landing=SECTIONS.get(ident,'待逐式审查；保留原方法比较，不能新增方程等价结论')
        if ident=='L058': landing+='；本次补读PDF4–6'
        if ident=='L071': landing+='；本次补读PDF4–6'
        vals=[ident,row.get('title',row['name']),f'{level}；{pages}',landing,row.get('method','见原目录')]
        lines.append('| '+' | '.join(map(cell,vals))+' |')
    lines += ['', '## 网上资源及专利逐项对应', '',
        '以下“原比较/边界”来自已有证据目录，属于原有阅读结论的索引；本次未重新取得所有80项正文。专利的权利要求、实施例和学术论文的理论/实验不是同等级证明。需要逐式比较的未读专利，应先取得公开说明书和明确实施例。', '',
        '|ID|标题与原链接|证据级别|原比较|边界/未完成项|',
        '|---|---|---|---|---|']
    for row in cat['online']:
        title=cell(row.get('title',''))
        url=row.get('url','')
        vals=[row['id'],f'[{title}]({url})' if url else title,
              row.get('level',''),row.get('same',''),row.get('different','')]
        lines.append('| '+' | '.join(map(cell,vals))+' |')
    lines += ['', '新增相位延迟核对见正文9.1及 `evidence/sources.json`；其他网上记录不因本次建立映射而升级为公式已核对。', '']
    save(ROOT/'corpus_mapping.md','\n'.join(lines))
    files=['formula_by_formula_comparison.md','corpus_mapping.md',
           'verify_formulas.py','build_evidence.py','evidence/algebra_checks.json',
           'evidence/sources.json','.gitattributes','requirements.txt']
    checks=json.loads((ROOT/'evidence/algebra_checks.json').read_text(encoding='utf-8'))
    if not checks['passed'] or checks['source_sha256'] != sha(ROOT/'verify_formulas.py'):
        raise RuntimeError('Algebra evidence failed or stale; run verify_formulas.py --write first')
    manifest=dict(date='2026-10-23',scope='Additive formula review; no V7 source/model mutations',
                  algebra_checks=len(checks['checks']),all_passed=checks['passed'],
                  files=[dict(path=f,sha256=sha(ROOT/f)) for f in files])
    save(ROOT/'evidence/manifest.json',json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    print(f"Mapped {len(cat['local'])} local and {len(cat['online'])} online records; verified {len(sources)} local source hashes; sealed {len(files)} deliverable files")


if __name__=='__main__':
    main()
