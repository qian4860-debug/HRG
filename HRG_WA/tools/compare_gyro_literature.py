"""Inventory local HRG references and extract selected pages without modifying PDFs.

An inventory entry proves availability and identity, not that its contents were read.
Text extracts are private working files and must not be committed as a paper corpus.
"""
import argparse
import hashlib
import json
import logging
from pathlib import Path

logging.getLogger('pypdf').setLevel(logging.ERROR)
logging.getLogger('pdfminer').setLevel(logging.ERROR)
PROJECT = Path(__file__).resolve().parents[1]
OUTPUT = PROJECT / 'HRG_WA_simulink/layered/evidence/literature_comparison'
WORK = PROJECT / 'HRG_WA_simulink/layered/_work/literature_comparison'
ROOTS = [Path('D:/学习资料/资料/全角陀螺'), PROJECT / '全角陀螺',
         Path('D:/学习资料/资料/1-s2.0-S0263224123008953-main.pdf')]


def open_pdf(path):
    from pypdf import PdfReader
    try:
        reader = PdfReader(path, strict=False)
        return reader, 'pypdf'
    except Exception:
        import pdfplumber
        return pdfplumber.open(path), 'pdfplumber'


def extract(reader, engine, index):
    page = reader.pages[index]
    return (page.extract_text() if engine == 'pypdf' else page.extract_text(layout=False)) or ''


def inventory():
    grouped = {}
    for root in ROOTS:
        for path in ([root] if root.is_file() else sorted(root.rglob('*.pdf'))):
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            if digest in grouped:
                grouped[digest]['paths'].append(path.as_posix())
                continue
            row = dict(id='L' + str(len(grouped) + 1).zfill(3), sha256=digest,
                       paths=[path.as_posix()], name=path.name,
                       evidenceLevel='inventory_only', readPdfPages=[], error='')
            try:
                reader, engine = open_pdf(path)
                row.update(pages=len(reader.pages), parser=engine)
                if hasattr(reader, 'close'):
                    reader.close()
            except Exception as error:
                row.update(pages=None, parser=None, error=str(error))
            grouped[digest] = row
    result = dict(date='2026-10-23', roots=[p.as_posix() for p in ROOTS],
                  scope='All PDF bytes in the two HRG roots plus one adjacent ASIC paper discovered by whole-library screening; deduplicated by SHA256; not all published literature',
                  files=sum(len(r['paths']) for r in grouped.values()), uniqueByteObjects=len(grouped),
                  items=list(grouped.values()))
    OUTPUT.mkdir(parents=True, exist_ok=True)
    (OUTPUT / 'local_inventory.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({k: v for k, v in result.items() if k != 'items'}, ensure_ascii=False))
    for row in result['items']:
        print(row['id'], row['pages'], row['name'])


def pages(path, selection, label):
    reader, engine = open_pdf(path)
    indices = set()
    for group in selection.split(','):
        parts = group.split('-')
        first = int(parts[0])
        last = int(parts[-1]) if parts[-1] != 'end' else len(reader.pages)
        indices.update(range(first, last + 1))
    WORK.mkdir(parents=True, exist_ok=True)
    target = WORK / (label + '.txt')
    texts = []
    for page in sorted(indices):
        if not 1 <= page <= len(reader.pages):
            raise ValueError(f'PDF page out of range: {page}')
        texts.append(f'\n--- PDF PAGE {page} ---\n' + extract(reader, engine, page - 1))
    target.write_text('\n'.join(texts), encoding='utf-8')
    print(json.dumps(dict(path=path.as_posix(), pages=len(reader.pages), extracted=sorted(indices),
                          engine=engine, output=target.as_posix()), ensure_ascii=False))
    if hasattr(reader, 'close'):
        reader.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--inventory', action='store_true')
    parser.add_argument('--fronts', action='store_true', help='extract first three pages of each inventoried item for screening, not full reading')
    parser.add_argument('--file', type=Path)
    parser.add_argument('--pages', default='1-3')
    parser.add_argument('--label', default='selected_pages')
    args = parser.parse_args()
    if args.inventory:
        inventory()
    elif args.fronts:
        data = json.loads((OUTPUT / 'local_inventory.json').read_text(encoding='utf-8'))
        for row in data['items']:
            try:
                pages(Path(row['paths'][0]), '1-' + str(min(3, row['pages'] or 3)), row['id'])
            except Exception as error:
                print(row['id'], type(error).__name__, str(error)[:150])
    elif args.file:
        if Path(args.label).name != args.label:
            raise ValueError('Label must be a filename component')
        pages(args.file, args.pages, args.label)
    else:
        parser.error('Select --inventory or --file')


if __name__ == '__main__':
    main()
