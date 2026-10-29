"""Verify reference occurrence coverage, Zotero targets and local archive receipt."""
from pathlib import Path
import json,hashlib
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
def main():
 graph=json.loads((HERE/'citation_edges.json').read_text(encoding='utf-8'))
 summary=json.loads((HERE/'summary.json').read_text(encoding='utf-8'))
 assert len(graph['edges'])==161 and not graph['errors']
 assert len({e['parent_doi'] for e in graph['edges']})==6
 assert summary['status']=='verified' and summary['all_source_rows_resolved']
 assert summary['existing_metadata_preserved'] and summary['source_bytes_preserved']
 work=ROOT/'HRG_WA_simulink/layered/_work/v10_cited'
 source=work/'references.json';rows=json.loads(source.read_text(encoding='utf-8'))
 assert hashlib.sha256(source.read_bytes()).hexdigest()==summary['source_sha256']
 resolved=json.loads((work/'resolved.json').read_text(encoding='utf-8'))
 assert {r['id'] for r in rows}=={r['source_id'] for r in resolved}
 assert len(rows)==len(resolved)==161
 assert len({r['key'] for r in resolved})==summary['unique_target_items']==132
 library=Path('D:/学习资料/资料/全角陀螺/V10引用文献_20261029')
 assert (library/'references.json').read_bytes()==source.read_bytes()
 assert json.loads((library/'summary.json').read_text(encoding='utf-8'))==summary
 print('PASS: six parents; 161 citation occurrences; 132 verified Zotero target entries; local bibliography archive matches')
if __name__=='__main__':main()
