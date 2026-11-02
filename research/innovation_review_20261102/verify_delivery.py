"""核对修订稿、原稿快照和本次使用的证据；不改写原始资料。"""
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


if __name__ == '__main__':
    manifest = json.loads((HERE/'evidence_sources.json').read_text(encoding='utf-8'))
    for name, expected in manifest['delivery_sha256'].items():
        assert sha(HERE/name) == expected, name
    for name, expected in manifest['project_evidence_sha256'].items():
        assert sha(ROOT/name) == expected, name
    snapshot = HERE/'original_proposal_snapshot.md'
    assert sha(snapshot) == manifest['original']['sha256']
    original = Path(manifest['original']['path'])
    if original.exists():
        assert sha(original) == sha(snapshot), '原稿原始字节已变化，请保留快照并复核'
    result = json.loads((HERE/'audit_results.json').read_text(encoding='utf-8'))
    assert result['checks_passed'] == 10
    assert result['script_sha256'] == sha(HERE/'audit_claims.py')
    text = (HERE/'五个创新点_可行性评估与修订V2.md').read_text(encoding='utf-8')
    assert text.count('## ') >= 10 and text.count('```') % 2 == 0
    assert all(f'修订创新点{x}' in text for x in '一二三四五')
    assert text.count('\\[') == text.count('\\]') == 21
    print('交付核对通过：五项修订、21组公式、10组代数核验、原稿快照及证据哈希。')
