"""Verify spectrum-observer patch over the two immutable earlier receipts."""
import argparse
from datetime import datetime, timezone
import subprocess
from verify_demo_fix import ROOT, PROJECT, read, sha, base_blob

FOLDER = ROOT / "evidence/spectrum_fix"
MANIFEST = FOLDER / "manifest.json"
OLD = [ROOT / "evidence/acceptance_manifest.json", ROOT / "evidence/demo_window_fix/manifest.json"]


def git(*args):
    return subprocess.check_output(["git", "-c", "safe.directory=" + PROJECT.as_posix(), *args], cwd=PROJECT)


def write(path, data):
    import json
    path.write_bytes(json.dumps(data, ensure_ascii=False, indent=2).encode("utf-8"))


def prepare():
    path = ROOT / "_work/spectrum_reference/hrg_wa_v5.slx"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(git("show", "04050e4:HRG_WA_simulink/layered/models/hrg_wa_v5.slx"))
    print("Prepared immutable 04050e4 baseline in ignored _work; user model files untouched.")


def check():
    r = read(FOLDER / "scoreboards.json")
    assert r["pass"] and len(r["checks"]) == 61 and all(c["pass"] for c in r["checks"])
    assert len(r["instruments"]) == 16 and all(i["compiledSampleTimeS"] > 0 for i in r["instruments"])


def seal():
    check()
    protected = read(ROOT / "_work/spectrum_fix_protected.json")
    for name, digest in protected.items():
        assert sha(PROJECT / name) == digest, "Preexisting user edit changed: " + name
    sources = [ROOT / n for n in ["README.md", "wl_build.m", "wl_view_results.m", "wl_native_psd.m",
               "wl_validate_spectrum.m", "tools/verify_spectrum_fix.py"]] + [PROJECT / ".gitattributes"]
    sources += [ROOT / "models" / ("hrg_wa_v5_spectrum_fixed" + ext) for ext in [".slx", ".png"]]
    sources += [p for p in FOLDER.iterdir() if p.is_file() and p != MANIFEST]
    record = {"sealedUTC": datetime.now(timezone.utc).isoformat(),
              "baseCommit": git("rev-parse", "04050e4").decode().strip(),
              "previousReceipts": {p.relative_to(PROJECT).as_posix(): sha(p) for p in OLD},
              "files": {p.relative_to(PROJECT).as_posix(): sha(p) for p in sources},
              "preservedWorkingChanges": protected}
    write(MANIFEST, record)
    print(f"Sealed {len(sources)} spectrum patch files.")


def verify():
    patch = read(MANIFEST)
    for name, digest in patch["previousReceipts"].items():
        assert sha(PROJECT / name) == digest, "Historical receipt changed: " + name
    files = {}
    for receipt in OLD:
        files.update(read(receipt)["files"])
    files.update(patch["files"])
    protected = patch["preservedWorkingChanges"]
    for name, digest in files.items():
        actual = sha(PROJECT / name)
        if actual != digest:
            assert actual == protected.get(name), "Changed sealed file: " + name
            assert base_blob(patch["baseCommit"], name) == digest
    for name, digest in protected.items():
        actual = sha(PROJECT / name)
        assert actual == digest or actual == base_blob(patch["baseCommit"], name), "Preserved user bytes changed: " + name
    check()
    print(f"PASS {len(files)} historical/patch hashes, 61 spectrum checks and preserved user edits.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seal", action="store_true")
    parser.add_argument("--prepare-baseline", action="store_true")
    args = parser.parse_args()
    if args.prepare_baseline:
        prepare()
    elif args.seal:
        seal()
    else:
        verify()
