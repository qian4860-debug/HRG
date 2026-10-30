"""Build source/read-scope ledgers; no reference code is executed."""
from pathlib import Path
import json,hashlib,re
from pypdf import PdfReader

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]


def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    imported=json.loads((HERE/'imported_books.json').read_text(encoding='utf-8'))
    candidates=json.loads((HERE/'library_candidates.json').read_text(encoding='utf-8'))
    for record in imported+json.loads((HERE/'huawei_books.json').read_text(encoding='utf-8')):
        if not any(x['path']==record['library_path'] for x in candidates):
            p=Path(record['library_path'])
            candidates.append(dict(path=p.as_posix(),name=p.name,bytes=p.stat().st_size,status='selected_pages_read',role='用户新增教材/讲义'))
    candidates.sort(key=lambda x:x['path'])
    (HERE/'library_candidates.json').write_text(json.dumps(candidates,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    definitions={
        'razavi_cmos':dict(title='Design of Analog CMOS Integrated Circuits, Second Edition',pages=[38,247,248,250,283,294,430,445,563,570,611],visual=[38,248,570],chapters=['2.2.3','7.2','7.8','8.1','10','13.2','14.2']),
        'razavi_converters':dict(title='Analysis and Design of Data Converters (2025)',pages=[24,25,42,56,73,93,256,257,260,308,510,515],visual=[56,257,515],chapters=['2.1','3.1.4','3.5.4','3.10','5.3','12.2','12.3','14.2','21.3']),
        'sansen_bilingual':dict(title='Analog Design Essentials bilingual rendering, filename attributes translation to deepseekv4flash',pages=[1,2,3,4,20],visual=[4,20],chapters=['1'],boundary='Machine translation aid; page4 micrometre/millimetre error visually checked; compare English original')}
    sources=[]
    for item in imported:
        p=Path(item['library_path']);definition=definitions[item['id']]
        assert sha(p)==item['sha256']
        sources.append(dict(id=item['id'],path=p.as_posix(),sha256=item['sha256'],pdf_pages=len(PdfReader(p).pages),title=definition['title'],
                            text_pages_read=definition['pages'],visual_pages_read=definition['visual'],sections=definition['chapters'],
                            boundary=definition.get('boundary','Selected pages actually read; not whole-book reading or implementation proof')))
    extra=[('sansen_english','D:/学习资料/面试笔试/模拟IC笔试面试面试题全集（部分有答案）/附赠资料/题库资料包/Analog Design Essentials (Willy Sansen).pdf',[1,2,5,6,7,18,20,116,120,153,230]),
           ('modern_analog','D:/学习资料/资料/现代模拟集成电路设计_含目录.pdf',[87,95,132,166,179,193])]
    for key,name,pages in extra:
        p=Path(name);sources.append(dict(id=key,path=p.as_posix(),sha256=sha(p),pdf_pages=len(PdfReader(p).pages),text_pages_read=pages,visual_pages_read=[],boundary='Selected pages read; textbook hand analysis, not entire-book reading'))
    for item in json.loads((HERE/'huawei_books.json').read_text(encoding='utf-8')):
        sources.append(dict(id=item['id'],path=item['library_path'],sha256=item['sha256'],pdf_pages=item['pdf_pages'],visual_pages_read=item['visual_pages_read'],text_pages_read=[],boundary=item['boundary']))
    archive_docs=json.loads((HERE/'archive_documents.json').read_text(encoding='utf-8'))
    for i,item in enumerate(archive_docs):
        if item.get('pages_read'):
            sources.append(dict(id='archive_'+str(i),path=item['library_path'],sha256=item['sha256'],pdf_pages=item['pages'],text_pages_read=item['pages_read'],visual_pages_read=[],boundary=item['status'],archive_chain=item['archive_chain']))
    ledger=dict(date='2026-10-30',sources=sources,candidate_entries=len(candidates),initial_directory_scan=220,
                newly_supplied_archives=3,archive_entries=len(archive_docs),valid_pdf_entries=sum(x.get('pages') is not None for x in archive_docs),
                unique_valid_pdf_bytes=len({x['sha256'] for x in archive_docs if x.get('pages') is not None}),
                boundary='Filename inventory, machine previews, human selected-page reading and independent derivation are distinct statuses')
    by_path={x['path']:x for x in sources}
    for candidate in candidates:
        if candidate['path'] in by_path:candidate['status']='selected_pages_read; see source ledger for exact pages'
    (HERE/'library_candidates.json').write_text(json.dumps(candidates,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    (HERE/'sources.json').write_text(json.dumps(ledger,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    lines=['# 电路资料覆盖与阅读台账','',f"初次目录扫描220条，教材/讲义新归档补入后{len(candidates)}条；新增3 ZIP另列，递归登记61条文档项，56条可解析PDF对应54个不同有效PDF字节对象。不是全部通读声明。",'',
           '## 进入本轮推导的实际选读页','','| 来源ID | 本地原文 | PDF页 | 边界 |','|---|---|---|---|']
    for x in sources:
        ns=sorted(set(x.get('text_pages_read',[])+x.get('visual_pages_read',[])))
        lines.append(f"| `{x['id']}` | [{Path(x['path']).name}](<{x['path']}>) | {','.join(map(str,ns))} | {x['boundary']} |")
    lines+=['','## 全部候选的模块入口（文件名分类，未读不升级）','','| 文件 | 模块入口 | 状态 |','|---|---|---|']
    for x in candidates:
        name=x['name'];modules=[]
        for rx,label in [(r'ADC|DAC|Converter|转换|Sigma','采样/转换/参考'),(r'噪声|Noise','噪声预算'),(r'PLL|锁相','时钟/相位环'),(r'运放|运算放大|Analog|模拟|CMOS|Razavi|拉扎维|Sansen|Gray|Allen','器件/放大/反馈'),(r'信号|离散','滤波/采样'),(r'SPICE|Spectre|Model','模型与验证')]:
            if re.search(rx,name,re.I):modules.append(label)
        role='、'.join(modules) or x['role']
        lines.append(f"| [{name.replace('|','/')}](<{x['path']}>) | {role} | {x['status']}；{x['role']} |")
    lines+=['','## 新增运放专题文档','','| 文档 | 总页数 | 阅读状态 |','|---|---:|---|']
    for x in archive_docs:
        label=Path(x['archive_chain'][-1]).name
        target=f"[{label}](<{x['library_path']}>)" if x.get('library_path') else label
        lines.append(f"| {target} | {x.get('pages','—')} | {x['status']}；已读{x.get('pages_read',[])} |")
    (HERE/'library_coverage.md').write_text('\n'.join(lines)+'\n',encoding='utf-8',newline='\n')
    print('Registered',len(sources),'selected-page sources;',len(candidates),'candidate files; archive status preserved')


if __name__=='__main__':main()
