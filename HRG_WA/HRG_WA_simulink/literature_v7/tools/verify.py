"""Seal exact bytes and verify meaningful independent receipts. No dependencies."""
import argparse
import csv
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[1]
E = ROOT / 'evidence'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(name):
    return json.loads((E / name).read_text(encoding='utf-8-sig'))


def verify_metrics():
    unit = read('unit_scoreboards.json')
    assert unit['pass'] and all(c['pass'] for c in unit['checks'])
    m = read('mechanics_scoreboard.json')
    assert m['pass'] and m['halfStepErrorRatio'] < .1
    assert read('noise_scoreboard.json')['pass']
    assert read('interface_sweep.json')['finite']
    assert read('instrument_scoreboard.json')['pass']
    v = read('validation.json')
    assert v['functionalPass'] and all(c['finite'] for c in v['cases'])
    assert v['PI_PIR']['quadratureRatio'] < 1
    assert v['PI_PIR']['energyRatio'] < 1
    cold = next(c['metrics'] for c in v['cases'] if c['name'] == 'zero_state_startup')
    assert cold['build']['status'] == 'zero_energy_start_reached_from_seed'
    assert cold['checks']['build']
    assert read('saved_models.json')['reopenedAndCompiled']
    for model in read('saved_models.json')['carrierModels']:
        assert model['compiled'] and model['scopes'] >= 19 and model['spectra'] >= 16
    # Real switched voltage must vanish outside drive; logs share native grid.
    with (E / 'switched_v7_timing_tail.csv').open(newline='') as f:
        gates = [[float(x) for x in row] for row in csv.reader(f)]
    with (E / 'switched_v7_electrode_voltage_tail.csv').open(newline='') as f:
        volts = [[float(x) for x in row] for row in csv.reader(f)]
    assert len(gates) == len(volts)
    for g, x in zip(gates, volts):
        assert abs(g[0] - x[0]) < 1e-12
        assert g[1] * g[2] == 0 and g[2] * g[3] == 0
        if not g[1]:
            assert max(abs(v) for v in x[1:]) == 0
    return {'unitChecks': len(unit['checks']), 'carrierCases': len(v['cases']),
            'PIR_Q_Ratio': v['PI_PIR']['quadratureRatio'],
            'coldBuildTimeS': cold['build']['timeS']}


def dependencies():
    paths = [p for p in ROOT.rglob('*') if p.is_file() and p != E / 'manifest.json'
             and '__pycache__' not in p.parts]
    # Shared physics, algorithm adapters, legacy helpers, and measured-head input.
    shared = ROOT.parent
    paths += list(shared.glob('*.m'))
    paths += list((shared / 'layered').glob('*.m'))
    paths += list((shared / 'layered' / 'legacy').glob('*.m'))
    legacy_root = REPO / 'HRG_WA_Digital_ASIC_MATLAB_v4_6_5_FRP_validation_fix'
    paths += list(legacy_root.glob('HRG_WA_v46_*.m'))
    paths += [legacy_root / 'HRG_WA' / 'config' / 'head_default.json',
              shared / 'layered' / 'legacy' / 'provenance.json',
              shared / 'layered' / 'evidence' / 'literature_comparison' / 'comparison_catalog.json']
    return sorted(set(paths))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--seal', action='store_true')
    args = parser.parse_args()
    metrics = verify_metrics()
    target = E / 'manifest.json'
    if args.seal:
        receipt = {'date': '2026-10-23', 'scope': 'V7 additive branch and exact shared dependencies',
                   'verified': metrics,
                   'sha256': {p.relative_to(REPO).as_posix(): digest(p) for p in dependencies()}}
        target.write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    receipt = read('manifest.json')
    for path, sha in receipt['sha256'].items():
        assert digest(REPO / path) == sha, f'changed dependency: {path}'
    assert set(receipt['sha256']) == {p.relative_to(REPO).as_posix() for p in dependencies()}, 'unsealed dependency'
    print(json.dumps({'pass': True, 'hashes': len(receipt['sha256']), **metrics}, ensure_ascii=False))


if __name__ == '__main__':
    main()
