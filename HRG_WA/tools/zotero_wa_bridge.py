"""Plan and apply a local Zotero 10 collection import through its official API.

No live SQLite writes, preference edits, existing-key scraping or cloud API.
The complete Zotero inventory stays local and is not a GitHub deliverable.
Original source files are linked in place. Existing memberships are preserved.
"""
from pathlib import Path
from collections import Counter
import argparse
import hashlib
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'HRG_WA_simulink/layered/_work/zotero_bridge'
PUBLIC=ROOT/'research/zotero_integration_20261024'
HEAD=Path('D:/学习资料/资料/全角陀螺')
SKILL=Path('C:/Users/11725/.codex/skills/ic-reference-library')
DATA=Path('C:/Users/11725/Zotero')
PAPER_EXT={'.pdf','.caj','.nh','.kdh','.djvu'}

def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def save(p,v):
    p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def normalized_doi(x):return str(x or '').strip().lower().removeprefix('https://doi.org/').removeprefix('http://doi.org/')

class LocalAPI:
    def __init__(self):
        self.opener=urllib.request.build_opener(urllib.request.ProxyHandler({}))
        self.server=None;self.key=None
    def request(self,path,method='GET',data=None,authorize=True,timeout=30):
        assert path.startswith('/api/')
        headers={'Zotero-API-Version':'3'}
        if self.server:headers['Zotero-Server-ID']=self.server
        if method!='GET' and authorize:
            if not self.key:self.authorize()
            headers['Zotero-API-Key']=self.key
        body=None if data is None else json.dumps(data,ensure_ascii=False).encode('utf-8')
        if body is not None:headers['Content-Type']='application/json'
        request=urllib.request.Request('http://127.0.0.1:23119'+path,data=body,headers=headers,method=method)
        with self.opener.open(request,timeout=timeout) as response:
            server=response.headers.get('Zotero-Server-ID')
            if self.server and server and self.server!=server:raise RuntimeError('Zotero instance changed; stop and rebuild the plan')
            self.server=server or self.server
            raw=response.read();kind=response.headers.get('Content-Type','')
            return json.loads(raw) if 'json' in kind and raw else raw.decode('utf-8')
    def authorize(self):
        result=self.request('/api/local/authorize','POST',{'appName':'HRG_WA 本地文献归档'},authorize=False,timeout=300)
        self.key=result['key'] # Memory only: never serialize or print this key.
        print('Zotero application authorization granted; remembered:',bool(result.get('remember')),flush=True)
    def write_many(self,path,objects):
        output=[]
        for start in range(0,len(objects),50):
            batch=objects[start:start+50]
            try:result=self.request(path,'POST',batch)
            except urllib.error.HTTPError as error:
                if error.code!=401:raise
                self.key=None;result=self.request(path,'POST',batch)
            if result.get('failed'):
                # Preserve partial successes; a new plan reconciles actual keys.
                save(WORK/'last_write_result.json',result)
                raise RuntimeError('Partial Zotero API write failure; result retained locally, rebuild plan before retry')
            output.extend(result.get('successful',{}).values())
        return output

def source_files():
    grouped={}
    for p in sorted(HEAD.rglob('*')):
        if p.is_file() and p.suffix.lower() in PAPER_EXT:
            grouped.setdefault(sha(p),[]).append(p)
    return [dict(sha256=h,path=paths[0].as_posix(),other_paths=[p.as_posix() for p in paths[1:]],
        title=paths[0].stem.replace('_',' '),relative=paths[0].relative_to(HEAD).as_posix()) for h,paths in grouped.items()]

def attachment_path(item):
    d=item['data'];key=item['key']
    if d.get('linkMode')=='linked_file':
        p=d.get('path','')
        if p.startswith('attachments:'):return None # A relative base directory needs explicit API resolution.
        return Path(p) if p else None
    if d.get('linkMode') in ('imported_file','imported_url') and d.get('filename'):
        return DATA/'storage'/key/d['filename']
    return None

def inventory(api):
    api.request('/api/')
    collections=api.request('/api/users/0/collections')
    items=api.request('/api/users/0/items?includeTrashed=0')
    files=[]
    for item in items:
        if item['data'].get('itemType')!='attachment':continue
        p=attachment_path(item)
        if p and p.is_file():files.append(dict(key=item['key'],parent=item['data'].get('parentItem'),path=p.as_posix(),sha256=sha(p)))
    result=dict(server=api.server,collections=collections,items=items,files=files)
    save(WORK/'live_inventory.json',result)
    return result

