"""Independently align native DAC CSV clocks and check half-LSB error bounds."""
import csv
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
E = ROOT / "evidence"


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def write(path, data):
    path.write_bytes(json.dumps(data, ensure_ascii=False, indent=2, allow_nan=False).encode("utf-8"))


def main():
    checks = []
    for folder in sorted(E.glob("v*_nominal")):
        c = read(folder / "configuration.json")
        nodes = read(folder / "observation_nodes.json")
        assert all(n.get("waveformDecimation") == 1 for n in nodes), "Regenerate native waveform evidence"
        fs = c["fsPlant"]
        with (folder / "tap_dac_requested_wave.csv").open() as f:
            reference = {round(float(r[0]) * fs): list(map(float, r[1:])) for r in csv.reader(f)}
        with (folder / "tap_dac_wave.csv").open() as f:
            data = [list(map(float, r)) for r in csv.reader(f)]
        errors = [[], []]
        times = []
        for r in data:
            tick = round(r[0] * fs) - round(c["dacDelay"] * fs / c["fsAdc"])
            if tick not in reference:
                continue
            times.append(r[0])
            for i in range(2):
                errors[i].append(r[i + 1] - reference[tick][i])
        assert len(times) > 20
        peak = max(abs(v) for e in errors for v in e)
        bound = c["dacFsV"] / 2 ** c["dacBits"] if c["dacBits"] else 0
        ok = peak <= bound + 1e-12
        checks.append({"name": folder.name + "_DAC_half_LSB", "peakErrorV": peak,
                       "halfLSBV": bound, "samples": len(times), "pass": ok})
        assert ok, checks[-1]
        m = read(folder / "metrics.json")
        m["dacErrorRmsV"] = [math.sqrt(sum(v * v for v in e) / len(e)) for e in errors]
        m["dacErrorWindowStartS"] = times[0]
        m["dacErrorWindowEndS"] = times[-1]
        m["dacReferenceMethod"] = "native integer-clock alignment over last 8 carrier cycles"
        write(folder / "metrics.json", m)
    # Batch screening reports evaluate navigation/ADC budgets. Do not retain
    # the earlier floating-timestamp DAC diagnostic from those trial reports.
    for name in ["sweep_results.json", "joint_candidates.json", "architecture_comparison.json"]:
        path = E / name
        report = read(path)
        for row in report["rows"]:
            for key in list(row["metrics"]):
                if key.startswith("dacError") or key == "dacReferenceMethod":
                    del row["metrics"][key]
        report["dacDiagnosticScope"] = "DAC waveform errors are independently audited in nominal native-rate CSVs; screening rows evaluate navigation and ADC budgets."
        write(path, report)
    write(E / "native_waveform_scoreboards.json", {"checks": checks, "pass": all(c["pass"] for c in checks)})
    print(f"PASS {len(checks)} independently aligned DAC waveform bounds.")


if __name__ == "__main__":
    main()
