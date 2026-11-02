"""Refresh review notes without re-copying archives or rewriting import history."""
from pathlib import Path
import json
from import_library import HERE,READ,SKILL
def main():
    path=HERE/'library_receipt.json';r=json.loads(path.read_text(encoding='utf-8'))
    for v in r['records']:
        v['reviewed_pdf_pages']=READ[v['id']]
        if v['id']=='N03':v['content_boundary']='PDF1-9 main article; PDF10 mixes references of an unrelated HRG nonlinear-detection paper with the continuation of the main article references; not an additional full paper'
    text=json.dumps(r,ensure_ascii=False,indent=2)+'\n';path.write_text(text,encoding='utf-8',newline='\n')
    (SKILL/'hrg-additions-20261102.json').write_text(text,encoding='utf-8',newline='\n')
if __name__=='__main__':main()
