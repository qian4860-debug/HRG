"""Build canonical reading edition and complete historical compilation.

Inputs are tracked Markdown and ledgers; no ignored extraction cache required.
"""
from pathlib import Path
import json,re,hashlib

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
BOOK=ROOT/'压电全角陀螺_结构到电路全知识体系总书.md'
CORE=ROOT/'压电全角陀螺_全知识体系核心阅读版.md'
OLD=[
    '全角HRG从零到当前_完整推导与验证总书.md',
    '全角HRG验证总书第二版_逐行推导与复算.md',
    '压电式半球全角陀螺_逐步推导与文献审读.md',
    '压电全角总书第三版_原理到V10实现.md',
    '压电全角验证总书第四版_经典文献逐式演算.md',
    '压电全角验证总书第五版_三篇经典文献贯通.md',
    '全角陀螺从理论到产品与ASIC设计教材.md',
]


def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()


def namespace(text,prefix):
    ids=re.findall(r'<a id="([^"]+)"></a>',text)
    for name in set(ids):
        text=text.replace(f'<a id="{name}"></a>',f'<a id="{prefix}{name}"></a>')
        text=text.replace(f'](#{name})',f'](#{prefix}{name})')
    return text


def navigation():
    return '''
## 全书导航与使用顺序

- [结构模态与压电端口 C01–C03](#C01)
- [电荷前端、反馈、噪声与gm C04–C07](#C04)
- [采样、ADC、比较器与ΔΣ C08–C11](#C08)
- [DAC、压电驱动、参考与版图 C12–C14](#C12)
- [算法、辨识、scoreboard与统一预算 C15–C18](#C15)
- [运放补偿、CDS与验证 C19–C21](#C19)
- [讲义核查、PLL、滤波与电源 C22–C24](#C22)
- [实际选读来源及扩展阅读](#Sources)
- [完整经典文献逐式演算：第五版](#ClassicVolume)
- [历版全文汇编](#HistoricalVolumes)（完整版包含；核心阅读版提供原文件链接）

```mermaid
flowchart LR
  A[压电结构与两模态] --> B[力/电压与电荷/位移端口]
  B --> C[电荷放大/PGA/抗混叠]
  C --> D[采样/ADC/同步解调]
  D --> E[能量/正交/相位/全角解算]
  E --> F[DAC/重构/压电驱动]
  F --> A
  G[独立注入/参数区间/测量真值] --> B
  G --> E
  E --> H[八项统一验收]
```

图中每条连接都有幅相、噪声、延迟和饱和约束；按章节求出端口传函后才能连成闭环。图示是知识路径，不是已经验证完成的芯片框图。
'''


