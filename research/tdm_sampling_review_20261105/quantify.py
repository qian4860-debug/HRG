"""分时窗口/相位预算的可复算算例；不是实物参数或闭环验收。"""
import hashlib
import json
import math
from pathlib import Path

HERE = Path(__file__).resolve().parent


def calculate():
    # 50 us 时隙为自设示例；35 us 仅借用 Wang 2025 一个工况的建立时间。
    slot_s, discard_s = 50e-6, 35e-6
    window_s = slot_s - discard_s
    rates = [40_000, 1_000_000, 5_000_000, 65_000_000]
    phase_budget_deg = 0.1
    return {
        "scope": "illustrative_arithmetic_only_not_hardware_or_closed_loop_validation",
        "slot_us": slot_s * 1e6,
        "discard_us": discard_s * 1e6,
        "valid_window_us": window_s * 1e6,
        "rate_examples": [
            {"fs_Hz": fs, "nominal_samples_in_window": fs * window_s,
             "phase_per_sample_deg_at_1kHz": 360 * 1000 / fs}
            for fs in rates
        ],
        "minimum_fs_for_sample_counts_Hz": {
            str(n): n / window_s for n in [20, 64]
        },
        "phase_time_budget": [
            {"carrier_Hz": f, "phase_budget_deg": phase_budget_deg,
             "time_budget_ns": phase_budget_deg / (360 * f) * 1e9,
             "phase_per_20ns_tick_deg": 360 * f * 20e-9}
            for f in [1000, 7322, 9463]
        ],
        "adc_five_cycle_latency_ns": {
            str(fs): 5 / fs * 1e9 for fs in [5_000_000, 65_000_000]
        },
        "pu_example_amplitude_decay": {
            "f_Hz": 9463, "Q": 132000,
            "tau_s": 132000 / (math.pi * 9463),
            "time_to_20pct_amplitude_loss_s": -math.log(0.8) * 132000 / (math.pi * 9463),
        },
        "pu_timing_example": {
            "drive_ms": 10, "read_ms": 21, "each_discharge_ms": 1,
            "unusable_read_start_ms": 5,
            "cycle_ms": 10 + 21 + 2 * 1,
            "cycle_rate_Hz": 1 / 0.033,
            "valid_read_ms": 21 - 5,
            "azimuth_deviation_deg_at_200deg_s": 0.43 * 200 * (0.010 + (0.021 - 0.005) / 2 + 0.001),
        },
        "assumptions": [
            "nominal fs*Tw is not an exact edge-aligned sample count",
            "all transient rejection and guard time must be included in discard_s",
            "phase per sample is not a lower bound on an I/Q phase estimator",
            "more samples are not automatically statistically independent",
        ],
    }


if __name__ == "__main__":
    result = calculate()
    result["script_sha256"] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    target = HERE / "budget.json"
    target.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps(result, ensure_ascii=False, indent=2))
