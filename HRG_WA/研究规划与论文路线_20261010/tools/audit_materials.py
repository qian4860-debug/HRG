"""Read-only source inventory and text extraction; outputs stay in report folder."""
from pathlib import Path
import hashlib
import json
import re
import sys
import zipfile
import xml.etree.ElementTree as ET

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE / 'vendor'))
from pypdf import PdfReader

ROOT = HERE.parent.parent
OUT = HERE.parent / 'evidence'
OUT.mkdir(exist_ok=True)
files = [p for p in ROOT.rglob('*') if p.is_file() and HERE.parent not in p.parents]
records = []
texts = {}
for p in files:
    rel = str(p.relative_to(ROOT))
    data = p.read_bytes()
    sha = hashlib.sha256(data).hexdigest()
    records.append({'path': str(p), 'bytes': len(data), 'sha256': sha, 'extension': p.suffix})
    if p.suffix.lower() in {'.md', '.m', '.v', '.sv', '.log', '.txt', '.f', '.ps1'}:
        text = data.decode('utf-8-sig', errors='replace')
        texts.setdefault(sha, {'paths': [], 'text': text})['paths'].append(str(p))
    elif p.suffix.lower() == '.pdf':
        try:
            text = '\n'.join(f'\n--- PAGE {i+1} ---\n' + (page.extract_text() or '')
                             for i, page in enumerate(PdfReader(p).pages))
            (OUT / (p.stem + '.txt')).write_text(text, encoding='utf-8')
        except Exception as exc:
            (OUT / (p.stem + '_error.txt')).write_text(str(exc), encoding='utf-8')
    elif p.suffix.lower() == '.docx':
        with zipfile.ZipFile(p) as z:
            tree = ET.fromstring(z.read('word/document.xml'))
            ns = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
            paras = [''.join(t.itertext()) for t in tree.findall('.//w:p', ns)]
            (OUT / (p.stem + '.txt')).write_text('\n'.join(paras), encoding='utf-8')
(OUT / 'source_inventory.json').write_text(json.dumps(records, ensure_ascii=False, indent=2), encoding='utf-8')
(OUT / 'unique_texts.json').write_text(json.dumps(texts, ensure_ascii=False, indent=2), encoding='utf-8')
docs = []
code = []
for sha, item in texts.items():
    suffix = Path(item['paths'][0]).suffix.lower()
    header = '\n\n' + '=' * 60 + '\n' + '\n'.join(item['paths']) + '\nSHA256: ' + sha + '\n'
    if suffix == '.md':
        docs.append(header + item['text'])
    elif suffix in {'.m', '.v', '.sv'}:
        lines = item['text'].splitlines()
        selected = [f'{i+1}: {line}' for i, line in enumerate(lines)
                    if re.search(r'^\s*(function |module |%|//)|frp|kalman|fixed|oracle|assert|pass|FAIL', line, re.I)]
        code.append(header + '\n'.join(selected))
(OUT / 'all_unique_markdown.txt').write_text(''.join(docs), encoding='utf-8')
(OUT / 'code_research_index.txt').write_text(''.join(code), encoding='utf-8')
archive = ROOT / '全角陀螺.zip'
zrecords = []
with zipfile.ZipFile(archive) as z:
    for info in z.infolist():
        if info.is_dir():
            continue
        name = info.filename
        data = z.read(info)
        zrecords.append({'name': name, 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()})
        if name.lower().endswith('.pdf'):
            import io
            try:
                reader = PdfReader(io.BytesIO(data))
                page_ids = sorted(set(range(min(3, len(reader.pages)))) | set(range(max(0, len(reader.pages)-2), len(reader.pages))))
                chunks = [f'ARCHIVE: {name}\nTOTAL PAGES: {len(reader.pages)}\n'
                          'READING SCOPE: first three and last two pages, not full text.\n']
                chunks += [f'\n--- PAGE {i+1} ---\n' + (reader.pages[i].extract_text() or '') for i in page_ids]
                (OUT / ('archive_' + Path(name).stem + '.txt')).write_text(''.join(chunks), encoding='utf-8')
            except Exception as exc:
                (OUT / ('archive_' + Path(name).stem + '_error.txt')).write_text(str(exc), encoding='utf-8')
        elif name.lower().endswith('.docx'):
            import io
            with zipfile.ZipFile(io.BytesIO(data)) as doc:
                tree = ET.fromstring(doc.read('word/document.xml'))
                ns = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
                paragraphs = [''.join(t.itertext()) for t in tree.findall('.//w:p', ns)]
                (OUT / ('archive_' + Path(name).stem + '.txt')).write_text('\n'.join(paragraphs), encoding='utf-8')
(OUT / 'archive_inventory.json').write_text(json.dumps(zrecords, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps({'files': len(records), 'unique_texts': len(texts), 'unique_markdown': len(docs),
                  'archive_entries': len(zrecords), 'output': str(OUT)}, ensure_ascii=False))