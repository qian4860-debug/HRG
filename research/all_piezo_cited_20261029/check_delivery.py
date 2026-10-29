from pathlib import Path
import json,hashlib
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
def main():
 p=json.loads((HERE/'parents.json').read_text(encoding='utf-8'))
 e=json.loads((HERE/'selected_edges.json').read_text(encoding='utf-8'))
 c=json.loads((HERE/'coverage.json').read_text(encoding='utf-8'))
 s=json.loads((HERE/'summary.json').read_text(encoding='utf-8'))
 assert p['scanned_pdf_objects']==len(c['files'])==242
 assert len(p['parents'])==47 and sum(len(x['reference']) for x in p['parents'])==1371
 assert len(e)==564 and len({(x['parent_doi'],x['index']) for x in e})==564
 assert s['status']=='verified' and s['all_source_rows_resolved'] and s['existing_metadata_preserved']
 w=ROOT/'HRG_WA_simulink/layered/_work/all_piezo_cited';r=json.loads((w/'references.json').read_text(encoding='utf-8'))
 m=json.loads((w/'resolved.json').read_text(encoding='utf-8'))
 assert len(r)==len(m)==564 and {x['id'] for x in r}=={x['source_id'] for x in m}
 assert len({x['key'] for x in m})==s['unique_target_items']==377
 assert hashlib.sha256((w/'references.json').read_bytes()).hexdigest()==s['source_sha256']
 lib=Path('D:/学习资料/资料/全角陀螺/压电全角引文扩展_20261029')
 assert (lib/'references.json').read_bytes()==(w/'references.json').read_bytes()
 assert json.loads((lib/'summary.json').read_text(encoding='utf-8'))==s
 print('PASS: 242 PDF objects; 47 matched parents; 564 candidate citation edges mapped to 377 Zotero entries')
if __name__=='__main__':main()
