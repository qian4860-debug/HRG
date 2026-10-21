"""Seal exact model/evidence bytes; verify source provenance and acceptance."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path

LAYER = Path(__file__).resolve().parents[1]
PROJECT = LAYER.parents[1]
MANIFEST = LAYER / "evidence/acceptance_manifest.json"
PDF_ROOT = Path("C:/Users/11725/xwechat_files/wxid_qvgyt57csh8y22_a935/msg/file/2026-10")
PDFS = [PDF_ROOT / "开题报告(1).pdf", PDF_ROOT / "MEMS硅陀螺数字闭环接口ASIC技术研究.pdf"]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def verify_provenance():
    provenance = read(LAYER / "legacy/provenance.json")
    source = PROJECT / "HRG_WA_Digital_ASIC_MATLAB_v4_6_5_FRP_validation_fix/HRG_WA_v46_simulate.m"
    assert sha(source) == provenance["source_sha256"], "Original MATLAB source changed"
    text = source.read_text(encoding="utf-8")
    helpers = text[text.index("function log = local_allocate_log"):]
    generated = (LAYER / "legacy/wl_legacy.m").read_text(encoding="utf-8")
    assert generated.endswith(helpers), "Legacy helper text no longer matches source"
    assert hashlib.sha256(helpers.encode()).hexdigest() == provenance["helper_bodies_sha256"]
    protected = LAYER / "_work/protected_worktree.json"
    if protected.exists():
        for name, digest in read(protected).items():
            assert sha(LAYER.parent / name) == digest, f"Preexisting user edit changed: {name}"


def check_results():
    a = read(LAYER / "evidence/algorithm_scoreboards.json")
    m = read(LAYER / "evidence/model_scoreboards.json")
    assert a["pass"] and m["pass"], "Functional scoreboards failed"
    native = read(LAYER / "evidence/native_waveform_scoreboards.json")
    assert native["pass"] and len(native["checks"]) == 5
    sweeps = read(LAYER / "evidence/sweep_results.json")["rows"]
    assert len(sweeps) == 30 and all(r["status"] == "simulated" for r in sweeps)
    joint = read(LAYER / "evidence/joint_candidates.json")["rows"]
    assert len(joint) == 6 and all(r["metrics"]["finite"] for r in joint)
    online = read(LAYER / "evidence/online_algorithm_activity.json")
    frp = read(LAYER / "evidence/frp_closed_loop_study.json")
    assert online["onlineUpdates"] > 0 and online["kalmanUpdates"] > 0
    assert frp["training"]["frpUpdates"] > 0 and frp["frozenWeightChange"] == 0
    architecture = read(LAYER / "evidence/architecture_comparison.json")
    assert len(architecture["rows"]) == 4
    for stage in range(2, 7):
        nodes = read(LAYER / f"evidence/v{stage}_nominal/observation_nodes.json")
        assert len(nodes) == 19
        clocks = {n["name"]: n["sampleRateHz"] for n in nodes}
        for name, expected in [("tap_mixer", 40000), ("tap_adc", 40000), ("tap_iq", 1000)]:
            assert abs(clocks[name] - expected) < expected * 1e-6, (stage, name, clocks[name])
    return {"algorithmChecks": len(a["checks"]), "modelChecks": len(m["checks"]), "nativeWaveformChecks": 5,
            "carrierSweepCases": len(sweeps), "jointCandidates": len(joint), "architectureCases": 4,
            "scope": "Functional acceptance; performance budget outcomes are reported separately."}


def seal():
    verify_provenance()
    checks = check_results()
    files = {}
    for path in sorted(LAYER.rglob("*")):
        rel = path.relative_to(LAYER)
        if not path.is_file() or path == MANIFEST or "_work" in rel.parts or "__pycache__" in rel.parts:
            continue
        files[path.relative_to(PROJECT).as_posix()] = sha(path)
    dependencies = [LAYER.parent / n for n in ["wa_parameters.m", "wa_validate_parameters.m", "wa_pack.m", "wa_initial.m", "wa_plant_rhs.m"]]
    dependencies += [PROJECT / "HRG_WA_Digital_ASIC_MATLAB_v4_6_5_FRP_validation_fix/HRG_WA/config/head_default.json",
                     PROJECT / "HRG_WA_Digital_ASIC_MATLAB_v4_6_5_FRP_validation_fix/HRG_WA_v46_simulate.m",
                     PROJECT / "HRG_WA_Digital_ASIC_MATLAB_v4_6_5_FRP_validation_fix/HRG_WA_v46_params.m",
                     PROJECT / "HRG_WA_Digital_ASIC_MATLAB_v4_6_5_FRP_validation_fix/HRG_WA_v46_advanced.m"]
    for path in dependencies:
        files[path.relative_to(PROJECT).as_posix()] = sha(path)
    record = {"sealedUTC": datetime.now(timezone.utc).isoformat(), "checks": checks,
              "files": files, "referenceDocuments": [{"path": str(p), "sha256": sha(p)} for p in PDFS],
              "note": "PDFs are local references only and are not redistributed. Existing dirty baseline models are preserved, excluded from this delivery."}
    MANIFEST.write_bytes(json.dumps(record, ensure_ascii=False, indent=2).encode("utf-8"))
    print(f"Sealed {len(files)} exact source/model/evidence files.")


def verify():
    record = read(MANIFEST)
    for name, digest in record["files"].items():
        assert sha(PROJECT / name) == digest, f"Changed sealed file: {name}"
    for entry in record["referenceDocuments"]:
        path = Path(entry["path"])
        if path.exists():
            assert sha(path) == entry["sha256"], f"Reference PDF changed: {path}"
    verify_provenance()
    check_results()
    print(f"PASS {len(record['files'])} exact hashes and all functional acceptance gates.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()
    verify() if args.verify else seal()
