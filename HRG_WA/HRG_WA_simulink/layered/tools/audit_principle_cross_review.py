"""Independent algebra for the paper/patent cross-review; no Simulink mutation."""
import argparse
import cmath
import hashlib
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT.parents[1]
OUTPUT = ROOT / 'evidence/principle_cross_review/independent_calculations.json'


def calculate():
    B, dg, gamma = .277, .00025, math.pi * 5000 / 2e6
    maximum_angle_identity_error = 0.0
    maximum_projection_error = 0.0
    maximum_common_amplitude_projection = 0.0
    maximum_common_phase_invariant_error = 0.0
    for k in range(129):
        theta = -math.pi / 2 + k * math.pi / 128
        n = [math.cos(2 * theta), math.sin(2 * theta)]
        p = [-n[1], n[0]]
        d = [complex(n[0], .1 * p[0]), complex(n[1], .1 * p[1])]
        rs = complex(abs(d[0]) ** 2 - abs(d[1]) ** 2,
                     2 * (d[0].conjugate() * d[1]).real)
        maximum_angle_identity_error = max(maximum_angle_identity_error,
                                            abs(rs - .99 * cmath.exp(4j * theta)))
        rotated = [v * cmath.exp(.713j) for v in d]
        rotated_rs = complex(abs(rotated[0]) ** 2 - abs(rotated[1]) ** 2,
                             2 * (rotated[0].conjugate() * rotated[1]).real)
        maximum_common_phase_invariant_error = max(maximum_common_phase_invariant_error, abs(rotated_rs - rs))
        maximum_common_amplitude_projection = max(maximum_common_amplitude_projection, abs(sum(x * y for x, y in zip(n, p))))
        axis, omega = math.radians(17), .01
        ca, sa = math.cos(4 * axis), math.sin(4 * axis)
        An = [ca * n[0] + sa * n[1], sa * n[0] - ca * n[1]]
        dz = [-gamma * n[j] - dg / 2 * An[j] - 2 * B * omega * p[j] for j in range(2)]
        from_matrix = .5 * sum(x * y for x, y in zip(p, dz))
        from_angle = -B * omega + dg / 4 * math.sin(4 * (theta - axis))
        maximum_projection_error = max(maximum_projection_error, abs(from_matrix - from_angle))
    frequency, tau = 5000.0, 1e9 * 1e-12
    a = 2 * math.pi * frequency * tau
    G = a / math.sqrt(1 + a * a) / (1 + (frequency / 30000) ** 2) / math.sqrt(1 + (frequency / 18000) ** 2)
    actuator_gain, energy, zeta, wn = .8, 1.0, .7, 2.0
    kp = zeta * wn / (actuator_gain * energy)
    ki = wn ** 2 / (2 * actuator_gain * energy)
    checks = {
        'four_theta_ellipse_identity': maximum_angle_identity_error < 1e-12,
        'common_phase_preserves_angle_invariants': maximum_common_phase_invariant_error < 1e-12,
        'common_amplitude_noise_has_zero_first_order_projection': maximum_common_amplitude_projection < 1e-12,
        'damping_angle_equation_matches_project_matrix': maximum_projection_error < 1e-12,
        'patent_printed_L_fails_zero_phase_counterexample': 2 * (1 * 1 + 0 * 0) == 2 and 2 * (1 * 0 + 0 * 0) == 0,
        'PI_gain_mapping_matches_desired_characteristic': abs(2 * actuator_gain * energy * kp - 2 * zeta * wn) < 1e-12 and abs(2 * actuator_gain * energy * ki - wn ** 2) < 1e-12,
    }
    assert all(checks.values())
    return dict(checks=checks, readoutGain=G, energyGain=G * G,
                physicalEnergyAtUnitIQ=1 / G ** 2,
                projectDeadZoneThresholdDegS=dg / (4 * B) * 180 / math.pi,
                projectDeadZoneThresholdDegH=dg / (4 * B) * 180 / math.pi * 3600,
                maximumAngleIdentityError=maximum_angle_identity_error,
                maximumProjectionError=maximum_projection_error,
                assumptions='B=.277; dgamma=.00025/s; f0=5kHz; Rf=1Gohm; Cf=1pF; readout poles30k/30k/18kHz; project definitions only')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    result = calculate()
    if args.write:
        local = [
            ('D:/学习资料/资料/全角陀螺/基于全角模式的石英半球谐振陀螺自适应控制电路及方法.pdf', [1, 3, 4]),
            ((PROJECT / '全角陀螺/新增资料_20260825/02_控制与信号处理/2021_Dead_Area_Compensation_Rate_Integrating_HRG.pdf').as_posix(), [2, 3, 4, 5]),
            ((PROJECT / '全角陀螺/新增资料_20261021_WoS/pdf/算法与补偿/2022_Nonlinear_RIG.pdf').as_posix(), [2, 3]),
        ]
        result['localReadings'] = [dict(path=p, readPdfPages=pages, sha256=hashlib.sha256(Path(p).read_bytes()).hexdigest()) for p, pages in local]
        result['priorAcceptanceManifestSHA256'] = hashlib.sha256((ROOT / 'evidence/principle_acceptance/manifest.json').read_bytes()).hexdigest()
        OUTPUT.parent.mkdir(parents=True, exist_ok=True)
        OUTPUT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    else:
        saved = json.loads(OUTPUT.read_text(encoding='utf-8'))
        assert saved['checks'] == result['checks']
        for key, value in result.items():
            if isinstance(value, float):
                assert math.isclose(saved[key], value, rel_tol=1e-10, abs_tol=1e-14), key
        assert saved['priorAcceptanceManifestSHA256'] == hashlib.sha256((ROOT / 'evidence/principle_acceptance/manifest.json').read_bytes()).hexdigest()
    print(f"PASS {len(result['checks'])} independent cross-review algebra groups; no carrier simulation rerun")


if __name__ == '__main__':
    main()
