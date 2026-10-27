"""Read the three user references; keep full extracted text in ignored work area."""
from pathlib import Path
import hashlib,json,re,zipfile
from lxml import etree
from pypdf import PdfReader

ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parents[1]
WORK=ROOT/'HRG_WA_simulink/layered/_work/book_v2_sources'
SOURCES=[
 ('T05',Path('D:/学习资料/资料/全角陀螺/邰涵翛-开题v0.5.docx')),
 ('P59',Path('C:/Users/11725/xwechat_files/wxid_qvgyt57csh8y22_a935/msg/file/2026-10/开题报告(1).pdf')),
 ('D153',Path('C:/Users/11725/xwechat_files/wxid_qvgyt57csh8y22_a935/msg/file/2026-10/MEMS硅陀螺数字闭环接口ASIC技术研究.pdf'))]
NS={'w':'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
    'm':'http://schemas.openxmlformats.org/officeDocument/2006/math',
    'v':'urn:schemas-microsoft-com:vml','o':'urn:schemas-microsoft-com:office:office',
    'r':'http://schemas.openxmlformats.org/officeDocument/2006/relationships'}
def tag(n):return etree.QName(n).localname
def mathtext(n):
    t=tag(n); cs=list(n)
    if t=='t':return n.text or ''
    def child(k):
        v=n.find('m:'+k,NS)
        return mathtext(v) if v is not None else ''
    if t.endswith('Pr'):return ''
    if t=='f':return '('+child('num')+')/('+child('den')+')'
    if t=='sSup':return '('+child('e')+')^('+child('sup')+')'
    if t=='sSub':return '('+child('e')+')_('+child('sub')+')'
    if t=='sSubSup':return '('+child('e')+')_('+child('sub')+')^('+child('sup')+')'
    if t=='rad':return 'root['+child('deg')+']('+child('e')+')'
    if t=='m':return '['+'; '.join(mathtext(x) for x in cs if tag(x)=='mr')+']'
    if t=='mr':return ', '.join(mathtext(x) for x in cs if tag(x)=='e')
    if t=='nary':
        p=n.find('m:naryPr/m:chr',NS);symbol=p.get('{'+NS['m']+'}val','∫') if p is not None else '∫'
        return symbol+'['+child('sub')+','+child('sup')+'] '+child('e')
    if t=='acc':return 'accent('+child('e')+')'
    return ''.join(mathtext(x) for x in cs)

def main():
    WORK.mkdir(parents=True,exist_ok=True);records=[]
    for sid,path in SOURCES:
        raw=path.read_bytes();record=dict(id=sid,path=path.as_posix(),sha256=hashlib.sha256(raw).hexdigest(),bytes=len(raw))
        if path.suffix=='.pdf':
            reader=PdfReader(path);texts=[]
            for k,page in enumerate(reader.pages,1):texts.append(f'\n===== PDF PAGE {k} =====\n'+(page.extract_text() or ''))
            record['pages']=len(reader.pages)
            (WORK/(sid+'.txt')).write_text(''.join(texts),encoding='utf-8',newline='\n')
        else:
            with zipfile.ZipFile(path) as z:
                root=etree.fromstring(z.read('word/document.xml'))
                relroot=etree.fromstring(z.read('word/_rels/document.xml.rels'))
                rels={x.get('Id'):x.get('Target') for x in relroot}
                lines=[];paras=[];lastpage=1
                for k,p in enumerate(root.findall('.//w:body//w:p',NS),1):
                    # Top-level math objects are emitted once, never flattened into missing symbols.
                    parts=[]
                    for n in p.iter():
                        if tag(n)=='oMath':parts.append(' MATH{'+mathtext(n)+'} ')
                        elif tag(n)=='t' and n.tag.startswith('{'+NS['w']+'}') and not any(tag(a)=='oMath' for a in n.iterancestors()):parts.append(n.text or '')
                    text=''.join(parts)
                    objects=p.findall('.//w:object',NS)
                    if objects:
                        text+=' OBJECTS{'+','.join(x.get('{'+NS['r']+'}id','') for x in p.findall('.//v:imagedata',NS))+'}'
                    if text.strip():
                        lines.append(f'P{k:04} [cached page~{lastpage}] '+text)
                        paras.append(dict(paragraph=k,cached_page=lastpage,text=text))
                    lastpage+=len(p.findall('.//w:lastRenderedPageBreak',NS))
                record.update(paragraphs=len(root.findall('.//w:body//w:p',NS)),omml=len(root.findall('.//m:oMath',NS)),ole=len(root.findall('.//o:OLEObject',NS)),cached_pages=lastpage)
                (WORK/(sid+'.txt')).write_text('\n'.join(lines),encoding='utf-8',newline='\n')
                (WORK/(sid+'_paragraphs.json')).write_text(json.dumps(paras,ensure_ascii=False,indent=2),encoding='utf-8',newline='\n')
                # Keep local XML and image fallback references for visual checks, not in public Git.
                (WORK/'T05_document.xml').write_bytes(z.read('word/document.xml'))
                (WORK/'T05_relationships.json').write_text(json.dumps(rels,ensure_ascii=False,indent=2),encoding='utf-8')
                for name in z.namelist():
                    if name.startswith('word/media/'):
                        dest=WORK/'T05_media'/Path(name).name;dest.parent.mkdir(exist_ok=True);dest.write_bytes(z.read(name))
        records.append(record)
    HERE.mkdir(parents=True,exist_ok=True)
    (HERE/'sources.json').write_text(json.dumps(dict(date='2026-10-27',sources=records,reading='Extraction only; reviewed locations tracked separately'),ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    print(json.dumps(records,ensure_ascii=False,indent=2))

if __name__=='__main__':main()
