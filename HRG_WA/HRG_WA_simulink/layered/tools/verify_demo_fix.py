"""Verify this patch layered over immutable b1c2a77 acceptance evidence."""
import hashlib
import json
import argparse
from datetime import datetime, timezone
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT.parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def base_blob(commit, path):
    data = subprocess.check_output(["git", "-c", "safe.directory=" + PROJECT.as_posix(),
                                    "show", commit + ":" + path], cwd=PROJECT)
    return hashlib.sha256(data).hexdigest()


def main():
    patch = read(ROOT / "evidence/demo_window_fix/manifest.json")
    original = ROOT / "evidence/acceptance_manifest.json"
    assert sha(original) == patch["baseManifestSHA256"], "Historical acceptance manifest changed"
    files = dict(read(original)["files"])
    files.update(patch["files"])
    preserved = patch["preservedWorkingChanges"]
    preserved_count = 0
    for name, digest in files.items():
        actual = sha(PROJECT / name)
        if actual == digest:
            continue
        assert actual == preserved.get(name), "Changed sealed file: " + name
        assert base_blob(patch["baseCommit"], name) == digest, "Historical accepted blob changed"
        preserved_count += 1
    for name, digest in preserved.items():
        actual = sha(PROJECT / name)
        assert actual == digest or actual == base_blob(patch["baseCommit"], name), "User's preserved bytes changed: " + name
    report = read(ROOT / "evidence/demo_window_fix/scoreboards.json")
    assert report["pass"] and len(report["checks"]) == 17
    assert all(c["pass"] for c in report["checks"])
    print(f"PASS {len(files)} historical/patch hashes, 17 demo checks; "
          f"{preserved_count} privately modified sealed files preserved and verified against original Git blobs.")


def seal():
    folder = ROOT / "evidence/demo_window_fix"
    manifest = folder / "manifest.json"
    original = ROOT / "evidence/acceptance_manifest.json"
    base = subprocess.check_output(["git", "-c", "safe.directory=" + PROJECT.as_posix(),
                                    "rev-parse", "b1c2a77"], cwd=PROJECT).decode().strip()
    assert sha(original) == base_blob(base, original.relative_to(PROJECT).as_posix())
    protected = read(ROOT / "_work/demo_fix_protected.json")
    for name, digest in protected.items():
        assert sha(PROJECT / name) == digest, "Preexisting user edit changed: " + name
    report = read(folder / "scoreboards.json")
    assert report["pass"] and len(report["checks"]) == 17
    sources = [ROOT / n for n in ["README.md", "wl_build.m", "wl_demo.m", "wl_sim.m",
               "wl_view_results.m", "wl_validate_demo.m", "tools/verify_demo_fix.py"]]
    sources += [PROJECT / ".gitattributes"]
    sources += [ROOT / "models" / ("hrg_wa_v5_demo_skew_test" + ext) for ext in [".slx", ".png"]]
    sources += [p for p in folder.iterdir() if p.is_file() and p != manifest]
    files = {p.relative_to(PROJECT).as_posix(): sha(p) for p in sources}
    record = {"sealedUTC": datetime.now(timezone.utc).isoformat(), "baseCommit": base,
              "baseManifestSHA256": sha(original), "files": files,
              "preservedWorkingChanges": protected,
              "note": "Incremental acceptance; original manifest/tag bytes retained. Demo creates an unsaved runtime model. Baseline comparison retains preexisting user files."}
    manifest.write_bytes(json.dumps(record, ensure_ascii=False, indent=2).encode("utf-8"))
    print(f"Sealed {len(files)} patch source, fixture and evidence files.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seal", action="store_true", help="create the new patch receipt after passing MATLAB validation")
    args = parser.parse_args()
    seal() if args.seal else main()
