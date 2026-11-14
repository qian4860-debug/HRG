"""五端假负载盲测与采集回放。估计器只读采样、驱动参考和预先核验的路由。"""
import argparse
import json
from pathlib import Path

import numpy as np


FS = 5_440_000
CARRIER = 6_800
N = FS // CARRIER
ADC_STEP = 2 / 2**16
ANGLE_BUDGET = .001  # 驻波机械角，rad
TAIL = slice(N, 2*N)
TIME = np.arange(2*N) / FS
PHASE = 2*np.pi*CARRIER*TIME
BASIS = np.column_stack((np.cos(PHASE), np.sin(PHASE)))
LATE_DEMOD = np.linalg.pinv(BASIS[TAIL])
WITNESS = slice(N//2, 3*N//2)
WINDOW_DEMOD = np.linalg.pinv(BASIS[WITNESS])
WEIGHT = np.linspace(.05, 1, 2*N)
FULL_DEMOD = np.linalg.pinv(BASIS*np.sqrt(WEIGHT[:, None]))*np.sqrt(WEIGHT)


def azimuth(iq):
    """物理驻波角来自两轴 Stokes 量，周期为 π/2。"""
    x, y = iq.T
    return np.arctan2(2*np.dot(x, y), np.dot(x, x)-np.dot(y, y))/4


def route_design(ref):
    """两轴已测驱动的 I/Q 相量，展开成可独立激励的四列。"""
    return (LATE_DEMOD @ ref[TAIL]).reshape(-1)


def synth(seed, repetitions, tests, train=False):
    """模拟 6800 Hz 假负载测试。每次重接保留独立噪声与未知恢复系数。"""
    rng = np.random.default_rng(seed)
    result = []
    # 以负载系统定义的复增益，估计器不读取这些参数。
    route = np.array([[.12, -.03, .03, .09], [.02, .09, -.11, .01],
                      [-.09, .03, .04, .08], [.01, .11, -.08, .02]])
    arms = ("off", "pos_x", "neg_x", "pos_y", "neg_y", "pos_xy", "neg_xy")
    codes = np.array([[0, 0], [1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [-1, -1]])
    for test in tests:
        for run in range(repetitions):
            idx = run % len(arms)
            amplitude = rng.uniform(.025, .08)
            carrier_phase = rng.uniform(-np.pi, np.pi, 2)
            ref_iq = amplitude*np.vstack((np.cos(carrier_phase), np.sin(carrier_phase)))*codes[idx]
            beta = rng.uniform(-np.pi/4, np.pi/4)
            signal_phase = rng.uniform(-np.pi, np.pi)
            signal = rng.uniform(.10, .21)*np.outer(
                [np.cos(signal_phase), np.sin(signal_phase)], [np.cos(2*beta), np.sin(2*beta)])
            if train:
                signal.fill(0)
            hidden = np.zeros((2, 2))
            if test in ("coherent_without_reference", "hidden_in_verified_route"):
                # 构造不随驱动见证通道变化的同载波污染。
                hidden = np.outer([np.cos(signal_phase), np.sin(signal_phase)],
                                  [-np.sin(2*beta), np.cos(2*beta)])*.005
            transfer = route if test != "unverified_route_change" else 1.8*route
            assumed_validated = test not in ("coherent_without_reference", "unverified_route_change")
            ref = BASIS @ ref_iq + rng.normal(0, 35e-6, (2*N, 2))
            tau = rng.uniform(9e-6, 20e-6) if train else rng.uniform(7e-6, 24e-6)
            transient = rng.uniform(-.024, .024, 2)*np.exp(-TIME[:, None]/tau)*bool(idx)
            volts = BASIS @ (signal + (ref_iq.reshape(-1) @ transfer).reshape(2, 2) + hidden)
            volts += transient + rng.normal(0, 55e-6, volts.shape)
            clip = bool(np.any((volts < -1) | (volts > 1-ADC_STEP)))
            volts = np.clip(np.round(volts/ADC_STEP)*ADC_STEP, -1, 1-ADC_STEP)
            result.append((volts, ref, clip, assumed_validated, test, arms[idx], beta))
    return result


def calibrate(batch):
    """无运动等效输入的校准批。冻结参考传递矩阵和窗残差预算。"""
    reg = np.stack([route_design(row[1]) for row in batch])
    iq = np.stack([(LATE_DEMOD @ row[0][TAIL]).reshape(-1) for row in batch])
    gain, _, rank, s = np.linalg.lstsq(reg, iq, rcond=None)
    assert rank == 4
    return gain, s


def estimate(volts, ref, clip, validated, gain, method):
    """门控使用已核验路由，而非盲测标签。残差检测可见瞬态，不能检测同基污染。"""
    late = LATE_DEMOD @ volts[TAIL]
    if method == "late_window":
        publish = not clip
        return azimuth(late), publish
    if method == "weighted_full_window":
        return azimuth(FULL_DEMOD @ volts), not clip
    if method == "drive_reference":
        late -= (route_design(ref) @ gain).reshape(2, 2)
    residual = volts[TAIL]-BASIS[TAIL] @ (LATE_DEMOD @ volts[TAIL])
    sv = np.linalg.svd(late, compute_uv=False)
    linearity = (sv[0]**2-sv[1]**2)/max(np.dot(sv, sv), np.finfo(float).tiny)
    publish = not clip and np.linalg.norm(residual)/np.sqrt(residual.size) <= .00015
    publish = publish and sv[0] >= .05 and linearity >= .90
    if method == "drive_reference":
        early = WINDOW_DEMOD @ volts[WITNESS]
        early -= ((WINDOW_DEMOD @ ref[WITNESS]).reshape(-1) @ gain).reshape(2, 2)
        cross = abs(angle_error(azimuth(early), azimuth(late)))
        publish = publish and validated and np.isfinite(ref).all() and cross <= .00085
    return azimuth(late), bool(publish)


def angle_error(estimate_rad, truth_rad):
    """以 4 倍角折返；只评价驻波角，与机体角精度分别报告。"""
    d = 4*(estimate_rad-truth_rad)
    return np.arctan2(np.sin(d), np.cos(d))/4


def score(batch, gain):
    """真值和工况标签只在估计结束后用于统计。拒发始终计入覆盖率分母。"""
    output = []
    for method in ("late_window", "weighted_full_window", "residual_gate", "drive_reference"):
        measurements = [(estimate(*row[:4], gain, method), row[4:]) for row in batch]
        for case in sorted({label[0] for _, label in measurements}):
            for arm in ("all", "off", "pos_x", "neg_x", "pos_y", "neg_y", "pos_xy", "neg_xy"):
                subset = [(est, label) for est, label in measurements if label[0] == case
                          and (arm == "all" or label[1] == arm)]
                if not subset:
                    continue
                errors = np.array([angle_error(estimate_rad, truth) for
                                   (estimate_rad, publish), (_, _, truth) in subset if publish])
                output.append(dict(method=method, case=case, injection=arm, tested=len(subset),
                                   published=len(errors), rejected=len(subset)-len(errors),
                                   false_accept=int(np.sum(np.abs(errors)>ANGLE_BUDGET)),
                                   rms_mrad=float(1e3*np.sqrt(np.mean(errors**2))) if errors.size else None,
                                   max_mrad=float(1e3*np.max(np.abs(errors))) if errors.size else None))
    return output


def transfer_sensitivity(batch, gain):
    """固定已核验标签，测试标定之后参考传递的未察觉比例误差。"""
    nominal = [row for row in batch if row[4] == "nominal"]
    if not nominal:
        return []
    return [
        {"relative_training_gain_error": delta, **next(row for row in score(nominal, gain*(1+delta))
         if row["method"] == "drive_reference" and row["injection"] == "all")}
        for delta in (0, .005, .01, .025, .05, .10)
    ]


def load_capture(path, metadata):
    """读取同一触发对齐的帧。真值为独立运动等效输入，参考为另一路真实测量。"""
    data = np.load(path, allow_pickle=False)
    assert metadata["sample_rate_Hz"] == FS and metadata["carrier_Hz"] == CARRIER
    volts, ref = data["adc_V"], data["drive_ref_V"]
    assert volts.ndim == 3 and volts.shape[1:] == (2*N, 2) and ref.shape == volts.shape
    keys = ("adc_clip", "validated_route", "case", "injection", "truth_beta_rad")
    assert all(data[key].shape == (len(volts),) for key in keys)
    assert np.isfinite(volts).all() and np.isfinite(ref).all()
    assert all(np.isin(data[key], [0, 1]).all() for key in ("adc_clip", "validated_route"))
    assert metadata["sample_origin"] == "sense_connect" and metadata["independent_reference"]
    return list(zip(volts, ref, *(data[key] for key in keys), strict=True))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    parser.add_argument("--calibration", type=Path)
    parser.add_argument("--blind", type=Path)
    parser.add_argument("--metadata", type=Path)
    args = parser.parse_args()
    supplied = (args.calibration, args.blind, args.metadata)
    if any(supplied) and not all(supplied):
        parser.error("实体采集回放需要校准批、盲测批和元数据。")
    if all(supplied):
        metadata = json.loads(args.metadata.read_text(encoding="utf-8"))
        assert args.calibration.resolve() != args.blind.resolve()
        assert args.calibration.read_bytes() != args.blind.read_bytes()
        assert metadata["calibration_batch_id"] != metadata["blind_batch_id"]
        calibration = load_capture(args.calibration, metadata)
        assert metadata["calibration_motion_source_off"] and not any(row[2] for row in calibration)
        blind = load_capture(args.blind, metadata)
        assert all(np.isfinite(row[-1]) for row in blind)
        scope = "provided capture replay; provenance and sample alignment as recorded by operator"
    else:
        metadata = {"calibration_seed": 98263, "blind_seed": 192841}
        calibration = synth(metadata["calibration_seed"], 84, ["nominal"], train=True)
        blind = synth(metadata["blind_seed"], 84, ["nominal", "coherent_without_reference",
                      "unverified_route_change", "hidden_in_verified_route"])
        scope = "synthetic fake-load replay; no hardware measurements"
    gain, singular = calibrate(calibration)
    rows = score(blind, gain)
    if not all(supplied):
        all_arms = {(r["method"], r["case"]): r for r in rows if r["injection"]=="all"}
        tagged = all_arms["drive_reference", "nominal"]
        assert tagged["false_accept"] == 0 and tagged["published"] >= .95*tagged["tested"]
        assert all_arms["residual_gate", "hidden_in_verified_route"]["false_accept"] > 0
        assert all_arms["drive_reference", "hidden_in_verified_route"]["false_accept"] > 0
        assert all_arms["drive_reference", "unverified_route_change"]["published"] == 0
    payload = dict(scope=scope, metadata=metadata, calibration_frames=len(calibration),
                   blind_frames=len(blind), calibration_singular_values=singular.tolist(),
                   angle_budget_mrad=1000*ANGLE_BUDGET, rows=rows,
                   synthetic_gain_sensitivity=transfer_sensitivity(blind, gain) if not all(supplied) else [])
    args.output.write_text(json.dumps(payload, indent=2, allow_nan=False)+"\n",
                           encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()
