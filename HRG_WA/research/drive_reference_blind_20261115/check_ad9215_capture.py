"""验证 AD9215 码制、量程及延迟配对。输入均为合成数据。"""
import csv
import json
from pathlib import Path
import tempfile

import numpy as np

from prepare_blind_capture import AD9215_CODINGS, FIELDS, FS, LABELS, N, prepare


def check(directory):
    samples, labels, output = (directory / name for name in ("samples.csv", "labels.csv", "out.npz"))
    with labels.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(LABELS)
        writer.writerows((frame, 1, "nominal", "off", 0) for frame in range(2))

    ticks = np.arange(2*N)
    x = (ticks % 1024) - 512
    y = (511 - 3*ticks) % 1024 - 512
    reference = np.column_stack((ticks / FS, -2*ticks / FS))

    def encode(code, coding):
        if coding == "offset-binary":
            return int(code + 512)
        if coding == "twos-complement-word":
            return int(code % 1024)
        return int(code)

    def write_samples(coding, delay):
        with samples.open("w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(FIELDS)
            for frame in range(2):
                for tick in range(2*N + delay):
                    sample = 17 + frame*4*N + tick
                    source_tick = tick - delay
                    codes = (x, y) if frame == 0 else (y, x)
                    adc = [encode(code[source_tick], coding) if source_tick >= 0
                           else encode(0, coding) for code in codes]
                    ref = reference[tick] if tick < 2*N else (99, -99)
                    # 前导过载属于窗外，尾拍过载必须保留在第二帧最后一个样本。
                    clip = int(source_tick < 0 or (frame == 1 and source_tick == 2*N-1))
                    writer.writerow((sample, sample/FS, frame, tick, *adc, *ref, clip))

    cases = 0
    for coding in AD9215_CODINGS:
        for vpp in (1.0, 2.0):
            for delay in (0, 5, 7):
                write_samples(coding, delay)
                args = dict(coding=coding, vpp=vpp, delay=delay)
                assert prepare(samples, labels, output, **args) == 2
                with np.load(output) as data:
                    expected = np.array([np.column_stack((x, y)), np.column_stack((y, x))])
                    np.testing.assert_array_equal(data["adc_V"], expected * (vpp/1024))
                    np.testing.assert_array_equal(data["drive_ref_V"], [reference, reference])
                    np.testing.assert_array_equal(data["adc_clip"], [False, True])
                    assert data["adc_clip_samples"].sum() == 1
                    assert data["adc_clip_samples"][1, -1]
                    assert data["adc_delay_cycles"] == delay
                cases += 1

    write_samples("offset-binary", 5)
    original = samples.read_text(encoding="utf-8").splitlines()
    invalid = {
        "missing_tail": original[:-1],
        "missing_inner_sample": original[:12] + original[13:],
        "out_of_range_code": original[:1] + [
            ",".join(original[1].split(",")[:4] + ["1024"] + original[1].split(",")[5:])
        ] + original[2:],
        "timestamp_misalignment": original[:1] + [
            ",".join(original[1].split(",")[:1] + ["0"] + original[1].split(",")[2:])
        ] + original[2:],
    }
    for case, rows in invalid.items():
        samples.write_text("\n".join(rows) + "\n", encoding="utf-8")
        try:
            prepare(samples, labels, output, coding="offset-binary", vpp=2, delay=5)
        except ValueError:
            continue
        raise AssertionError(f"异常输入未拒绝：{case}")
    return dict(source="synthetic", successful_cases=cases, rejected_cases=list(invalid),
                samples_per_channel_per_frame=2*N)


if __name__ == "__main__":
    with tempfile.TemporaryDirectory() as temporary:
        print(json.dumps(check(Path(temporary)), indent=2))
