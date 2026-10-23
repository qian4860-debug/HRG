"""Register verified acquisitions in the local skill without editing original PDFs."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / 'research/literature_acquisition_20261023'
SKILL = Path('C:/Users/11725/.codex/skills/ic-reference-library')


def main():
    summary = json.loads((REPORT / 'summary.json').read_text(encoding='utf-8'))
    assert not summary['file_audit_issues'], 'Resolve file audit issues before indexing'
    refs = SKILL / 'references'
    for source, target in [('README.md', 'hrg-cited-papers-20261023.md'),
                           ('fulltext_manifest.json', 'hrg-cited-papers-20261023.json')]:
        (refs / target).write_bytes((REPORT / source).read_bytes())
    topic = refs / 'hrg-whole-angle.md'
    addition = ('\n2026-10-24引用文献获取更新：[一级引用获取清单](hrg-cited-papers-20261023.md)，'
                '[全文路径与哈希](hrg-cited-papers-20261023.json)。Bryan原卷摘页已取得；'
                'Lynch1995/1998原文尚未取得。L062原损坏文件保留，另存出版方完整30页PDF，'
                '不能将原路径视为已修复。新增全文仅完成身份/字节检查，未据此升级公式核验状态。\n')
    text = topic.read_text(encoding='utf-8')
    if 'hrg-cited-papers-20261023.md' not in text:
        topic.write_text(text + addition, encoding='utf-8', newline='\n')
    subprocess.run([sys.executable, str(ROOT / 'tools/index_reference_library.py'),
                    '--output', str(refs / 'full-library'), '--as-of', '2026-10-24'], check=True)
    full = json.loads((refs / 'full-library/catalog_full_summary.json').read_text(encoding='utf-8'))
    guide = refs / 'full-library.md'
    text = guide.read_text(encoding='utf-8')
    note = f"\n2026-10-24重建索引：{full['counts'].get('file', 0)}个文件、{full['counts'].get('directory', 0)}个目录，遍历错误{len(full['errors'])}。新增引用全文仍仅按元数据及获取清单登记。\n"
    if note not in text:
        guide.write_text(text + note, encoding='utf-8', newline='\n')
    receipt = dict(completed='2026-10-24', skill=str(SKILL),
                   indexed=full['counts'], errors=full['errors'],
                   index_sha256=full['indexSHA256'],
                   fulltext_manifest_sha256=hashlib.sha256((REPORT / 'fulltext_manifest.json').read_bytes()).hexdigest(),
                   boundary='Local metadata and bounded acquisition index; original source PDFs unchanged')
    (REPORT / 'skill_installation_receipt.json').write_text(json.dumps(receipt, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(receipt, ensure_ascii=False))


if __name__ == '__main__':
    main()
