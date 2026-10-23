"""Register the bounded Lynch citing subset in the user's local reference skill.

The complete private index remains outside the HRG repository and GitHub.
"""
from pathlib import Path
import json
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[1]
REPORT=ROOT/'research/lynch1995_citing_20261024'
SKILL=Path('C:/Users/11725/.codex/skills/ic-reference-library')

def main():
    summary=json.loads((REPORT/'summary.json').read_text(encoding='utf-8'))
    manifest=json.loads((REPORT/'fulltext_manifest.json').read_text(encoding='utf-8'))
    refs=SKILL/'references';name='lynch1995-citing-20261024'
    data=dict(summary=summary,records=manifest['records'],
        acquisition_register=(REPORT/'records.json').as_posix(),
        requested_list='https://scholar.google.com/scholar?cites=15957943393310504435',
        reading_level='Identity and reverse citation only; not full formula review')
    (refs/(name+'.json')).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    text=f'''# Lynch 1995 被引文献专题

登记日期：2026-10-24。用户提供Scholar被引列表cites=15957943393310504435；浏览器正文读取超时，**尚未完整枚举该列表**。本专题是从已持有原文及公开出版方/大学库恢复的可核实子集，方向为后续论文引用Lynch 1995，不是Lynch的参考文献表。

已确认引用关系的记录{summary['confirmed_citing_records']}条，其中可访问且身份核验的全文{summary['confirmed_citing_fulltexts']}条：新增下载{summary['new_confirmed_citing_fulltexts']}条，库内已有{summary['existing_confirmed_citing_fulltexts']}条。同文异写可能保留不同记录，独立字节计数见JSON，不能将记录数直接当篇数或覆盖率。

按SHA256去重为{summary['unique_confirmed_fulltext_hashes']}份独立PDF，其中新增{summary['new_unique_confirmed_fulltext_hashes']}份、复用原库{summary['existing_unique_confirmed_fulltext_hashes']}份。不同版本即使字节不同也可能属于同一篇论文，不将文件数直接等同于出版物数。

本地入口：`{summary['library']}/README.md`；已有全文保留原路径，不重复搬移。详细清单：[全文路径和SHA256]({name}.json)；完整检索及失败原因在`{REPORT.as_posix()}/records.json`。新全文仅完成身份/引用关系核验，尚未逐式阅读；候选未确认者不会标为被引论文。

完整私人目录仅在本技能本地Git保存，不随HRG公开源码同步。Scholar题录恢复后须按DOI、题名、年份和版本继续核对覆盖缺口。
'''
    (refs/(name+'.md')).write_text(text,encoding='utf-8',newline='\n')
    topic=refs/'hrg-whole-angle.md';old=topic.read_text(encoding='utf-8')
    link=f'[{name}]({name}.md)'
    if link not in old:
        topic.write_text(old.rstrip()+'\n\n2026-10-24新增Lynch 1995被引专题：'+link+'。这是可核实子集，尚未完整取得Scholar题录；全文获取不等于推导核验。\n',encoding='utf-8',newline='\n')
    subprocess.run([sys.executable,str(SKILL/'scripts/index_reference_library.py'),
         '--output',str(refs/'full-library'),'--as-of','2026-10-24'],check=True)
    print(json.dumps(dict(skill=SKILL.as_posix(),confirmed_fulltexts=summary['confirmed_citing_fulltexts']),ensure_ascii=True))

if __name__=='__main__':main()
