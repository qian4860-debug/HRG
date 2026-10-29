"""Check review evidence and source identity; do not certify proposed algorithms."""
from pathlib import Path
import hashlib
import json

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]


def main():
    sources=json.loads((HERE/'sources_reviewed.json').read_text(encoding='utf-8'))
    assert sources['body_read_this_review']==6
    for s in sources['sources']:
        p=Path(s['path'])
        assert hashlib.sha256(p.read_bytes()).hexdigest()==s['sha256'], s['id']
    math=json.loads((HERE/'formula_audit.json').read_text(encoding='utf-8'))
    latency=json.loads((HERE/'latency_audit.json').read_text(encoding='utf-8'))
    assert len(math['checks'])==12 and all(math['checks'].values())
    assert len(latency['checks'])==3 and all(latency['checks'].values())
    assert .074 < latency['original_metrics']['angle_rms_deg'] < .076
    # Statements correspond to actual measured audit outputs, not fitted claims.
    assert latency['iq_vs_window_mid_state_carrier_rms_deg'] < .003
    assert latency['state_ellipse_vs_truth_carrier_rms_deg'] > .04
    report=(ROOT/'V10优化审查_压电表头与Zotero全文证据.md').read_text(encoding='utf-8')
    assert '没有完成全部' in report and '不表示缺陷已修复' in report
    summary=json.loads((HERE/'inventory_summary.json').read_text(encoding='utf-8'))
    assert summary['accessible_pdf_attachments']==251 and summary['unique_pdf_byte_objects']==235
    assert summary['internal_storage_unresolved_paths']==0
    print('PASS: 32 cited source hashes, 6 body-reading records, 12 math examples, 3 MATLAB audit checks, honest coverage and known-limitations labels')


if __name__=='__main__':
    main()
