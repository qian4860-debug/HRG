"""Archive the provided original bytes and register bounded reading evidence.

Apply only for this user's authorized local reference-library workflow.
Original PDFs stay outside the public HRG repository.
"""
from pathlib import Path
import hashlib
import json
import shutil

ROOT=Path(__file__).resolve().parents[2]
OUT=Path(__file__).resolve().parent
WORK=ROOT/'HRG_WA_simulink/layered/_work/lynch_classics_20261030'
LIB=Path('D:/学习资料/资料/全角陀螺/经典文献_20261030')
SKILL=Path('C:/Users/11725/.codex/skills/ic-reference-library')


def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()


def archive(source,target):
    if target.exists():
        assert sha(source)==sha(target),'Refuse to overwrite different reference bytes'
    else:shutil.copyfile(source,target)
    return dict(path=target.as_posix(),sha256=sha(target),bytes=target.stat().st_size)


def main():
    LIB.mkdir(parents=True,exist_ok=True)
    original=Path('C:/Users/11725/xwechat_files/wxid_qvgyt57csh8y22_a935/msg/file/2026-10/vibratory gyro analysis by the method of averaging-Lynch经典.pdf')
    source=archive(original,LIB/'Lynch_平均法_用户提供九页扫描.pdf')
    source.update(id='lynch_averaging_scan',title='Vibratory Gyro Analysis by the Method of Averaging',author='D. D. Lynch',
                  original_path=original.as_posix(),pdf_pages=9,printed_pages='18–26',visual_pages_reviewed=list(range(1,10)),
                  equations_reviewed=list(range(1,47)),year='Conventionally cited as 1995; proceedings title/copyright pages absent from provided scan',
                  boundary='All 46 numbered equation groups reviewed and independently derived; handwritten annotations not treated as authorial print; not an exact-HRG-geometry or hardware proof')
    app=archive(WORK/'zhinst_citation.pdf',LIB/'Zurich_2015_Control_of_MEMS_CVG_公开应用笔记.pdf')
    app.update(id='zhinst_2015',title='Control of MEMS Coriolis Vibratory Gyroscopes',pdf_pages=9,text_pages_reviewed=[9],
               url='https://www.zhinst.com/sites/default/files/zi_appnote_mems_gyroscope.pdf',
               boundary='Reference [6] reviewed as a route to Lynch 1998 Annex B; not a substitute for that original')
    pending=[
        dict(id='lynch_1998',title='Coriolis Vibratory Gyros',status='conference_TOC_verified_no_fulltext',url='https://www.tu-braunschweig.de/index.php?eID=dumpFile&f=177401&t=f&token=535e2fe0f690dfe51fd898b4828c2d6c8952a483',note='University TOC says 15/16 September 1998; do not use old erroneous MEMS-PDF mapping'),
        dict(id='ragot_2011',title='A new control mode greatly improving performance of axisymmetrical vibrating gyroscopes',doi='10.1134/S2075108711040134',url='https://link.springer.com/article/10.1134/S2075108711040134',status='publisher_abstract_only_no_equation_claim'),
        dict(id='jeanroy_2014',title='HRG and marine applications',doi='10.1134/S2075108714020047',url='https://link.springer.com/article/10.1134/S2075108714020047',status='publisher_abstract_only_no_equation_claim'),
        dict(id='rozelle_2009',title='The Hemispherical Resonator Gyro: From Wineglass to the Planets',url='https://www.researchgate.net/publication/279909300_The_Hemispherical_Resonator_Gyro_From_Wineglass_to_the_Planets',status='author_public_fulltext_HTML_partial_sections_reviewed_PDF_not_obtained',note='Identity and selected history/electronics excerpts, not whole-paper or equation verification'),
        dict(id='lynch_history',title='HRG Development at Delco, Litton, and Northrop Grumman',status='secondary_bibliographic_identity_only_original_not_obtained',note='2008 workshop / 2009 proceedings distinction unresolved without original; not two assumed independent papers')]
    results=json.loads((OUT/'checks.json').read_text(encoding='utf-8'))
    attempts=json.loads((WORK/'download_attempts.json').read_text(encoding='utf-8'))
    attempts.append(json.loads((WORK/'archive_attempt.json').read_text(encoding='utf-8')))
    # Local-only intermediate relative paths are not useful public evidence.
    for r in attempts:r.pop('first_page',None);r.pop('path',None)
    data=dict(date='2026-10-30',sources=[source,app],recommended_other_papers=pending,public_download_attempts=attempts,
              independent_python_checks=results['total'],boundary='Source identity and explicit reading levels; other-five fulltext gap remains')
    (OUT/'sources.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    name='lynch-averaging-20261030'
    (SKILL/'references'/f'{name}.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    text=f'''# Lynch 平均法原文：2026-10-30 更新

用户提供的九页扫描已经归档，SHA256 `{source['sha256']}`，文件：`{source['path']}`。PDF1–9、印刷页18–26、原式1–46逐组视觉阅读与独立演算。通常引为1995，但扫描件无原卷出版页，页码不改写成常见引文的26–34。手写批注不视为作者原文。

总书第四版：`{(ROOT/'压电全角验证总书第四版_经典文献逐式演算.md').as_posix()}`。36项NumPy独立检查和4项MATLAB检查通过；为合成理论夹具，不是新增实物/Simulink/RTL验收。

Lynch1998、Ragot2011、Jeanroy2014、Rozelle2009、Lynch发展史已搜索；仅Rozelle有作者公开全文网页，本轮审读部分段落，其余正文未取得。已取得的Zurich应用笔记PDF9[6]提供1998论文收入IEEE1431附录B的线索，不等于取得该论文。详细边界见[{name}.json]({name}.json)。

本条更新此前“Lynch1995尚未取得”的历史状态，不改动封存历史索引，也不把Lynch1998错误关联的另一篇MEMS论文当作原文。
'''
    (SKILL/'references'/f'{name}.md').write_text(text,encoding='utf-8',newline='\n')
    topic=SKILL/'references/hrg-whole-angle.md';s=topic.read_text(encoding='utf-8');link=f'[{name}]({name}.md)'
    if link not in s:topic.write_text(s.rstrip()+'\n\n2026-10-30 Lynch平均法原文已取得并逐式审读：'+link+'。此前1995未取得为历史状态；1998正文仍未取得。\n',encoding='utf-8',newline='\n')
    print('Archived original scan and official application note; registered exact reading scope, no PDFs copied into public project')


if __name__=='__main__':main()
