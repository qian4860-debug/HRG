"""Preserve and import the user-supplied multi-query bibliography without losing rows."""
from pathlib import Path
import json,sys,hashlib
import import_zotero_bibliography as imp
from zotero_wa_bridge import LocalAPI
class BatchAPI(LocalAPI):
 def request(self,path,method='GET',data=None,authorize=True,timeout=180):
  return super().request(path,method,data,authorize,timeout)
 def authorize(self):
  result=self.request('/api/local/authorize','POST',{'appName':'HRG_WA 本地文献归档'},authorize=False,timeout=3600)
  self.key=result['key']
  print('Zotero archive authorization received',flush=True)
ROOT=Path(__file__).resolve().parents[1]
def main():
 source=Path('C:/Users/11725/Downloads/data_2026-10-29_15-19-10.json')
 work=ROOT/'HRG_WA_simulink/layered/_work/scholar_151910';work.mkdir(parents=True,exist_ok=True)
 raw=source.read_bytes();rows=json.loads(raw);h=hashlib.sha256(raw).hexdigest()
 (work/'original.json').write_bytes(raw)
 prepared=[]
 for n,r in enumerate(rows,1):
  d=dict(r);d['id']=str(r['id'])+'__row_'+str(n);prepared.append(d)
 src=work/'row_preserving_import.json';imp.save(src,prepared)
 imp.WORK=work;imp.PUBLIC=ROOT/'research/scholar_151910_20261029';imp.BATCH='Scholar多关键词_20261029_151910';imp.DATE='2026-10-29'
 imp.LocalAPI=BatchAPI
 sys.argv=[sys.argv[0],str(src),'--apply'];imp.main()
 library=Path('D:/学习资料/资料/全角陀螺/Scholar多关键词_20261029_151910');library.mkdir(parents=True,exist_ok=True)
 (library/source.name).write_bytes(raw)
 receipt=dict(original_sha256=h,source_rows=len(rows),unique_source_ids=len({r['id'] for r in rows}),
  library=str(library),scope='Bibliographic JSON and URLs only; not PDF full-text acquisition',
  zotero=json.loads((imp.PUBLIC/'summary.json').read_text(encoding='utf-8')))
 imp.save(imp.PUBLIC/'receipt.json',receipt);imp.save(library/'receipt.json',receipt)
 skill=Path('C:/Users/11725/.codex/skills/ic-reference-library/references')
 imp.save(skill/'scholar-151910-20261029.json',receipt)
 route=skill/'hrg-whole-angle.md';t=route.read_text(encoding='utf-8');marker='## 多关键词题录151910（2026-10-29）'
 if marker not in t:route.write_text(t+'\n\n'+marker+'\n\n[导入登记](scholar-151910-20261029.json)。题录入库不代表全文已取得或已读；含跨查询重复与无关命中，未据关键词自动判定相关。\n',encoding='utf-8')
 assert source.read_bytes()==raw
 print(json.dumps(receipt,ensure_ascii=True),flush=True)
if __name__=='__main__':main()