def plan():
    sources=source_files();save(WORK/'source_plan.json',sources)
    api=LocalAPI()
    try:current=inventory(api)
    except urllib.error.HTTPError as error:
        if error.code!=403:raise
        summary=dict(status='waiting_for_local_api_enable',source_unique_files=len(sources),source_paths=sum(1+len(x['other_paths']) for x in sources),
             setting='Zotero Settings > Advanced > Allow other applications on this computer to communicate with Zotero',
             boundary='No Zotero collection or item has been changed')
        save(PUBLIC/'summary.json',summary);print(json.dumps(summary,ensure_ascii=True));return
    byhash={x['sha256']:x for x in current['files']}
    root=[x for x in current['collections'] if x['data']['name'].strip()=='全角陀螺' and not x['data'].get('parentCollection')]
    if len(root)>1:raise RuntimeError('Multiple top-level 全角陀螺 collections; select one explicitly before importing')
    result=dict(server=current['server'],root_collection=root[0]['key'] if root else None,
                source_files=sources,reuse_files=[x for x in sources if x['sha256'] in byhash],
                create_files=[x for x in sources if x['sha256'] not in byhash],
                collection_policy='Every imported/reused source belongs to 全角陀螺; existing memberships preserved',
                attachment_policy='linked_file; original local files remain the canonical bytes')
    save(WORK/'import_plan.json',result)
    summary=dict(status='concrete_plan_ready',source_unique_files=len(sources),source_paths=sum(1+len(x['other_paths']) for x in sources),
        zotero_items=len(current['items']),zotero_file_attachments=len(current['files']),
        reused_files=len(result['reuse_files']),new_linked_files=len(result['create_files']),
        root_collection_exists=bool(root),boundary='Plan only; no Zotero writes')
    save(PUBLIC/'summary.json',summary);print(json.dumps(summary,ensure_ascii=True))

def index(current):
    # All bibliographic metadata remains in the local skill repository.
    records=[];bykey={x['key']:x for x in current['files']}
    for item in current['items']:
        d=item['data'];r={k:d[k] for k in ('itemType','title','DOI','date','creators','collections','parentItem','tags') if k in d}
        r.update(key=item['key'],version=item['version'])
        if item['key'] in bykey:r['local_file']=bykey[item['key']]
        records.append(r)
    save(SKILL/'references/zotero-library-20261024.json',dict(date='2026-10-24',server=current['server'],
        records=records,collections=current['collections'],boundary='Metadata and paths, not full scientific reading'))
    text=('# Zotero本地资料库\n\n2026-10-24通过官方只读Local API登记'+str(len(records))+'条目、'
       +str(len(current['files']))+'个可访问文件附件。完整题录/分类/路径见[zotero-library-20261024.json](zotero-library-20261024.json)。'
       '题录收录与PDF全文提取不代表逐式阅读。私人题录索引仅在本技能本地Git，不上传HRG公共仓库。\n')
    (SKILL/'references/zotero-library-20261024.md').write_text(text,encoding='utf-8',newline='\n')

def apply():
    requested=read(WORK/'import_plan.json');api=LocalAPI();current=inventory(api)
    if current['server']!=requested['server']:raise RuntimeError('Different Zotero database; rebuild plan')
    # Reconcile live files, including additions since the preview, before any write.
    byhash={x['sha256']:x for x in current['files']};bykey={x['key']:x for x in current['items']}
    for f in requested['source_files']:
        if sha(Path(f['path']))!=f['sha256']:raise RuntimeError('Source changed; rebuild plan')
    root=[x for x in current['collections'] if x['data']['name'].strip()=='全角陀螺' and not x['data'].get('parentCollection')]
    if len(root)>1:raise RuntimeError('Ambiguous target collection')
    if not root:
        made=api.write_many('/api/users/0/collections',[{'name':'全角陀螺','parentCollection':False}])
        collection=made[0]['key']
    else:collection=root[0]['key']
    updates={};create=[]
    for f in requested['source_files']:
        held=byhash.get(f['sha256'])
        if held:
            key=held.get('parent') or held['key'];item=bykey[key];d=item['data']
            groups=list(d.get('collections',[]))
            if collection not in groups:updates[key]={'key':key,'version':item['version'],'collections':groups+[collection]}
        else:
            create.append({'itemType':'attachment','linkMode':'linked_file','path':str(Path(f['path'])),
                'title':f['title'],'contentType':'application/pdf' if Path(f['path']).suffix.lower()=='.pdf' else 'application/octet-stream',
                'collections':[collection],'tags':[{'tag':'HRG_WA_本地全文'},{'tag':'题录待校对'}]})
    if updates:api.write_many('/api/users/0/items',list(updates.values()))
    # A one-file pilot validates the installed client's linked-file support.
    if create:
        pilot=api.write_many('/api/users/0/items',create[:1]);key=pilot[0]['key']
        check=api.request('/api/users/0/items/'+key);p=attachment_path(check)
        if not p or not p.is_file() or sha(p)!=sha(Path(create[0]['path'])):raise RuntimeError('Linked-file pilot did not preserve accessible bytes')
        if len(create)>1:api.write_many('/api/users/0/items',create[1:])
    final=inventory(api);index(final)
    byhash={x['sha256']:x for x in final['files']};allitems={x['key']:x for x in final['items']}
    for f in requested['source_files']:
        assert f['sha256'] in byhash
        held=byhash[f['sha256']];item=allitems[held.get('parent') or held['key']]
        assert collection in item['data'].get('collections',[])
    summary=dict(status='verified',source_unique_files=len(requested['source_files']),
        new_linked_files=len(create),existing_memberships_extended=len(updates),
        all_source_files_accessible_in_target=True,source_hashes_preserved=True,
        private_zotero_items_indexed=len(final['items']),private_file_attachments_indexed=len(final['files']),
        boundary='File/collection verification, not automatic scientific reading or bibliographic equivalence')
    save(PUBLIC/'summary.json',summary);print(json.dumps(summary,ensure_ascii=True))

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('command',choices=['plan','apply','index']);args=p.parse_args()
    if args.command=='plan':plan()
    elif args.command=='apply':apply()
    else:index(inventory(LocalAPI()))
