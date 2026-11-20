"""用配对合成帧复核第40号的驱动参考、路由标志及掉线边界。依赖 NumPy。"""
import argparse
import csv
import json
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
import blind_drive_reference as module
from prepare_blind_capture import prepare, synthetic_example, WITNESS_FIELDS


def score(module, batch, gain, ref_transform, route_valid, health, guarded):
    """同一批逐帧盲估；只在估计之后读取留出的角真值。角误差统一以 mrad 计。"""
    errors = []
    reasons = {}
    for volts, ref, clip, _, _, _, truth in batch:
        samples = ref_transform(ref)
        kwargs = {"reference_healthy": health} if guarded else {}
        angle, ok = module.estimate(volts, samples, clip, route_valid, gain, "drive_reference", **kwargs)
        reason = "released" if ok else "withheld"
        reasons[reason] = reasons.get(reason, 0) + 1
        if ok:
            errors.append(1000 * module.angle_error(angle, truth))
    magnitudes = np.abs(errors)
    return dict(frames=len(batch), released=len(errors), withheld=len(batch)-len(errors),
                false_release=int(np.count_nonzero(magnitudes > 1000*module.ANGLE_BUDGET)),
                coverage=len(errors)/len(batch), max_released_mrad=max(magnitudes, default=None),
                reason_counts=reasons)


