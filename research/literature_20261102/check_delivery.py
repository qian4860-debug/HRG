from pathlib import Path
import argparse,hashlib,json
HERE=Path(__file__).resolve().parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def check():
    r=json.loads((HERE/'library_receipt.json').read_text(encoding='utf-8'));assert r['input_count']==19 and r['unique_pdf_core_count']==18
    assert len(r['records'])==19 and len({v['pdf_core_sha256'] for v in r['records']})==18
    for v in r['records']:
        p=Path(v['path']);a=Path(v['archive_path']);assert sha(p)==v['sha256'],v['id'];b=a.read_bytes();n=b.rfind(b'%%EOF');assert hashlib.sha256(b[:n+5] if n>=0 else b).hexdigest()==v['pdf_core_sha256']
        assert v['reviewed_pdf_pages'] and v['read_scope']!='full formula verification'
    # 两个不同下载尾部的同主体文件必须映射到同一归档路径。
    x={v['id']:v for v in r['records']};assert x['N04']['archive_path']==x['N14']['archive_path'];assert 'unrelated' in x['N11']['content_boundary']
    assert [sum(v['group']==g for v in r['records'] if v['id']!='N14') for g in ['HRG直接相关','可迁移标定温补方法','系统背景_非HRG本体']]==[9,6,3]
    private=Path('C:/Users/11725/.codex/skills/ic-reference-library/references/hrg-additions-20261102.json');assert private.read_bytes()==(HERE/'library_receipt.json').read_bytes()
    doc=(HERE/'文献融入与五个创新候选.md').read_text(encoding='utf-8');assert sum(('### 候选'+str(i)+'：') in doc for i in range(1,6))==5
def snapshot():
    return {p.name:sha(p) for p in sorted(HERE.iterdir()) if p.is_file() and p.suffix in {'.py','.json','.md'} and p.name!='manifest.json'}
def main():
    a=argparse.ArgumentParser();a.add_argument('--seal',action='store_true');args=a.parse_args();check()
    if args.seal:(HERE/'manifest.json').write_text(json.dumps({'date':'2026-11-02','files':snapshot(),'scope':'Selected-page literature review and five unproven innovation candidates; no model accuracy upgrade'},ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    assert snapshot()==json.loads((HERE/'manifest.json').read_text(encoding='utf-8'))['files'];print('PASS: 19 originals, 18 archived PDF cores, 9/6/3 classification, private index identity, five candidates and sealed review')
if __name__=='__main__':main()
