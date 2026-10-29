"""Read local Zotero attachment metadata; never request library-write access.

The complete personal inventory is deliberately written only under ignored _work.
No download-plugin attribution is inferred from filenames or link mode.
"""
from pathlib import Path
import hashlib
import json
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from zotero_wa_bridge import LocalAPI, attachment_path


def main():
    api = LocalAPI()
    api.request('/api/')
    items = api.request('/api/users/0/items?includeTrashed=0')
    bykey = {x['key']: x for x in items}
    files = []
    for x in items:
        if x['data'].get('itemType') != 'attachment':
            continue
        p = attachment_path(x)
        if not p or not p.is_file() or p.suffix.lower() != '.pdf':
            continue
        parent = bykey.get(x['data'].get('parentItem'), {}).get('data', {})
        files.append(dict(key=x['key'], title=parent.get('title', x['data'].get('title', '')),
                          path=str(p), sha256=hashlib.sha256(p.read_bytes()).hexdigest()))
    work = ROOT / 'HRG_WA_simulink/layered/_work/v10_literature_review'
    work.mkdir(parents=True, exist_ok=True)
    (work/'inventory.json').write_text(json.dumps(dict(items=len(items), files=files), ensure_ascii=False, indent=2), encoding='utf-8')
    storage = Path('C:/Users/11725/Zotero/storage')
    paths = list(storage.rglob('*.pdf'))
    known = {Path(x['path']).resolve() for x in files}
    previous = json.loads((ROOT/'HRG_WA_simulink/layered/_work/v10_electrical/pdf_inventory.json').read_text(encoding='utf-8-sig'))
    summary = dict(date='2026-10-29', zotero_items=len(items), accessible_pdf_attachments=len(files),
                   unique_pdf_byte_objects=len({x['sha256'] for x in files}),
                   internal_storage_pdf_paths=len(paths), internal_storage_unresolved_paths=sum(p.resolve() not in known for p in paths),
                   new_attachment_keys_since_previous_inventory=len({x['key'] for x in files}-{x['key'] for x in previous}),
                   boundary='Attachment inventory is not reading coverage. Previous inventory has no hashes: unchanged keys do not prove unchanged PDF bytes. Download plugin provenance is not reliably available.')
    Path(__file__).with_name('inventory_summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
