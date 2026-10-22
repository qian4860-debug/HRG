"""Incremental receipt: local-reference audit and eight-family acceptance."""
import argparse
from datetime import datetime, timezone
from verify_demo_fix import ROOT, PROJECT, read, sha, base_blob
from verify_spectrum_fix import git, write

FOLDER = ROOT / 'evidence/principle_acceptance'
MANIFEST = FOLDER / 'manifest.json'
OLD = [ROOT / 'evidence/acceptance_manifest.json',
       ROOT / 'evidence/demo_window_fix/manifest.json',
       ROOT / 'evidence/spectrum_fix/manifest.json']
SOURCES = ['wl_setup.m', 'wl_acceptance_budget.m', 'wl_acceptance_metrics.m',
           'wl_acceptance_sim.m', 'wl_run_acceptance.m', 'wl_validate_acceptance.m',
           'wl_run_lock_capture.m',
           'docs/principle_review_acceptance.md', 'tools/verify_principle_acceptance.py']


def check():
    tests = read(FOLDER / 'scoreboards.json')
    assert tests['pass'] and len(tests['checks']) >= 54
    assert all(c['pass'] for c in tests['checks'])
    campaign = read(FOLDER / 'campaign_quick.json')
    assert campaign['executionComplete'] and len(campaign['cases']) == 24
    rows = {r['name']: r for r in campaign['cases']}
    assert not rows['ADC_overrange_negative_control']['metrics']['pass']
    assert not rows['zero_energy_start_negative_control']['metrics']['pass']
    for row in rows.values():
        assert {'build', 'energy', 'quadrature', 'lock', 'angle', 'rate', 'zeroBias', 'saturation'} <= set(row['metrics'])
    for row in rows.values():
        if row['group'] == 'stochastic_single_source':
            switches = row['configuration']['noiseSourceEnable']
            assert sum(switches.values()) == 1
            assert 'pairedNoise' in row['metrics']
    assert rows['zero_input']['metrics']['zeroBias']['status'] == 'short_run_zero_input_mean_only'
    assert rows['baseline']['metrics']['build']['status'] == 'not_assessed_precharged'
    assert not rows['baseline']['metrics']['fullRimPeriodObserved']
    assert rows['channel_skew']['configuration']['channelSkewS'] >= 1 / rows['channel_skew']['configuration']['fsPlant']
    capture = read(FOLDER / 'lock_capture.json')
    assert capture['physicalRimEquivalentPeriods'] >= 1
    assert capture['metrics']['steadySamples'] >= 20
    assert capture['metrics']['pass']
    return len(tests['checks']), len(rows)


def seal():
    check()
    protected = read(ROOT / '_work/principle_review/protected.json')
    for name, digest in protected.items():
        assert sha(PROJECT / name) == digest, 'User bytes changed: ' + name
    paths = [ROOT / n for n in SOURCES]
    paths += [ROOT.parent / 'wa_validate_parameters.m']
    paths += [p for p in FOLDER.iterdir() if p.is_file() and p != MANIFEST and not p.name.endswith('_partial.json')]
    write(MANIFEST, dict(sealedUTC=datetime.now(timezone.utc).isoformat(),
                        baseCommit=git('rev-parse', 'dff5953').decode().strip(),
                        previousReceipts={p.relative_to(PROJECT).as_posix(): sha(p) for p in OLD},
                        files={p.relative_to(PROJECT).as_posix(): sha(p) for p in paths},
                        preservedWorkingChanges=protected))
    print(f'Sealed {len(paths)} new/changed files; historical receipts unchanged.')


def verify():
    patch = read(MANIFEST)
    for name, digest in patch['previousReceipts'].items():
        assert sha(PROJECT / name) == digest, 'Historical receipt modified: ' + name
    files = {}
    for receipt in OLD:
        files.update(read(receipt)['files'])
    files.update(patch['files'])
    for name, digest in files.items():
        actual = sha(PROJECT / name)
        if actual != digest:
            assert actual == patch['preservedWorkingChanges'].get(name), 'Changed sealed file: ' + name
            assert base_blob(patch['baseCommit'], name) == digest
    for name, digest in patch['preservedWorkingChanges'].items():
        assert sha(PROJECT / name) == digest, 'User bytes changed: ' + name
    checks, cases = check()
    print(f'PASS {len(files)} combined hashes, {checks} checks, {cases} actual injection cases; user edits preserved.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--seal', action='store_true')
    args = parser.parse_args()
    seal() if args.seal else verify()
