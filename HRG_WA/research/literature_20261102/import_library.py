"""Add non-destructive local copies/indexes; raw PDFs are never GitHub payloads."""
from pathlib import Path
import argparse,hashlib,json,shutil
HERE=Path(__file__).resolve().parent
LIB=Path('D:/学习资料/资料/全角陀螺');SKILL=Path('C:/Users/11725/.codex/skills/ic-reference-library/references')
def corehash(p):
    b=p.read_bytes();n=b.rfind(b'%%EOF');return hashlib.sha256(b[:n+5] if n>=0 else b).hexdigest()
DIRECT={'N09','N10','N11','N13','N15','N16','N17','N18','N19'}
BACKGROUND={'N05','N07','N08'}
READ={'N01':[1,6],'N02':[1,6],'N03':[1,9,10],'N04':[1,2],'N05':[1],'N06':[1,2,3],'N07':[1],'N08':[1],'N09':[1,2,5],'N10':[1,2,10],'N11':[1,4,5],'N12':[1,7],'N13':[1,5],'N14':[1,2],'N15':[1,5],'N16':[1,6],'N17':[3,5,6,7,8,67,72],'N18':[4,5,9,10,154,155,156,157,158,159,160,161,162,163,174,175,177],'N19':[4,5,9,10,11]}
READ.update(N01=[1],N02=[1],N06=[1],N09=[1],N13=[1])
def main():
    a=argparse.ArgumentParser();a.add_argument('--write',action='store_true');args=a.parse_args()
    rows=json.loads((HERE/'sources.json').read_text(encoding='utf-8'));known={}
    for p in sorted(LIB.rglob('*.pdf')):
        try:known.setdefault(corehash(p),p)
        except OSError:pass
    copied=0;receipts=[]
    for r in rows:
        src=Path(r['path']);h=corehash(src);ident=r['id'];group='HRG直接相关' if ident in DIRECT else '系统背景_非HRG本体' if ident in BACKGROUND else '可迁移标定温补方法'
        existing=known.get(h);target=existing or LIB/'新增文献_20261102'/group/src.name
        if not existing:
            if args.write:target.parent.mkdir(parents=True,exist_ok=True);assert not target.exists();shutil.copy2(src,target)
            known[h]=target;copied+=1
        rec={k:v for k,v in r.items() if k!='metadata'}
        rec.update(group=group,pdf_core_sha256=h,archive_path=str(target),action='reused_core_equivalent' if existing else 'copied_original',reviewed_pdf_pages=READ[ident],read_scope='selected-page review, not full formula verification')
        if ident=='N10':rec.update(pages=10,read_scope='Poppler visual pages 1,2,10; Python text extraction failed; original unchanged')
        if ident in {'N04','N14'}:rec['read_scope']='scan: visual pages 1,2; no machine-readable main text; same PDF core, distinct trailing bytes'
        if ident=='N17':rec['read_scope']='English abstract and selected text; Chinese font map corrupt; visual PDF67/72 verified'
        if ident=='N11':rec['content_boundary']='PDF5 is an unrelated appended paper; HRG conclusions on PDF4'
        if ident=='N03':rec['content_boundary']='PDF1-9 main article; PDF10 mixes unrelated HRG nonlinear-detection references and continuation of main article references; not a complete additional paper'
        receipts.append(rec)
    out=dict(date='2026-11-02',input_count=19,unique_pdf_core_count=len({r['pdf_core_sha256'] for r in receipts}),new_copies=copied,records=receipts,
             dedup_rule='SHA256 of original bytes through final %%EOF; acquisition tail may differ. Originals and both raw hashes retained; not a claim of generic semantic dedup.')
    (HERE/'library_receipt.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    if args.write:
        (SKILL/'hrg-additions-20261102.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
        text='# 2026-11-02 HRG与标定补充\n\n19个输入、18个PDF主体；原文件不改写，重复的线振动台论文复用单一归档路径。机器提取不代表逐式核验。\n\n[逐篇路径、哈希、实际阅读页码与边界](hrg-additions-20261102.json)。项目分析：C:/Users/11725/Desktop/HRG_WA/research/literature_20261102/文献融入与五个创新候选.md。\n\nN17为电容式全角、含阻尼/频裂前馈及Luenberger噪声抑制；N18为平板电极速率积分、含增益/相位/阻尼分步辨识。不得将已有方法称为本项目原创。N16静电检测加速度模型不能直接移植为压电参数。N11第5页为拼接的其他文章。N10仅视觉选页，Python正文解析失败；N04/N14为扫描件；N17中文文本乱码，已视觉核对PDF67/72。\n'
        (SKILL/'hrg-additions-20261102.md').write_text(text,encoding='utf-8',newline='\n')
        topic=SKILL/'hrg-whole-angle.md';raw=topic.read_text(encoding='utf-8');link='hrg-additions-20261102.md'
        if link not in raw:topic.write_text(raw+'\n\n## 2026-11-02补充文献与创新边界\n\n[本次补充登记]('+link+')；19输入按主体去重18份，分HRG直接相关、可迁移方法和系统背景。实际选读页码与解析限制单列。\n',encoding='utf-8',newline='\n')
    print('Input',19,'unique cores',out['unique_pdf_core_count'],'new copies',copied,'write',args.write)
if __name__=='__main__':main()
