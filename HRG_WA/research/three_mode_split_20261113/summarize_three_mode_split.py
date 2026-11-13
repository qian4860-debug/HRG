"""核对三模式 MATLAB 回执，按相同时间和工况计算有符号差分。"""

import json
from pathlib import Path


MODES = ("continuous", "tdm_separate", "tdm_shared")
SPLITS = (0, 25, 50)
BETAS = (0, 22.5)
RATES = (0, .05, -.05, .2, -.2)
DIRECTORY = Path(__file__).resolve().parent


def load(name):
    return json.loads((DIRECTORY / f"{name}.json").read_text(encoding="utf-8"))


def case_key(row):
    return row["mode"], row["split_mHz"], row["initial_beta_deg"], row["rate_rad_s"]


def index(rows, splits, rates):
    """先验证工况、评分覆盖和完整发布，再允许做有符号差分。"""
    table = {case_key(row): row for row in rows}
    expected = {
        (mode, split, beta, rate)
        for mode in MODES for split in splits for beta in BETAS for rate in rates
    }
    assert len(table) == len(rows) and table.keys() == expected
    for row in table.values():
        assert row["score_available"] and not row["tracking_lost"]
        assert row["published_frames"] == row["expected_frames"] > 0
        assert row["adc_clip_ticks"] == 0
        assert row["frame_ticks"] == (800 if row["mode"] == "continuous" else 3200)
    return table


def differences_by_checkpoint(main):
    """先对每种模式扣除同初角的零频差，再比较调度和复用的增量。"""
    contrast = []
    for split in (25, 50):
        for beta in BETAS:
            curves = []
            for mode in MODES:
                case = main[mode, split, beta, 0]
                baseline = main[mode, 0, beta, 0]
                assert case["zero_checkpoint_s"] == baseline["zero_checkpoint_s"]
                curves.append([
                    at_split - at_zero for at_split, at_zero in zip(
                        case["zero_checkpoint_error_mrad"], baseline["zero_checkpoint_error_mrad"],
                        strict=True,
                    )
                ])
            continuous, separate, shared = curves
            contrast.append({
                "split_mHz": split,
                "initial_beta_deg": beta,
                "checkpoint_s": case["zero_checkpoint_s"],
                "split_effect_mrad": dict(zip(MODES, curves, strict=True)),
                "separate_minus_continuous_mrad": [b - a for a, b in zip(continuous, separate, strict=True)],
                "shared_minus_separate_mrad": [b - a for a, b in zip(separate, shared, strict=True)],
            })
    return contrast


def width_contrast(adc10, adc16):
    """只比较评分时间窗一致的 10 位和 16 位，保留每个输入方向的结果。"""
    contrast = []
    for key, coarse in adc10.items():
        fine = adc16[key]
        assert coarse["score_s"] == fine["score_s"]
        contrast.append({
            "mode": key[0],
            "split_mHz": key[1],
            "initial_beta_deg": key[2],
            "rate_rad_s": key[3],
            "rate_error_mrad_s": [coarse["rate_error_mrad_s"], fine["rate_error_mrad_s"]],
            "endpoint_error_mrad": [coarse["endpoint_error_mrad"], fine["endpoint_error_mrad"]],
            "rms_error_mrad": [coarse["rms_error_mrad"], fine["rms_error_mrad"]],
            "detrended_rms_mrad": [coarse["detrended_rms_mrad"], fine["detrended_rms_mrad"]],
            "rate_gate_pass": [coarse["rate_gate_pass"], fine["rate_gate_pass"]],
        })
    return contrast


def quality(rows):
    """单列精度、余量和限幅，避免用精度通过替代启动限幅记录。"""
    return {
        "count": len(rows),
        "rate_pass": sum(row["rate_gate_pass"] for row in rows),
        "angle_rms_pass": sum(row["angle_rms_gate_pass"] for row in rows),
        "adc_peak_pass": sum(row["adc_peak_gate_pass"] for row in rows),
        "dac_clip_case_count": sum(row["dac_clip_ticks"] > 0 for row in rows),
        "adc_clip_case_count": sum(row["adc_clip_ticks"] > 0 for row in rows),
        "max_adc_sense_peak_V": max(row["adc_sense_peak_V"] for row in rows),
        "max_abs_rate_error_mrad_s": max(abs(row["rate_error_mrad_s"]) for row in rows),
        "max_rms_error_mrad": max(row["rms_error_mrad"] for row in rows),
    }


def main():
    continuous, tdm, coarse, fine = map(load, ("continuous_main", "tdm_main", "adc10", "adc16"))
    assert continuous["setup"] == tdm["setup"]
    assert coarse["setup"] | {"adc_bits": 16} == fine["setup"]
    baseline = index(continuous["cases"] + tdm["cases"], SPLITS, RATES)
    adc10 = index(coarse["cases"], (0, 50), (0, .05, -.05))
    adc16 = index(fine["cases"], (0, 50), (0, .05, -.05))
    pairs = continuous["signed_pairs"] + tdm["signed_pairs"]
    assert len(pairs) == len(MODES) * len(SPLITS) * len(BETAS) * 2
    summary = {
        "scope": "deterministic 26-state matched experiment, at common acquisition-center times",
        "zero_split_contrasts": differences_by_checkpoint(baseline),
        "signed_pairs": pairs,
        "width_order_bits": [10, 16],
        "width_contrasts": width_contrast(adc10, adc16),
        "quality_by_mode_and_split": [
            {
                "mode": mode,
                "split_mHz": split,
                "zero": quality([baseline[mode, split, beta, 0] for beta in BETAS]),
                "signed": quality([
                    baseline[mode, split, beta, rate] for beta in BETAS for rate in RATES if rate
                ]),
            }
            for mode in MODES for split in SPLITS
        ],
    }
    with (DIRECTORY / "mode_comparison.json").open("w", encoding="utf-8", newline="\n") as out:
        json.dump(summary, out, indent=2, allow_nan=False)
        out.write("\n")


if __name__ == "__main__":
    main()
