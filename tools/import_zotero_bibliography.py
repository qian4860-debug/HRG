"""Import a Scholar-style JSON bibliography via the official Zotero Local API.

No PDF acquisition, inferred journal metadata, SQLite edits, or stored API keys.
Raw input and the complete personal library stay in the ignored local work area.
"""
from pathlib import Path
from collections import Counter
import argparse
import hashlib
import json
import re
import unicodedata
from urllib.parse import urlsplit, urlunsplit, parse_qsl, urlencode, unquote
from zotero_wa_bridge import LocalAPI

ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'HRG_WA_simulink/layered/_work/zotero_import_20261026'
PUBLIC=ROOT/'research/zotero_import_20261026'
BATCH='JSON导入_2026-10-26_18-24-36'
DATE='2026-10-26'

def save(p,value):
    p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def title_key(value):
    return ''.join(c for c in unicodedata.normalize('NFKC',str(value)).casefold() if c.isalnum())
def valid_title(value):return str(value or '').strip() not in ('','标题不可用','[标题不可用]')
def year(value):
    m=re.search(r'\b(?:18|19|20)\d{2}\b',str(value or ''))
    return m.group() if m else ''
def doi(value):
    m=re.search(r'10\.\d{4,9}/[^\s?#]+',unquote(str(value or '')),re.I)
    return m.group().rstrip('/').casefold() if m else ''
def url_key(value):
    try:u=urlsplit(str(value or '').strip())
    except ValueError:return ''
    if u.scheme not in ('http','https') or not u.netloc:return ''
    host=u.netloc.casefold().removeprefix('www.')
    path=unquote(u.path).replace('/abstract/document/','/document/').rstrip('/')
    query=[(k,v) for k,v in parse_qsl(u.query) if k not in ('hl','lr','oi','ots','sig','authuser') and not k.startswith('utm_')]
    return urlunsplit(('',host,path,urlencode(sorted(query)),''))
def source_marker(fingerprint,record_id):return f'HRG JSON source: {fingerprint}/{record_id}'

def make_item(row,fingerprint):
    known=valid_title(row.get('title'))
    title=str(row.get('title','')).strip() if known else '[题名待补全] '+str(row.get('author','未知作者'))+' ['+str(row['id'])+']'
    authors=[]
    for part in re.split('[,，]',str(row.get('author',''))):
        name=part.replace('…','').replace('...','').strip()
        if name:authors.append({'creatorType':'author','name':name})
    # Single-field names preserve the supplied abbreviated form without guessing
    # given/family names. Omitted authors remain explicit in the raw-source field.
    extra=[source_marker(fingerprint,row['id']),
        'Import date: '+DATE,
        'Authors as supplied: '+str(row.get('author','')),
        'Year as supplied: '+str(row.get('year','')),
        'Citation count snapshot: '+str(row.get('citations','')),
        'Source page/position: '+str(row.get('page',''))+'/'+str(row.get('pos','')),
        'Source keyword: '+str(row.get('keyword','')),
        'Metadata status: supplied bibliography; document type/journal/complete author list not verified']
    tags=[{'tag':BATCH},{'tag':'题录待校对'}]
    if not known:tags.append({'tag':'题名待补全'})
    href=str(row.get('href',''))
    return dict(itemType='document',title=title,date=year(row.get('year')),creators=authors,
        url=href if url_key(href) else '',extra='\n'.join(extra),tags=tags)

def match(row,items,fingerprint):
    marker=source_marker(fingerprint,row['id'])
    eligible=[i for i in items if i['data'].get('itemType') not in ('attachment','note','annotation')]
    found=[i for i in eligible if marker in i['data'].get('extra','').splitlines()]
    if found:return found[0],'source_identity'
    requested_doi=doi(row.get('href'))
    if requested_doi:
        found=[i for i in eligible if doi(i['data'].get('DOI'))==requested_doi]
        if found:return sorted(found,key=lambda x:x['key'])[0],'doi'
    if not valid_title(row.get('title')):return None,'new_incomplete_title'
    title=title_key(row['title']);date=year(row.get('year'));url=url_key(row.get('href'))
    found=[i for i in eligible if title_key(i['data'].get('title',''))==title and
        ((date and year(i['data'].get('date'))==date) or
         (url and url_key(i['data'].get('url'))==url))]
    if found:
        # Reuse one existing record; do not merge/delete other existing duplicates.
        found.sort(key=lambda x:(not bool(x['data'].get('DOI')),x['key']))
        return found[0],'title_year_or_url'
    return None,'new'

