"""Read reference files without loading models or executing callbacks."""
import argparse
import collections
import hashlib
import json
from pathlib import Path
import zipfile
import xml.etree.ElementTree as ET


def audit(root):
    files = []
    for p in sorted(root.rglob('*')):
        if not p.is_file():
            continue
        relative = p.relative_to(root).as_posix()
        cache = 'slprj' in p.parts or p.suffix == '.slxc'
        record = dict(path=relative, bytes=p.stat().st_size, cache=cache,
                      sha256=hashlib.sha256(p.read_bytes()).hexdigest())
        if p.suffix in ('.slx', '.mlx') or p.name.endswith('.slx.r2022a'):
            with zipfile.ZipFile(p) as z:
                blocks, callbacks, scripts = [], [], []
                for name in z.namelist():
                    if not name.endswith('.xml'):
                        continue
                    try:
                        tree = ET.fromstring(z.read(name))
                    except ET.ParseError:
                        continue
                    for b in tree.iter('Block'):
                        params = {v.get('Name'): v.text for v in b.findall('P')}
                        blocks.append(dict(xml=name, name=b.get('Name'), type=b.get('BlockType'), params=params))
                    for v in tree.iter('P'):
                        if (v.get('Name') or '').endswith(('Fcn', 'Callback')) and v.text:
                            callbacks.append(dict(xml=name, name=v.get('Name'), value=v.text))
                        if v.get('Name') == 'script' and v.text:
                            scripts.append(dict(xml=name, text=v.text))
                record.update(blocks=blocks, callbacks=callbacks, scripts=scripts)
                if p.suffix == '.mlx':
                    record['live_text'] = ''.join(ET.fromstring(z.read('matlab/document.xml')).itertext())
        elif p.suffix == '.m':
            data = p.read_bytes()
            try:
                record['source_text'] = data.decode('utf-8')
            except UnicodeDecodeError:
                record['source_text'] = data.decode('gb18030', 'replace')
        files.append(record)
    return dict(source_root=str(root.resolve()), note='Read-only ZIP/XML audit; no reference callbacks executed.',
                total_files=len(files), extensions=dict(collections.Counter(Path(f['path']).suffix for f in files)), files=files)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('root', type=Path)
    parser.add_argument('out', type=Path)
    args = parser.parse_args()
    result = audit(args.root)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
    print(result['total_files'], result['extensions'])
