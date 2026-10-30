"""Reproducible fifth-book assembly; never overwrite accepted earlier books."""
from pathlib import Path
import hashlib
import json
import re

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
BOOK=ROOT/'压电全角验证总书第五版_三篇经典文献贯通.md'
PRIOR=ROOT/'压电全角验证总书第四版_经典文献逐式演算.md'


def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()


def content():
    chapters=sorted((HERE/'chapters').glob('*.md'))
    old=PRIOR.read_text(encoding='utf-8').split('## 先学会区分四种对象',1)[1]
    old='## 先学会区分四种对象'+old
    old=old.replace('这个小节依据已经审读的Lynch平均法，不冒充尚未取得的Ragot 2011逐式复现。','这个小节保留第四版的Lynch平均法推演；本版第二编另按新取得的Ragot 2011全文进行逐式核查。')
    old=old.split('本卷已完整覆盖所提供九页平均法文稿的46组编号公式。图片中其余经典文献')[0]
    parts=[chapters[0].read_text(encoding='utf-8'),old]+[p.read_text(encoding='utf-8') for p in chapters[1:]]+[(HERE/'worked_steps.md').read_text(encoding='utf-8')]
    return '\n\n---\n\n'.join(parts)+'\n',chapters


def main():
    text,chapters=content()
    assert text.count(r'\[')==text.count(r'\]')
    BOOK.write_text(text,encoding='utf-8',newline='\n')
    mapping=[]
    def rpage(n):return 1 if n<=2 else 2 if n<=6 else 3 if n<=11 else 4 if n<=17 else 5 if n<=24 else 6 if n<=29 else 7 if n<=31 else 10
    for p in chapters:
        s=p.read_text(encoding='utf-8')
        for m in re.finditer(r'<a id="([RJZ])(\d{2})"></a>',s):
            kind,n=m[1],int(m[2]);page=rpage(n) if kind=='R' else (1 if n==1 else 2 if n<=7 else 3) if kind=='J' else None
            mapping.append(dict(source={'R':'ragot2011','J':'jeanroy2014','Z':'rozelle2009'}[kind],original_equation=n if kind!='Z' else None,
                                author_numbered=kind!='Z',book_node=f'{kind}{n:02}',pdf_page=page,chapter=p.relative_to(ROOT).as_posix(),heading=s[m.end():].lstrip().splitlines()[0]))
    (HERE/'equation_map.json').write_text(json.dumps(mapping,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    # Reading evidence is a tracked input. A clean checkout does not need the
    # ignored extraction/render cache to reconstruct the book or equation map.
    ledger=json.loads((HERE/'sources.json').read_text(encoding='utf-8'))
    assert len(ledger['sources'])==3
    for item in ledger['sources']:
        if Path(item['path']).exists():assert sha(Path(item['path']))==item['sha256']
    prior=json.loads((ROOT/'research/classics_20261030/manifest.json').read_text(encoding='utf-8'))
    preserved=dict(prior['files']);preserved.update(prior['preserved_previous_files'])
    files=chapters+[p for p in HERE.iterdir() if p.is_file() and p.name!='manifest.json' and p.suffix in {'.md','.py','.m','.csv','.json'}]+[BOOK]
    manifest=dict(book=BOOK.relative_to(ROOT).as_posix(),files={p.relative_to(ROOT).as_posix():sha(p) for p in sorted(set(files))},preserved_previous_files=preserved,
                  counts=dict(lynch_retained=46,ragot_printed=32,jeanroy_printed=9,rozelle_book_nodes=8,new_python_checks=38,new_matlab_checks=9,trace_nodes=66))
    (HERE/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    print('Built fifth book:',len(text.splitlines()),'lines;',len(mapping),'new mapped groups/nodes')


if __name__=='__main__':main()
