"""Read local Zotero PDF files without touching its live database or permissions.

Full extracted text stays in ignored work files. The private library inventory
belongs in ic-reference-library; project evidence includes only HRG sources.
"""
from pathlib import Path
import hashlib
import json
import sys
import acquire_wa_citations as identity

ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'HRG_WA_simulink/layered/_work/zotero_bridge'
STORAGE=Path('C:/Users/11725/Zotero/storage')
HEAD=Path('D:/学习资料/资料/全角陀螺')

def main():
    WORK.mkdir(parents=True,exist_ok=True)
    byhash={}
    for p in sorted(HEAD.rglob('*.pdf')):
        byhash.setdefault(hashlib.sha256(p.read_bytes()).hexdigest(),[]).append(p.as_posix())
    records=[]
    for p in sorted(STORAGE.rglob('*.pdf')):
        h=hashlib.sha256(p.read_bytes()).hexdigest()
        rec=dict(attachment_key=p.parent.name,path=p.as_posix(),filename=p.name,sha256=h,
                 same_bytes_in_head_folder=byhash.get(h,[]),reading_level='extracted_not_yet_reviewed')
        try:
            count,pages,parser=identity.pdf_pages(p)
            text='\n'.join(f'\n@@PDFPAGE:{n}@@\n'+t for n,t in pages)
            (WORK/(p.parent.name+'.txt')).write_text(text,encoding='utf-8',newline='\n')
            rec.update(pages=count,parser=parser,characters=len(text),first_page_dois=identity.dois(pages[0][1]),
                       extracted_pdf_pages=[n for n,t in pages])
        except Exception as ex:rec['extraction_error']=str(ex)
        records.append(rec)
        print(p.parent.name,rec.get('pages'),bool(rec['same_bytes_in_head_folder']),flush=True)
    identity.save(WORK/'pdf_inventory.json',dict(date='2026-10-24',records=records,
           boundary='Local attachment files only; current parent-item and collection metadata require the official Local API'))
    print(json.dumps(dict(pdf_files=len(records),unique_hashes=len({x['sha256'] for x in records}),
          distinct_from_head_folder=sum(not x['same_bytes_in_head_folder'] for x in records)),ensure_ascii=True))

if __name__=='__main__':main()