def prepare(rows,items,fingerprint):
    current=list(items);create=[];mapping=[]
    for row in rows:
        held,reason=match(row,current,fingerprint)
        if held:key=held['key']
        else:
            data=make_item(row,fingerprint);key='pending:'+str(len(create))
            create.append(data);current.append(dict(key=key,data=data))
        mapping.append(dict(source_id=row['id'],key=key,reason=reason))
    return create,mapping

def inventory(api):
    api.request('/api/')
    return dict(server=api.server,items=api.request('/api/users/0/items?includeTrashed=0'),
        collections=api.request('/api/users/0/collections'))

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('--apply',action='store_true');args=parser.parse_args()
    fingerprint=digest(args.source);rows=json.loads(args.source.read_text(encoding='utf-8-sig'))
    assert isinstance(rows,list) and all(isinstance(r,dict) and r.get('id') for r in rows)
    assert len({r['id'] for r in rows})==len(rows),'Repeated source IDs require reconciliation'
    api=LocalAPI();before=inventory(api);save(WORK/'before.json',before)
    create,mapping=prepare(rows,before['items'],fingerprint)
    summary=dict(date=DATE,source_sha256=fingerprint,source_records=len(rows),
        missing_titles=sum(not valid_title(r.get('title')) for r in rows),
        new_items=len(create),reused_existing_items=len({r['key'] for r in mapping if not r['key'].startswith('pending:')}),
        duplicate_source_rows=len(rows)-len({r['key'] for r in mapping}),
        reasons=dict(Counter(r['reason'] for r in mapping)),collection=BATCH,
        status='planned',boundary='Bibliographic entries and supplied URLs only; no PDF attachments in the input')
    save(WORK/'plan.json',dict(server=api.server,mapping=mapping,create=create,summary=summary))
    save(PUBLIC/'summary.json',summary);print(json.dumps(summary,ensure_ascii=True),flush=True)
    if not args.apply:return
    assert digest(args.source)==fingerprint,'Source changed before import'
    root=[c for c in before['collections'] if c['data']['name']=='全角陀螺' and not c['data'].get('parentCollection')]
    assert len(root)==1,'Unique parent collection required'
    parent=root[0]['key']
    batch=[c for c in before['collections'] if c['data']['name']==BATCH and c['data'].get('parentCollection')==parent]
    assert len(batch)<=1
    if batch:collection=batch[0]['key']
    else:collection=api.write_many('/api/users/0/collections',[dict(name=BATCH,parentCollection=parent)])[0]['key']
    updates={};bykey={i['key']:i for i in before['items']}
    for rec in mapping:
        if rec['key'].startswith('pending:'):continue
        item=bykey[rec['key']];groups=list(item['data'].get('collections',[]));merged=list(dict.fromkeys(groups+[parent,collection]))
        if merged!=groups:updates[item['key']]=dict(key=item['key'],version=item['version'],collections=merged)
    if updates:api.write_many('/api/users/0/items',list(updates.values()))
    for item in create:item['collections']=[parent,collection]
    created=[]
    if create:
        # A one-item pilot exercises the installed client's schema before bulk work.
        created+=api.write_many('/api/users/0/items',create[:1])
        if len(create)>1:created+=api.write_many('/api/users/0/items',create[1:])
    after=inventory(api);save(WORK/'after.json',after)
    # Match every source again, including rows deduplicated inside this export.
    resolved=[]
    for row in rows:
        item,reason=match(row,after['items'],fingerprint)
        assert item is not None,('Missing imported record',row['id'])
        assert collection in item['data'].get('collections',[])
        resolved.append(dict(source_id=row['id'],key=item['key'],reason=reason))
    # Existing bibliographic fields and memberships must remain intact.
    after_bykey={i['key']:i for i in after['items']}
    for key in updates:
        old=bykey[key]['data'];new=after_bykey[key]['data']
        for field in ('title','creators','date','DOI','url','extra'):
            assert old.get(field)==new.get(field),('Changed existing metadata',key,field)
        assert set(old.get('collections',[]))<=set(new.get('collections',[]))
    assert digest(args.source)==fingerprint,'Source changed during import'
    save(WORK/'resolved.json',resolved)
    summary.update(status='verified',created_items=len(created),existing_memberships_extended=len(updates),
        unique_target_items=len({x['key'] for x in resolved}),all_source_rows_resolved=True,
        existing_metadata_preserved=True,source_bytes_preserved=True,total_library_items=len(after['items']))
    save(PUBLIC/'summary.json',summary);print(json.dumps(summary,ensure_ascii=True),flush=True)

if __name__=='__main__':main()
