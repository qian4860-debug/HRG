"""Verify row coverage, source bytes, attachment identities and formula receipts."""
from pathlib import Path
import hashlib,json

ROOT=Path(__file__).resolve().parents[2];OUT=Path(__file__).resolve().parent
def main():
    manifest=json.loads((OUT/'manifest.json').read_text(encoding='utf-8'))
    source=Path('C:/Users/11725/Downloads/data_2026-10-29_12-24-02.json')
    assert hashlib.sha256(source.read_bytes()).hexdigest()==manifest['source_sha256']
    original=ROOT/'HRG_WA_simulink/layered/_work/scholar_piezo_20261029/source_original.json'
    assert hashlib.sha256(original.read_bytes()).hexdigest()==manifest['source_sha256']
    review=json.loads((OUT/'relevance_review.json').read_text(encoding='utf-8'))
    assert len(review['records'])==len(manifest['records'])==203
    assert len({r['source_id'] for r in review['records']})==203
    assert [r['source_id'] for r in review['records']]==[r['source_id'] for r in manifest['records']]
    held=[]
    for r in manifest['records']:
        if r.get('path'):
            p=Path(r['path']);assert hashlib.sha256(p.read_bytes()).hexdigest()==r['sha256'];held.append(r)
    assert not manifest['records'][9].get('path')
    assert not manifest['records'][173].get('path')
    assert len(held)==34
    assert manifest['counts']=={'existing_fulltext':18,'not_obtained':169,'downloaded_fulltext':16}
    f=json.loads((OUT/'formula_checks.json').read_text(encoding='utf-8'))
    assert f['all_passed'] and len(f['checks'])==19
    note=json.loads((OUT/'review_note_receipt.json').read_text(encoding='utf-8'))
    assert note['all_parent_notes_verified'] and note['unique_parent_entries']==202
    attach=json.loads((OUT/'attachment_receipt.json').read_text(encoding='utf-8'))
    assert attach['verified_parent_hash_pairs']==34 and attach['all_paths_accessible']
    table=(OUT/'逐条相关性.md').read_text(encoding='utf-8')
    assert sum(line.startswith('| S') for line in table.splitlines())==203
    assert not list(OUT.rglob('*.pdf'))
    print('PASS: 203 source rows; 34 hash-verified PDFs; 202 Zotero review notes; 19 formula checks')

if __name__=='__main__':main()
