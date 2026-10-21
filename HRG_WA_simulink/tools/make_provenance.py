"""Save small provenance receipts; never copy reference source or PDFs."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]


def source_hash(path):
    data = path.read_bytes()
    if path.suffix in ('.m', '.py', '.json'):
        data = data.replace(b'\r\n', b'\n').replace(b'\r', b'\n')
    return hashlib.sha256(data).hexdigest()


def main():
    audit = json.loads((ROOT / '_work/reference_audit_full.json').read_text(encoding='utf-8'))
    out = dict(source_root=audit['source_root'], total_files=audit['total_files'],
               extensions=audit['extensions'], method=audit['note'], files=[])
    for f in audit['files']:
        original = Path(audit['source_root']) / f['path']
        if hashlib.sha256(original.read_bytes()).hexdigest() != f['sha256']:
            raise SystemExit('Reference file changed since initial audit: ' + f['path'])
        record = {k: f[k] for k in ['path', 'bytes', 'sha256', 'cache']}
        if 'blocks' in f:
            record['block_count'] = len(f['blocks'])
            record['reference_subsystems'] = sorted(set(
                b['params']['ReferencedSubsystem'] for b in f['blocks']
                if 'ReferencedSubsystem' in b['params']))
        out['files'].append(record)
    evidence = ROOT / 'evidence'
    evidence.mkdir(exist_ok=True)
    out['reference_bytes_unchanged_at_seal'] = True
    (evidence / 'reference_inventory.json').write_text(json.dumps(out, ensure_ascii=False, indent=2), encoding='utf-8')
    source = []
    for p in sorted(ROOT.glob('*.m')):
        source.append(dict(path=p.relative_to(ROOT).as_posix(), sha256=source_hash(p)))
    for p in sorted(ROOT.glob('*.slx')):
        source.append(dict(path=p.relative_to(ROOT).as_posix(), sha256=source_hash(p)))
    for p in sorted((ROOT / 'tools').glob('*.py')):
        source.append(dict(path=p.relative_to(ROOT).as_posix(), sha256=source_hash(p)))
    profile = ROOT.parent / 'HRG_WA_Digital_ASIC_MATLAB_v4_6_5_FRP_validation_fix/HRG_WA/config/head_default.json'
    source.append(dict(path=profile.relative_to(ROOT.parent).as_posix(), sha256=source_hash(profile)))
    literature = []
    names = ['2021_Whole_Angle_Control_Vector_Composition.pdf',
             'High_quality_factor_MEMS_gyroscope_with_whole_angle_mode_of_operation.pdf',
             'Real-Time_Elimination_of_Harmonic_Drift_for_Hemispherical_Resonator_Gyro_Based_on_FRP_Control_Scheme.pdf']
    for name in names:
        p = next((ROOT.parent / '全角陀螺').rglob(name))
        literature.append(dict(path=p.relative_to(ROOT.parent).as_posix(), sha256=hashlib.sha256(p.read_bytes()).hexdigest()))
    result = json.loads((evidence / 'validation_results.json').read_text(encoding='utf-8'))
    if not result['pass']:
        raise SystemExit('Cannot seal a failing regression')
    receipt = dict(date='2026-10-21', scope='Behavioral Simulink, not bit-true RTL or measured head performance',
                   source_hash_policy='Text source CRLF/CR normalized to LF; SLX binary exact bytes. Reference/evidence hashes are exact bytes.',
                   sources=source, literature=literature,
                   validation_sha256=hashlib.sha256((evidence / 'validation_results.json').read_bytes()).hexdigest())
    (evidence / 'provenance.json').write_text(json.dumps(receipt, ensure_ascii=False, indent=2), encoding='utf-8')
    print('Saved source and literature hashes for passing regression.')


if __name__ == '__main__':
    main()
