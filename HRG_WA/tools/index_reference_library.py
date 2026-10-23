"""Index every accessible filesystem entry under a user-selected reference root.

Metadata only: no document contents, archive extraction, or source-file mutation.
The full personal-library index belongs in the local skill repository, not GitHub.
"""
import argparse
from collections import Counter
from datetime import date
import gzip
import hashlib
import json
import os
from pathlib import Path


def build(root, output, as_of):
    root = root.resolve(strict=True)
    output.mkdir(parents=True, exist_ok=True)
    target = output / 'catalog_full.jsonl.gz'
    counts, extensions, top = Counter(), Counter(), Counter()
    errors = []
    with target.open('wb') as binary, gzip.GzipFile(filename='', fileobj=binary, mode='wb', mtime=0) as compressed:
        def write(row):
            compressed.write((json.dumps(row, ensure_ascii=False, separators=(',', ':')) + '\n').encode('utf-8'))
            counts[row['type']] += 1
            top[row['relative'].split('/')[0]] += 1
        pending = [root]
        while pending:
            parent = pending.pop()
            try:
                entries = sorted(os.scandir(parent), key=lambda x: x.name.casefold())
            except OSError as error:
                errors.append(dict(path=parent.as_posix(), error=str(error)))
                continue
            for entry in entries:
                path = Path(entry.path)
                relative = path.relative_to(root).as_posix()
                try:
                    stat = entry.stat(follow_symlinks=False)
                    linked = entry.is_symlink() or bool(getattr(stat, 'st_file_attributes', 0) & 0x400)
                    kind = 'link' if linked else 'directory' if entry.is_dir(follow_symlinks=False) else 'file'
                    row = dict(relative=relative, type=kind, size=stat.st_size if kind == 'file' else None,
                               mtimeNs=stat.st_mtime_ns)
                    write(row)
                    if kind == 'directory':
                        pending.append(path)
                    elif kind == 'file':
                        extensions[path.suffix.lower() or '(none)'] += 1
                except OSError as error:
                    errors.append(dict(path=path.as_posix(), error=str(error)))
    summary = dict(indexDate=as_of, root=root.as_posix(), status='metadata_index_not_fulltext_reading',
                   counts=dict(counts), extensions=dict(extensions.most_common()), topLevelEntries=dict(sorted(top.items())),
                   errors=errors, links='recorded without traversal to avoid cycles and escaping the selected root',
                   archives='archive files indexed; members not extracted',
                   indexSHA256=hashlib.sha256(target.read_bytes()).hexdigest())
    (output / 'catalog_full_summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(dict(root=summary['root'], counts=summary['counts'], errors=len(errors), index=target.as_posix()), ensure_ascii=False))


def search(root, output, terms, limit):
    found = 0
    with gzip.open(output / 'catalog_full.jsonl.gz', 'rt', encoding='utf-8') as stream:
        for line in stream:
            row = json.loads(line)
            if all(term.casefold() in row['relative'].casefold() for term in terms):
                print((root / row['relative']).as_posix())
                found += 1
                if found >= limit:
                    break
    print(f'{found} matches returned (limit {limit})')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path('D:/学习资料'))
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--as-of', help='Explicit index date YYYY-MM-DD, required when rebuilding')
    parser.add_argument('--search', nargs='+')
    parser.add_argument('--limit', type=int, default=100)
    args = parser.parse_args()
    if args.limit < 1:
        parser.error('--limit must be positive')
    if args.search:
        search(args.root, args.output, args.search, args.limit)
    else:
        if not args.as_of:
            parser.error('--as-of YYYY-MM-DD is required when rebuilding')
        date.fromisoformat(args.as_of)
        build(args.root, args.output, args.as_of)


if __name__ == '__main__':
    main()
