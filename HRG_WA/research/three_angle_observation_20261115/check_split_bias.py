"""独立核对第49号的留出划分、误差门限、成对增益和阶跃恢复时间。"""
import json
import math
from pathlib import Path


def check(folder):
    def read(name):
        return json.loads((folder / name).read_text(encoding="utf-8"))

    data = read("split_bias_verification.json")
    budget = data["absolute_budget_mrad_s"]
    for mode in data["modes"]:
        assert len(mode["cases"]) == 16 and max(mode["design_condition"]) < 10
        assert len(mode["native_checks"]) == 2
        for p in mode["native_checks"]:
            assert p["frames"] == 34000 and max(p["max_raw_corrected_delta_rad"]) < 1e-8
        for case in mode["cases"]:
            assert case["beta_deg"] not in data["training_beta_deg"]
            errors = case["error_raw_corrected_mrad_s"]
            for first, key in [(0, "all_window_pass"), (2, "late_pass")]:
                assert case[key] == [all(abs(w[j]) <= budget for w in errors[first:]) for j in range(2)]
        for pair in mode["rate_pairs"]:
            def at(rate):
                return next(c for c in mode["cases"] if c["truth_rad_s"] == rate
                            and c["plant_split_Hz"] == c["supplied_split_Hz"] == pair["split_Hz"])
            speed = pair["speed_rad_s"]
            plus, minus = at(speed), at(-speed)
            for i, (pos, neg) in enumerate(zip(plus["error_raw_corrected_mrad_s"], minus["error_raw_corrected_mrad_s"])):
                for j in (0, 1):
                    gain = 1 + (pos[j] - neg[j]) / (2000 * speed)
                    assert math.isclose(gain, pair["gain_raw_corrected"][i][j], abs_tol=1e-12)
                    correct = pos[j]/1000 + speed > 0 and neg[j]/1000 - speed < 0
                    assert correct == pair["directions_correct_raw_corrected"][i][j]
    step = read("split_step_recovery.json")
    assert len(step["cases"]) == 10
    for case in step["cases"]:
        if case["before_Hz"] == case["after_Hz"]:
            assert case["seam_baseline_max_delta_rad"] < 1e-9
        for column in range(3):
            good = [abs(row[column]) <= budget for row in case["post_step_error_mrad_s"]]
            recovery = next(((i+1)*step["window_s"] for i in range(1,len(good)) if good[i] and good[i-1]), None)
            saved = case["confirmed_recovery_s"][column]
            if recovery is None or saved is None:
                assert saved is recovery
            else:
                assert math.isclose(saved, recovery, rel_tol=0, abs_tol=1e-12)
    finite = read("split_bias_converter.json")
    assert {(c["bits"], c["rate_rad_s"]) for c in finite["cases"]} == {
        (b, v) for b in (10,16) for v in (-.001,0,.001)}
    assert all(c["full_and_unclipped"] for c in finite["cases"])
    print("32 static holdouts, 8 speed pairs, 4 native runs, 6 finite-bit runs and 10 step runs checked.")


if __name__ == "__main__":
    check(Path(__file__).resolve().parent)
