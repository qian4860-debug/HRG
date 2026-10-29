from pathlib import Path
import hashlib,json
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
def main():
 r=json.loads((HERE/'receipt.json').read_text(encoding='utf-8'))
 p=Path(r['library'])/'data_2026-10-29_15-19-10.json'
 assert hashlib.sha256(p.read_bytes()).hexdigest()==r['original_sha256']
 data=json.loads(p.read_text(encoding='utf-8-sig'));assert len(data)==808
 s=r['zotero'];assert s['status']=='verified' and s['all_source_rows_resolved']
 assert s['existing_metadata_preserved'] and s['source_bytes_preserved']
 assert s['unique_target_items']==805
 work=ROOT/'HRG_WA_simulink/layered/_work/scholar_151910'
 mapping=json.loads((work/'resolved.json').read_text(encoding='utf-8'))
 assert {x['source_id'] for x in mapping}=={str(x['id'])+'__row_'+str(n) for n,x in enumerate(data,1)}
 assert len({x['key'] for x in mapping})==805
 print('PASS: original bytes preserved; 808 rows resolved to 805 Zotero entries; no PDF acquisition claimed')
if __name__=='__main__':main()
