"""按冻结阈值评分温变之后的低速恢复，保留未恢复运行。"""
import argparse
import csv
import json
import math


def recovery(rows, event_s, hold_s, max_gap_s, angle_rad, rate_rad_s, min_coverage):
    """覆盖率输入为统一长度的因果窗统计，空洞打断持续达标。"""
    if not rows or not all(math.isfinite(row[0]) for row in rows):
        raise ValueError("需要有效时间序列")
    if any(b[0] <= a[0] for a,b in zip(rows, rows[1:])):
        raise ValueError("时间戳须严格递增")
    start, last = None, None
    for t, angle, rate, coverage, locked in rows:
        if t < event_s:
            continue
        if last is not None and t-last > max_gap_s:
            start = None
        last = t
        good = (locked == 1 and min_coverage <= coverage <= 1 and
                abs(angle) <= angle_rad and abs(rate) <= rate_rad_s)
        if not good:
            start = None
            continue
        if start is None:
            start = t
        if t-start >= hold_s:
            return dict(status="ready", t_ready_s=start-event_s, confirmed_s=t-event_s)
    if last is None:
        raise ValueError("事件后无观测")
    # 最晚开始时间比观察结束早一个完整保持期。尾部不连续时上下界不作外推。
    return dict(status="right_censored", t_ready_s=None, observed_after_event_s=last-event_s,
                last_unconfirmed_start_s=None if start is None else start-event_s)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture")
    for name in ("event", "hold", "max-gap", "angle", "rate", "min-coverage"):
        parser.add_argument(f"--{name}", required=True, type=float)
    a = parser.parse_args()
    if (not all(math.isfinite(v) for v in (a.event,a.hold,a.max_gap,a.angle,a.rate,a.min_coverage))
            or min(a.hold,a.max_gap,a.angle,a.rate) <= 0 or not 0 < a.min_coverage <= 1):
        parser.error("阈值须有限且位于有效区间。")
    cols = ("time_s", "angle_error_rad", "rate_error_rad_s", "coverage", "locked")
    with open(a.capture, encoding="utf-8-sig", newline="") as f:
        rows = [tuple(float(row[col]) for col in cols) for row in csv.DictReader(f)]
    print(json.dumps(recovery(rows,a.event,a.hold,a.max_gap,a.angle,a.rate,a.min_coverage),
                     allow_nan=False))


if __name__ == "__main__":
    main()
