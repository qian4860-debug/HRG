"""Inventory existing Markdown, without changing any historical source."""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parents[1]

def clean(text):
    return re.sub(r'!\[([^\]]*)\]\(data:image/[^)]+\)',
                  r'[原文内嵌图片：\1；图像字节保留在原文件]', text)

def main():
    files = subprocess.check_output(['git', 'ls-files', '-z'], cwd=ROOT).decode().split('\0')
    rows = []
    for name in sorted(x for x in files if x.endswith('.md')):
        if name.startswith('research/complete_book_20261027/') or name == '全角HRG从零到当前_完整推导与验证总书.md':
            continue
        p = ROOT / name
        raw = p.read_bytes()
        gitraw = subprocess.check_output(['git','show','HEAD:'+name],cwd=ROOT)
        assert raw.replace(b'\r\n',b'\n') == gitraw.replace(b'\r\n',b'\n'), name
        text = clean(raw.decode('utf-8-sig'))
        rows.append(dict(id=f'MD{len(rows)+1:03}', path=name,
                         sha256=hashlib.sha256(raw).hexdigest(), bytes=len(raw),
                         git_sha256=hashlib.sha256(gitraw).hexdigest(),
                         normalized_sha256=hashlib.sha256(raw.replace(b'\r\n',b'\n')).hexdigest(),
                         text_characters=len(text),
                         equations=text.count('\\[')+text.count('$$')//2,
                         headings=re.findall(r'^#{1,4} .+', text, flags=re.M)))
    HERE.mkdir(parents=True, exist_ok=True)
    (HERE/'inventory.json').write_text(json.dumps(rows, ensure_ascii=False, indent=2)+'\n',encoding='utf-8',newline='\n')
    print(json.dumps(dict(files=len(rows), cleaned_characters=sum(r['text_characters'] for r in rows)),ensure_ascii=False))
    for r in rows:
        print(r['id'],r['text_characters'],r['equations'],r['path'])

if __name__ == '__main__':
    main()
