"""Collect explicitly listed public papers, validate PDFs, and build a local index."""
import argparse
import concurrent.futures
import csv
import hashlib
import io
import json
import os
import re
import subprocess
from pathlib import Path
from pypdf import PdfReader

ROOT = Path(__file__).resolve().parents[1]
BATCH = ROOT / '全角陀螺' / '新增资料_20261021_WoS'


def collect(item, existing):
    row = dict(item)
    row.update(status='not_acquired', file='', sha256='', pages=0, errors=[])
    # Reuse only an existing file explicitly identified in the source manifest.
    if item.get('existing'):
        path = ROOT / item['existing']
        if path.is_file():
            data = path.read_bytes()
            reader = PdfReader(io.BytesIO(data))
            row.update(status='existing_local', file=str(path.relative_to(ROOT)),
                       sha256=hashlib.sha256(data).hexdigest(), pages=len(reader.pages))
            return row
    for url in item.get('pdf_urls', []):
        try:
            result = subprocess.run(['curl.exe', '--location', '--fail', '--silent',
                                     '--show-error', '--max-time', '30', '--max-filesize',
                                     '50000000', url], capture_output=True, timeout=40)
            if result.returncode:
                raise ValueError(result.stderr.decode('utf-8', errors='replace').strip())
            data = result.stdout
            final_url = url  # Redirect destination not recorded by this transport.
            if len(data) > 50_000_000 or not data.startswith(b'%PDF-'):
                raise ValueError('Response is not a PDF or exceeds 50 MB')
            reader = PdfReader(io.BytesIO(data))
            text = '\n'.join(p.extract_text() or '' for p in reader.pages[:3])
            normalize = lambda s: re.sub(r'[^a-z0-9]', '', s.lower())
            title_words = set(re.findall(r'[a-z]{4,}', item['title'].lower()))
            found_words = set(re.findall(r'[a-z]{4,}', text.lower()))
            match = len(title_words & found_words) / max(1, len(title_words))
            doi_match = bool(item.get('doi')) and normalize(item['doi']) in normalize(text)
            if not doi_match and match < .75:
                raise ValueError(f'PDF identity not confirmed (title overlap={match:.2f})')
            digest = hashlib.sha256(data).hexdigest()
            if digest in existing:
                path = existing[digest]
                status = 'existing_duplicate'
            else:
                path = BATCH / 'pdf' / item['category'] / (item['id'] + '.pdf')
                path.parent.mkdir(parents=True, exist_ok=True)
                if path.exists() and path.read_bytes() != data:
                    raise ValueError('Refusing to overwrite a different PDF')
                path.write_bytes(data)
                status = 'downloaded_verified'
            row.update(status=status, file=path.relative_to(ROOT).as_posix(), sha256=digest,
                       pages=len(reader.pages), download_url=url, final_url=final_url,
                       title_overlap=round(match, 3), doi_match=doi_match)
            return row
        except Exception as exc:
            row['errors'].append(f'{url}: {type(exc).__name__}: {exc}')
    return row


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--download', action='store_true')
    args = parser.parse_args()
    sources = json.loads((BATCH / 'sources.json').read_text(encoding='utf-8'))
    if args.download:
        existing = {hashlib.sha256(p.read_bytes()).hexdigest(): p
                    for p in (ROOT / '全角陀螺').rglob('*.pdf') if BATCH not in p.parents}
        with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
            rows = list(pool.map(lambda item: collect(item, existing), sources))
        (BATCH / 'catalog.json').write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding='utf-8')
    else:
        rows = json.loads((BATCH / 'catalog.json').read_text(encoding='utf-8'))
    # Recover validated downloads from an interrupted earlier collection attempt.
    for row in rows:
        path = BATCH / 'pdf' / row['category'] / (row['id'] + '.pdf')
        if row['status'] == 'not_acquired' and path.is_file():
            data = path.read_bytes()
            reader = PdfReader(io.BytesIO(data))
            text = '\n'.join(p.extract_text() or '' for p in reader.pages[:3])
            words = set(re.findall(r'[a-z]{4,}', row['title'].lower()))
            overlap = len(words & set(re.findall(r'[a-z]{4,}', text.lower()))) / max(1, len(words))
            if overlap >= .75:
                row.update(status='downloaded_verified', file=path.relative_to(ROOT).as_posix(),
                           sha256=hashlib.sha256(data).hexdigest(), pages=len(reader.pages),
                           title_overlap=round(overlap, 3), recovered_after_interruption=True)
    (BATCH / 'catalog.json').write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding='utf-8')
    fields = ['id', 'title', 'doi', 'category', 'discovery', 'status', 'file', 'pages', 'sha256', 'source']
    with (BATCH / 'catalog.csv').open('w', encoding='utf-8-sig', newline='') as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction='ignore')
        writer.writeheader()
        writer.writerows(rows)
    ris = []
    for row in rows:
        ris.extend(['TY  - GEN', f"TI  - {row['title']}", f"DO  - {row.get('doi', '')}",
                    f"UR  - {row['source']}", f"KW  - {row['category']}",
                    f"N1  - {row['discovery']}; {row['status']}"])
        if row['file']:
            ris.append('L1  - ' + (ROOT / row['file']).as_uri())
        ris.extend(['ER  - ', ''])
    (BATCH / 'references.ris').write_text('\n'.join(ris), encoding='utf-8')
    index = ['# 全角陀螺文献入库批次（2026-10-21）', '',
             'WoS 基础检索实测 222 条，开放获取筛选计数 36 条。完整题录导出时浏览器连接断开，未取得导出文件；本目录不是 222 条完整题录。', '',
             '以下是已核实来源的候选及下载结果。分类依据题名/摘要，未将全文取得等同于全文已审阅。RIS 的 GEN 类型用于避免在未核实出版类型时误标。', '',
             '| 类别 | 题名 | 全文状态 | 本地文件 |', '|---|---|---|---|']
    for row in rows:
        link = f"[{row['title']}]({row['source']})"
        file = f"[{Path(row['file']).name}]({Path(os.path.relpath(ROOT / row['file'], BATCH)).as_posix()})" if row['file'] else ''
        index.append(f"| {row['category']} | {link} | {row['status']} | {file} |")
    (BATCH / 'README.md').write_text('\n'.join(index) + '\n', encoding='utf-8')
    counts = {status: sum(r['status'] == status for r in rows) for status in sorted({r['status'] for r in rows})}
    print(json.dumps(counts, ensure_ascii=False))
    for row in rows:
        print(row['id'], row['status'], row['pages'])


if __name__ == '__main__':
    main()