def capture_regression(directory, saved):
    """通过真实 CSV→NPZ→命令行检验：混合故障局部隔离、旧格式降级、仿真黄金回执一致。"""
    def run(output, *args):
        subprocess.run([sys.executable, str(Path(module.__file__)), str(output), *map(str, args)], check=True)
        return json.loads(output.read_text(encoding="utf-8"))

    gold = json.loads(saved.read_text(encoding="utf-8"))
    assert run(directory/"nominal.json") == gold
    synthetic_example(directory)
    for name in ("calibration", "blind"):
        prepare(directory/f"{name}.csv", directory/f"{name}_labels.csv", directory/f"{name}.npz")
    cmd = ["--calibration", directory/"calibration.npz", "--blind", directory/"blind.npz",
           "--metadata", directory/"capture.json"]
    nominal = run(directory/"normal_replay.json", *cmd)
    assert nominal["reference_integrity"]["blind"] == {"ok": 28}
    raw = directory/"blind.csv"
    with raw.open(encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        fields = reader.fieldnames
        samples = list(reader)
    for row in samples:
        frame, tick = int(row["frame_id"]), int(row["sense_tick"])
        if frame == 1 and tick == 100:
            row["drive_ref_x_V"] = "nan"
        elif frame == 2:
            row["reference_frame_id"] = "1"
        elif frame == 3 and tick == 1200:
            row["reference_sample_index"] = str(int(row["sample_index"])-1)
        elif frame == 4:
            row["reference_healthy"] = "0"
    with raw.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        writer.writerows(samples)
    prepare(raw, directory/"blind_labels.csv", directory/"blind.npz")
    mixed = run(directory/"mixed.json", *cmd)
    integrity = mixed["reference_integrity"]
    assert integrity["calibration_error"] is None and integrity["blind"] == {
        "ok": 24, "nonfinite_reference": 1, "external_reference_fault": 1, "reference_out_of_time": 2}
    def independent_rows(receipt):
        return [r for r in receipt["rows"] if r["method"] != "drive_reference"]
    assert independent_rows(mixed) == independent_rows(nominal)
    def n_published(receipt):
        return sum(r["published"] for r in receipt["rows"]
                   if r["method"] == "drive_reference" and r["injection"] == "all")
    assert n_published(mixed) == n_published(nominal)-4
    # 既有样本无独立参考标签时，禁止根据 sample_index 假造参考时间戳。
    for name in ("blind", "calibration"):
        path = directory/f"{name}.csv"
        with path.open(encoding="utf-8", newline="") as f:
            reader = csv.DictReader(f)
            rows = list(reader)
            legacy_fields = [k for k in reader.fieldnames if k not in WITNESS_FIELDS]
        with path.open("w", encoding="utf-8", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=legacy_fields, extrasaction="ignore")
            writer.writeheader()
            writer.writerows(rows)
        prepare(path, directory/f"{name}_labels.csv", directory/f"{name}.npz")
    legacy = run(directory/"legacy.json", *cmd)
    assert independent_rows(legacy) == independent_rows(nominal)
    assert n_published(legacy) == 0 and legacy["reference_integrity"]["calibration_error"]
    return dict(historical_synthetic_receipt_equal=True, valid_replay_frames=28,
                mixed_fault_reference_status=integrity["blind"], legacy_reference_released=n_published(legacy),
                baseline_rows_unchanged=True)


def main():
    folder = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=folder.parents[1], help="HRG_WA 工程根目录")
    parser.add_argument("--out", type=Path, default=folder/"reference_boundary_scoreboard.json")
    args = parser.parse_args()
    cal_seed, blind_seed = 98263, 192841
    gain, _ = module.calibrate(module.synth(cal_seed, 84, ["nominal"], train=True))
    nominal = module.synth(blind_seed, 84, ["nominal"])
    hidden = module.synth(blind_seed, 84, ["hidden_in_verified_route"])
    # 同随机数确保参考、裁剪标志、路由标志、注入条件、真值一致，唯一区别是检测端的隐藏项。
    for a, b in zip(nominal, hidden, strict=True):
        np.testing.assert_array_equal(a[1], b[1])
        assert a[2:4] == b[2:4] and a[5:] == b[5:]
        assert np.max(np.abs(a[0]-b[0])) > 0
    keep = lambda r: r
    zero = np.zeros_like
    invalid = lambda r: np.full_like(r, np.nan)
    cases = [
        ("verified_nominal", nominal, keep, True, True, False),
        ("verified_hidden_5mV", hidden, keep, True, True, False),
        ("hidden_route_flag_off", hidden, keep, False, True, False),
        ("reference_stuck_zero_no_health", nominal, zero, True, True, False),
        ("reference_stuck_zero_fault_asserted", nominal, zero, True, False, True),
        ("reference_nonfinite_guarded", nominal, invalid, True, True, True),
        ("healthy_guard_nominal", nominal, keep, True, True, True),
        ("healthy_guard_hidden", hidden, keep, True, True, True),
    ]
    rows = {name: score(module, data, gain, change, valid, health, guard)
            for name, data, change, valid, health, guard in cases}
    assert rows["verified_nominal"]["released"] == len(nominal)
    assert rows["verified_nominal"]["false_release"] == 0
    assert rows["verified_hidden_5mV"]["false_release"] == len(hidden)
    assert rows["hidden_route_flag_off"]["released"] == 0
    assert rows["reference_stuck_zero_no_health"]["false_release"] > 0
    assert rows["reference_stuck_zero_fault_asserted"]["released"] == 0
    assert rows["reference_nonfinite_guarded"]["released"] == 0
    assert rows["healthy_guard_nominal"] == rows["verified_nominal"]
    assert rows["healthy_guard_hidden"] == rows["verified_hidden_5mV"]
    receipt = args.root/"research/drive_reference_blind_20261115/blind_drive_reference.json"
    with tempfile.TemporaryDirectory() as temp:
        check = capture_regression(Path(temp), receipt)
    report = dict(scope="paired synthetic witness-failure replay; external health bit is supplied",
                  calibration_seed=cal_seed, blind_seed=blind_seed, calibration_frames=84,
                  angle_limit_mrad=1000*module.ANGLE_BUDGET, paired_frames=84, cases=rows,
                  capture_regression=check)
    args.out.write_text(json.dumps(report, indent=2, allow_nan=False)+"\n", encoding="utf-8", newline="\n")
    for name, row in rows.items():
        print(f"{name}: {row['released']}/{row['frames']} released, {row['false_release']} above limit")


if __name__ == "__main__":
    main()
