"""Register accessible Zotero PDF files even while its metadata API is disabled."""
from pathlib import Path
import json

ROOT=Path(__file__).resolve().parents[1]
SKILL=Path('C:/Users/11725/.codex/skills/ic-reference-library')
SOURCE=ROOT/'research/zotero_integration_20261024/hrg_pdf_sources.json'

def main():
    data=json.loads(SOURCE.read_text(encoding='utf-8'))
    refs=SKILL/'references';name='zotero-wa-files-20261024'
    data['boundary']='File-level extraction and selected-section reading; the complete live-library metadata is indexed separately through the official Local API'
    (refs/(name+'.json')).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    count=len(data['records']);different=sum(not x['same_bytes_in_head_folder'] for x in data['records'])
    text=f'''# Zotero全角陀螺PDF补充

2026-10-24从本机`C:/Users/11725/Zotero/storage`登记{count}份可访问PDF，SHA256均不同，其中{different}份与D盘全角陀螺目录现有文件的字节不同。这些可能是新论文，也可能是不同版本，不能只凭字节不同判为新出版物。

[文件路径、SHA256、页数及提取状态]({name}.json)。已提取全部可解析正文，但全文提取不等于逐式通读。已核对公式与独立数值反例记录在工程`HRG_WA_simulink/literature_zotero_research/docs/source_formula_updates.md`。原PDF保留Zotero原位，未复制或上传到工程GitHub。

这份补充是文件级索引。[现用Zotero完整题录与分类](zotero-library-20261024.md)由官方Local API另外登记；不能把旧SQLite备份当现用资料库。现用数据库不被本脚本写入。工程中的`docs/paper_comparison.md`与`evidence/source_reading.json`逐份记录实际审读范围。
'''
    (refs/(name+'.md')).write_text(text,encoding='utf-8',newline='\n')
    for target in ('full-library.md','hrg-whole-angle.md'):
        p=refs/target;old=p.read_text(encoding='utf-8');link=f'[{name}]({name}.md)'
        if link not in old:p.write_text(old.rstrip()+'\n\nZotero本地PDF补充：'+link+'。登记与全文提取不代表全部推导已核验。\n',encoding='utf-8',newline='\n')
    print(json.dumps(dict(registered_pdfs=count,byte_distinct_from_D_folder=different),ensure_ascii=True))

if __name__=='__main__':main()
