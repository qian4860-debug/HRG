"""Assemble the fourth book without altering previously accepted books."""
from pathlib import Path
import hashlib
import json
import re

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
BOOK=ROOT/'压电全角验证总书第四版_经典文献逐式演算.md'


def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()


def page(n):
    if n<=2:return 1
    if n<=6:return 2
    if n<=15:return 3
    if n<=25:return 4
    if n<=31:return 5
    if n<=37:return 6
    if n<=40:return 7
    if n<=45:return 8
    return 9


def content():
    files=sorted((HERE/'chapters').glob('*.md'))
    parts=[p.read_text(encoding='utf-8') for p in files]
    title,rest=parts[0].split('\n',1)
    nav='''阅读导航：

- [旋转坐标与机械方程：原式1–6](#L01)
- [Pauli矩阵与向量方程：原式7–11](#L07)
- [复包络与平均法：原式12–17](#L12)
- [旋转的指数表示：原式18–23](#L18)
- [椭圆与七个二次量：原式24–31](#L24)
- [完整慢变量：原式32–39](#L32)
- [控制律与闭合系统：原式40–46](#L40)
- [完整数值算例](#WorkedExample)
- [压电V10映射](#V10Mapping)
'''
    return title+'\n\n'+nav+'\n'+rest+'\n\n---\n\n'+'\n\n---\n\n'.join(parts[1:]),files


def main():
    text,files=content()
    anchors=re.findall(r'<a id="L(\d{2})"></a>',text)
    assert sorted(map(int,anchors))==list(range(1,47)) and len(anchors)==46
    assert text.count(r'\[')==text.count(r'\]')
    BOOK.write_text(text,encoding='utf-8',newline='\n')
    equation_map=[]
    for p in files:
        s=p.read_text(encoding='utf-8')
        for m in re.finditer(r'<a id="L(\d{2})"></a>',s):
            n=int(m[1]);heading=s[m.end():].lstrip().splitlines()[0]
            equation_map.append(dict(original_equation=n,pdf_page=page(n),scan_printed_page=17+page(n),
                                     chapter=p.relative_to(ROOT).as_posix(),anchor='L'+m[1],heading=heading))
    (HERE/'equation_map.json').write_text(json.dumps(equation_map,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    prior=[ROOT/'全角HRG从零到当前_完整推导与验证总书.md',ROOT/'全角HRG验证总书第二版_逐行推导与复算.md',
           ROOT/'压电式半球全角陀螺_逐步推导与文献审读.md',ROOT/'压电全角总书第三版_原理到V10实现.md',
           ROOT/'HRG_WA_simulink/piezo_v10/p10_plant.m',ROOT/'HRG_WA_simulink/piezo_v10/p10_tick.m',
           ROOT/'HRG_WA_simulink/piezo_v10/models/hrg_wa_v10_piezo.slx']
    tracked=files+[p for p in HERE.glob('*') if p.is_file() and p.name!='manifest.json' and p.suffix in {'.py','.m','.json','.md','.csv'}]+[BOOK]
    manifest=dict(date='2026-10-30',book=BOOK.relative_to(ROOT).as_posix(),equation_groups=46,
                  files={p.relative_to(ROOT).as_posix():sha(p) for p in sorted(set(tracked))},
                  preserved_previous_files={p.relative_to(ROOT).as_posix():sha(p) for p in prior},
                  boundary='Theory book and synthetic independent checks; pending other-five fulltexts explicitly retained')
    (HERE/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    print('Built fourth book:',len(text.splitlines()),'lines; all 46 original numbered groups mapped; previous books untouched')


if __name__=='__main__':main()
