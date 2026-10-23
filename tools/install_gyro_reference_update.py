"""Install the user-requested whole-library index into the existing local skill.

Prepare first; --apply checks saved baseline bytes, preserves pre-existing catalog
edits, and commits only this update using index versions built from Git HEAD.
No document copies or full personal-library listing are sent to GitHub.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

PROJECT = Path(__file__).resolve().parents[1]
WORK = PROJECT/'HRG_WA_simulink/layered/_work/literature_comparison'
STAGE = WORK/'skill_update'
SKILL = Path('C:/Users/11725/.codex/skills/ic-reference-library')
EVIDENCE = PROJECT/'HRG_WA_simulink/layered/evidence/literature_comparison'
FOUR = ['半球谐振陀螺量化误差与阻尼误差抑制技术研究.pdf',
        '半球谐振陀螺全角模式控制技术研究与实现.pdf',
        '半球谐振陀螺全角模式控制与误差补偿系统设计与实.pdf',
        '半球谐振陀螺全角模式信号处理控制方法.pdf']
MD_APPEND = '\n\n## 完整学习资料与全角HRG专题（2026-10-23）\n\n- D:/学习资料：已递归登记全部可访问文件/目录。使用 [完整目录索引](full-library.md)，路径索引不代表全文已读，压缩包未解包。\n- [全角HRG文献与方法对比](hrg-whole-angle.md)：四篇指定原文、专题去重目录及既往网络资源，阅读页码和方法差异分别记录。\n'
SKILL_APPEND = '\n\n## 完整目录与全角陀螺专题\n\n用户已将整个 `D:/学习资料` 加入本技能。检索未在领域目录中单列的资料时，使用 [完整文件索引](references/full-library.md) 的本地查询脚本；全角HRG任务另读 [原文与推导对照](references/hrg-whole-angle.md)。索引包含原文件路径和元数据，不表示全文阅读；PDF自动前页筛查、人工已读页码和解析失败分别记录。压缩包仅登记入口，参考工程代码不因入库而获准执行。\n'


def additions():
    rows = [dict(category='完整学习资料库',name='D盘学习资料完整递归索引',path='D:/学习资料',exists=True,type='folder',
                 index='references/full-library/catalog_full.jsonl.gz',reading_status='路径与元数据索引；非全文已读'),
            dict(category='陀螺与惯性接口',name='全角HRG原文与推导方法专题',path='D:/学习资料/资料/全角陀螺',exists=True,type='folder',
                 index='references/hrg-whole-angle.json',reading_status='逐篇层级与已读页码见专题')]
    catalog = json.loads((EVIDENCE/'comparison_catalog.json').read_text(encoding='utf-8'))
    for name in FOUR:
        item = next(r for r in catalog['local'] if r['name']==name)
        rows.append(dict(category='陀螺与惯性接口／全角模式',name=name,path='D:/学习资料/资料/全角陀螺/'+name,
                         exists=True,type='file',sha256=item['sha256'],pdf_pages=item['pages'],
                         read_pdf_pages=item['readPdfPages'],reading_status=item['level'],index='references/hrg-whole-angle.md'))
    return rows


def append_json(original, rows):
    prior = json.loads(original.decode('utf-8-sig'))
    assert not any(r.get('name')==rows[0]['name'] for r in prior), 'Update already installed'
    point = original.rfind(b']')
    addition = ((',' if prior else '')+'\n'+json.dumps(rows,ensure_ascii=False,indent=2)[1:-1]+'\n').encode('utf-8')
    result = original[:point]+addition+original[point:]
    assert json.loads(result.decode('utf-8-sig')) == prior+rows
    return result


def prepare():
    baseline = WORK/'skill_baseline'
    hashes=json.loads((baseline/'hashes.json').read_text(encoding='utf-8'))
    STAGE.mkdir(parents=True,exist_ok=True)
    rows=additions()
    for rel in ['SKILL.md','references/catalog.md','references/catalog.json']:
        before=(baseline/Path(rel).name).read_bytes()
        assert hashlib.sha256(before).hexdigest()==hashes[rel]
        after=append_json(before,rows) if rel.endswith('.json') else before+(SKILL_APPEND if rel=='SKILL.md' else MD_APPEND).encode('utf-8')
        target=STAGE/rel;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(after)
    refs=STAGE/'references';full=refs/'full-library';full.mkdir(exist_ok=True)
    for name in ['catalog_full.jsonl.gz','catalog_full_summary.json']:
        shutil.copyfile(WORK/'skill_index'/name,full/name)
    screened=json.loads((WORK/'library_pdf_screening_summary.json').read_text(encoding='utf-8'))
    # Keep the full private screening register in the local skill, not in HRG GitHub.
    shutil.copyfile(WORK/'library_pdf_screening.json',full/'pdf_front_screening.json')
    (refs/'full-library.md').write_text('''# 完整学习资料目录索引

根目录：`D:/学习资料`。2026-10-23递归登记46213个文件、8577个目录，遍历错误0。隐藏条目和工程文件也纳入；原文件保持原位，压缩包未解包，链接不递归以免越出根目录/循环。

索引：`full-library/catalog_full.jsonl.gz`，摘要/索引SHA：`full-library/catalog_full_summary.json`。字段为relative、type、size、mtimeNs；文件内容未整体读取、没有将索引当作全文阅读。

查询示例（多个关键词按AND匹配完整相对路径）：

```powershell
D:/python/python.exe C:/Users/11725/.codex/skills/ic-reference-library/scripts/index_reference_library.py --output C:/Users/11725/.codex/skills/ic-reference-library/references/full-library --search 全角 量化
```

需要更新时同一脚本去掉--search并增加`--as-of YYYY-MM-DD`；脚本只重建本地索引，不修改原资料。更新后检查统计与错误并纳入本技能本地Git。

1054份PDF的前两页/元数据自动筛查有1041份成功、13份失败、55个命中；`full-library/pdf_front_screening.json`仅为机器筛查，不是人工全文阅读。扫描封面、字体和正文关键词可能漏检。全角主题用[专题索引](hrg-whole-angle.md)的人工页码和对照；通用库其余文件按任务选读。完整个人目录只在此技能的本地Git管理，不自动同步HRG公共仓库。
''',encoding='utf-8',newline='\n')
    (refs/'hrg-whole-angle.md').write_text('''# 全角HRG原文与推导专题

原资料根目录：`D:/学习资料/资料/全角陀螺`。用户指定四篇原文均已确认存在并单列到领域目录。机器索引[hrg-whole-angle.json](hrg-whole-angle.json)包含73个专题/邻近资料字节对象、重复路径、SHA、PDF页数、实际核对页码、推导方法和比较边界，另含80条恢复的网络记录。

详细对照在本地工程：`C:/Users/11725/Desktop/HRG_WA/HRG_WA_simulink/layered/docs/literature_derivation_comparison.md`；逐项表`literature_method_matrix.md`及可筛选`literature_method_matrix.html`位于同目录。该工程路径不可用时仍可用本技能JSON及原PDF定位。

优先查阅：陈洋2023量化/阻尼论文L057，蒲云飞2022控制/PIR/分时论文L054，刘学2024电路复用/误差补偿论文L053，张岚昕等2019信号处理控制L052。原文的模态角与物理圆周角、半幅/双幅解调、模拟解调前后ADC、TIA/电荷放大器参考面要先映射。

2026-10-23新增关键边界：PI仅有局部设计不保证周期扰动无差；PIR、完整卸荷切换、在线电调尚不等于当前模型已实现。L052式(4)-(7)、L057 PDF25式(2.16)、L060 PDF4式(8)有独立代数反例，按具体公式核对，不能否定整个原文。L062综述PDF解析失败（Unexpected EOF），不得继续继承旧目录的已核验声称。

机器筛查/书目/摘要/人工节选分别标注；未取得正文的网络条目不能按题名推断算法、系数或性能。目录收录不是所有论文逐式等价证明。
''',encoding='utf-8',newline='\n')
    shutil.copyfile(EVIDENCE/'comparison_catalog.json',refs/'hrg-whole-angle.json')
    scripts=STAGE/'scripts';scripts.mkdir(exist_ok=True)
    shutil.copyfile(PROJECT/'tools/index_reference_library.py',scripts/'index_reference_library.py')
    print('Prepared reviewable skill update:',STAGE.as_posix())


def apply():
    hashes=json.loads((WORK/'skill_baseline/hashes.json').read_text(encoding='utf-8'))
    resuming=all((SKILL/rel).read_bytes()==(STAGE/rel).read_bytes() for rel in hashes)
    for rel,digest in hashes.items():
        assert resuming or hashlib.sha256((SKILL/rel).read_bytes()).hexdigest()==digest, 'Concurrent skill edit: '+rel
    git=['git','-c','core.autocrlf=false','-c','core.whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol',
         '-c','user.name=Codex','-c','user.email=codex@local','-C',str(SKILL)]
    def run(*args,data=None):
        return subprocess.check_output(git+list(args),input=data)
    staged={x for x in run('diff','--cached','--name-only').decode().splitlines() if x}
    prepared={p.relative_to(STAGE).as_posix() for p in STAGE.rglob('*') if p.is_file()}
    assert (resuming and staged<=prepared) or not staged, 'Existing staged changes must remain separate'
    # Build catalog index versions against HEAD, retaining the user's existing live edits unstaged.
    overlays={}
    for rel in ['SKILL.md','references/catalog.json','references/catalog.md']:
        before=run('show','HEAD:'+rel)
        overlays[rel]=append_json(before,additions()) if rel.endswith('.json') else before+(SKILL_APPEND if rel=='SKILL.md' else MD_APPEND).encode('utf-8')
    files=[]
    for source in STAGE.rglob('*'):
        if source.is_file():
            rel=source.relative_to(STAGE);target=SKILL/rel;target.parent.mkdir(parents=True,exist_ok=True)
            assert not target.exists() or rel.as_posix() in hashes or (resuming and target.read_bytes()==source.read_bytes()), 'Unexpected existing skill resource: '+str(rel)
            shutil.copyfile(source,target);files.append(rel.as_posix())
    for rel,data in overlays.items():
        blob=run('hash-object','-w','--stdin',data=data).decode().strip()
        run('update-index','--add','--cacheinfo','100644',blob,rel)
    regular=[p for p in files if p not in overlays]
    run('add','--',*regular)
    run('diff','--cached','--check')
    run('commit','-m','Index full D learning library and add whole-angle HRG source comparisons')
    run('tag','-a','full-reference-library-20261023','-m','Full local path inventory, PDF screening, four-source detailed comparisons')
    # Check that only the pre-existing catalog additions remain unstaged.
    before_json=json.loads((WORK/'skill_baseline/catalog.json').read_text(encoding='utf-8-sig'))
    live_json=json.loads((SKILL/'references/catalog.json').read_text(encoding='utf-8-sig'))
    assert live_json==before_json+additions()
    assert (SKILL/'references/catalog.md').read_bytes()==(WORK/'skill_baseline/catalog.md').read_bytes()+MD_APPEND.encode('utf-8')
    receipt=dict(date='2026-10-23',skill=SKILL.as_posix(),localCommit=run('rev-parse','HEAD').decode().strip(),
                 localOnly=True,preexistingCatalogEditsPreserved=True,
                 fullIndexCounts={'files':46213,'directories':8577,'traversalErrors':0,'pdfs':1054},
                 installedHashes={rel:hashlib.sha256((SKILL/rel).read_bytes()).hexdigest() for rel in files},
                 globalListingPolicy='Full personal listing stays in the local skill repository, not HRG GitHub')
    (EVIDENCE/'skill_install_receipt.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(receipt,ensure_ascii=False,indent=2))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--apply',action='store_true');args=parser.parse_args()
    if args.apply:
        apply()
    else:
        prepare()
