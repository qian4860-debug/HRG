"""独立复核逐拍回执中的工况完整性、历史回归、正负方向和成对增益。"""

import argparse
import json
import math
from pathlib import Path


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def verify(folder, project):
    """按发布角速率单位 mrad/s 重新评分；启动窗和 160–240 ms 窗分别汇总。"""
    prior = read(project / "research/three_angle_observation_20261115/split_bias_converter.json")
    old = {(c["bits"], round(c["rate_rad_s"] * 1000, 6)): c for c in prior["cases"]}
    n_matched = 0
    for bits in (10, 12, 16):
        run = read(folder / f"adc{bits}_comparison.json")
        assert run["adc_bits"] == bits and run["dac_bits"] == 14 and run["fs_Hz"] == 5_440_000
        assert run["windows_s"] == prior["windows_s"] and run["adc_span_V"] == 2
        rows = {(c["phase_deg"], c["truth_mrad_s"]): c for c in run["cases"]}
        phases = sorted({angle for angle, _ in rows})
        assert 0 in phases
        rates = [-1, -.3, 0, .3, 1]
        assert len(rows) == len(run["cases"]) == len(phases)*len(rates)
        for phase in phases:
            for rate in rates:
                row = rows[phase, rate]
                assert row["frames"] == row["valid_frames"] > 0
                assert row["dac_clip_ticks"] == row["adc_clip_ticks"] == 0
                for i, (_, err) in enumerate(row["raw_corrected_error_mrad_s"]):
                    assert math.isclose(row["corrected_output_mrad_s"][i], rate+err, abs_tol=1e-12)
                    assert row["absolute_pass"][i] == (abs(err) <= run["absolute_limit_mrad_s"])
                if phase == 0 and (bits, rate) in old:
                    comparison = old[bits, rate]["error_raw_corrected_mrad_s"]
                    diff = max(abs(row["raw_corrected_error_mrad_s"][w][j]-comparison[w][j])
                               for w in range(2) for j in range(2))
                    assert diff <= 1e-7 and math.isclose(diff, row["max_history_delta_mrad_s"], abs_tol=1e-12)
                    n_matched += 1
            pairs = [p for p in run["pairs"] if p["phase_deg"] == phase]
            assert len(pairs) == 2 and {p["amplitude_mrad_s"] for p in pairs} == {.3, 1}
            for pair in pairs:
                amplitude = pair["amplitude_mrad_s"]
                pos, neg = rows[phase, amplitude], rows[phase, -amplitude]
                for w in range(2):
                    p, n = pos["corrected_output_mrad_s"][w], neg["corrected_output_mrad_s"][w]
                    gain = (p-n)/(2*amplitude)
                    good = n < 0 < p
                    assert math.isclose(gain, pair["gain"][w], abs_tol=1e-12)
                    assert good == pair["directions_correct"][w]
                    assert pair["pass"][w] == (good and abs(gain-1) <= .05 and
                                               pos["absolute_pass"][w] and neg["absolute_pass"][w])
            for w in range(2):
                passed = sum(rows[phase,r]["absolute_pass"][w] for r in rates)
                print(f"{bits:2d} bit {phase:2g} deg window {w+1}: rate {passed}/5; "
                      f"pair {sum(p['pass'][w] for p in pairs)}/2")
    assert n_matched == 6
    print("All 6 zero-phase historical trajectories matched the previous report.")


if __name__ == "__main__":
    folder = Path(__file__).resolve().parent
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument("--project", type=Path, default=folder.parent.parent)
    cli.add_argument("--folder", type=Path, default=folder)
    args = cli.parse_args()
    verify(args.folder, args.project)