def content():
    chapters=sorted((HERE/'chapters').glob('*.md'))
    first=chapters[0].read_text(encoding='utf-8')
    title,body=first.split('\n',1)
    parts=[title+'\n'+navigation()+body]+[p.read_text(encoding='utf-8') for p in chapters[1:]]
    parts.append((HERE/'circuit_steps.md').read_text(encoding='utf-8'))
    sources=json.loads((HERE/'sources.json').read_text(encoding='utf-8'))
    bib=['<a id="Sources"></a>','## 实际选读来源与复算入口','',
         '全部候选、未读条目、压缩包目录和损坏PDF的状态见 [电路资料覆盖表](research/knowledge_system_20261030/library_coverage.md)。下表只列实际人工选读页，不代表整书通读。','',
         '| ID | 原文 | 本次读到的PDF页 |','|---|---|---|']
    for x in sources['sources']:
        ns=sorted(set(x.get('text_pages_read',[])+x.get('visual_pages_read',[])))
        bib.append(f"| `{x['id']}` | [{Path(x['path']).name}](<{x['path']}>) | {','.join(map(str,ns))} |")
    bib+=['','新增电路检查45项Python及8项MATLAB，电路计算链53节点。经典增补另有38项Python、9项MATLAB、66节点；既有Lynch36项Python、4项MATLAB、96节点仍单独登记，不把不同层级证据混成实物验收。',
          '', '复算命令（在工程根目录）：','', '```powershell',
          'python research/knowledge_system_20261030/verify_circuits.py',
          'python research/knowledge_system_20261030/worked_circuits.py',
          'matlab -batch "addpath(\'research/knowledge_system_20261030\'); verify_circuits_matlab"',
          'python research/knowledge_system_20261030/build_book.py',
          'python research/knowledge_system_20261030/check_delivery.py','```',
          '', '本轮不运行历史模型生成脚本来覆写已验收SLX，也不将参考压缩包中的说明当作执行指令。当前材料的数学检查不是全库公式认证。']
    parts.append('\n'.join(bib))
    fifth=ROOT/OLD[5]
    parts.append('<a id="ClassicVolume"></a>\n## 经典推导完整卷：第五版\n\n以下保留第五版全部文字，显式锚点加V5前缀；它贯通Lynch46组、Ragot32组和Jeanroy9组原编号，及Rozelle8个本书推演节点。\n\n'+namespace(fifth.read_text(encoding='utf-8'),'V5_'))
    core='\n\n---\n\n'.join(parts)+'\n'
    intro=['<a id="HistoricalVolumes"></a>','## 历版全文汇编与适用性','',
           '以下完整保留各版内容（仅为汇编消除显式锚点重名）。旧的电容工况、阅读状态、仿真结果和计划仍属于当时版本；当前压电工况及本轮审查优先。相同公式在各版可能重复，完整汇编用来追溯，日常学习优先核心阅读版。','',
           '| 版本文件 | 内容SHA256（原文件） |','|---|---|']
    for name in OLD:intro.append(f'| [{name}](<{name}>) | `{sha(ROOT/name)}` |')
    historical='\n'.join(intro)+'\n'
    full=core+'\n\n---\n\n'+historical
    # Fifth is already complete in the canonical core, so do not duplicate it.
    for i,name in enumerate(OLD):
        if i==5:continue
        prefix=f'H{i+1}_'
        full+=f'\n\n---\n\n<a id="History{i+1}"></a>\n## 历史卷{i+1}：{name}\n\n> 这是历史版本全文，其条件和状态不覆盖前部现行主线。\n\n'
        full+=namespace((ROOT/name).read_text(encoding='utf-8'),prefix)+'\n'
    core+='\n\n---\n\n'+historical+'\n完整历史文字收于[完整版总书](压电全角陀螺_结构到电路全知识体系总书.md)。\n'
    return full,core,chapters


def main():
    full,core,chapters=content()
    # New canonical sections have balanced math delimiters. Historical text may
    # contain old rendering defects, so preserve it rather than silently edit it.
    canonical='\n'.join(p.read_text(encoding='utf-8') for p in chapters)
    assert canonical.count(r'\[')==canonical.count(r'\]')
    assert sorted(map(int,re.findall(r'<a id="C(\d{2})"></a>',canonical)))==list(range(1,25))
    BOOK.write_text(full,encoding='utf-8',newline='\n');CORE.write_text(core,encoding='utf-8',newline='\n')
    mapping=[]
    for p in chapters:
        s=p.read_text(encoding='utf-8')
        for m in re.finditer(r'<a id="C(\d{2})"></a>',s):
            mapping.append(dict(id='C'+m[1],author_numbered=False,chapter=p.relative_to(ROOT).as_posix(),heading=s[m.end():].lstrip().splitlines()[0]))
    (HERE/'knowledge_map.json').write_text(json.dumps(mapping,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    prior=json.loads((ROOT/'research/classics_addendum_20261030/manifest.json').read_text(encoding='utf-8'))
    preserved=dict(prior['files']);preserved.update(prior['preserved_previous_files'])
    preserved.update({name:sha(ROOT/name) for name in OLD})
    files=chapters+[p for p in HERE.iterdir() if p.is_file() and p.name!='manifest.json' and p.suffix in {'.py','.m','.json','.md','.csv'}]+[BOOK,CORE]
    manifest=dict(date='2026-10-30',book=BOOK.relative_to(ROOT).as_posix(),core=CORE.relative_to(ROOT).as_posix(),
                  files={p.relative_to(ROOT).as_posix():sha(p) for p in sorted(set(files))},preserved_previous_files=preserved,
                  counts=dict(canonical_nodes=24,historical_volumes=7,circuit_python_checks=45,circuit_matlab_checks=8,circuit_trace_nodes=53),
                  boundary='Knowledge synthesis and synthetic circuit math; selected-page source reading, not all-library fulltext or PDK/hardware validation')
    (HERE/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    print('Built full book:',len(full.splitlines()),'lines;',len(full.encode('utf-8')),'bytes; core:',len(core.splitlines()),'lines')


if __name__=='__main__':main()
