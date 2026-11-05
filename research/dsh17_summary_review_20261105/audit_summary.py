"""DSH17事实与量纲复核；只读旧证据，不重生成已验收模型。"""
import hashlib
import json
import math
from pathlib import Path
import subprocess

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent


def load(name):
    return json.loads((ROOT / name).read_text(encoding='utf-8'))


def metric_constraints(D, K):
    # W=[a,b;b,c], z=[a,sqrt(2)b,c]，取WA-A^TW的12元素。
    return np.array([[A[0, 1], (A[1, 1] - A[0, 0]) / math.sqrt(2), -A[1, 0]] for A in [D, K]])


def run():
    B, dt = 0.277, 125e-6
    rate_rows = []
    budget = math.radians(0.001)  # 自设速率谐波峰值预算1e-3 deg/s，非实物指标。
    for deg_s in [10, 100, 316, 1000]:
        omega = math.radians(deg_s)
        peak = 2 * B * dt * omega ** 2
        limit = budget / (2 * B * omega ** 2)
        rate_rows.append(dict(body_rate_deg_s=deg_s, peak_rate_rad_s=peak,
                              peak_rate_deg_h=math.degrees(peak) * 3600,
                              dt_limit_us_for_0p001_deg_s=limit * 1e6))

    a1 = load('research/port_deembedding_20261103/evidence/scores.json')
    primary = {r['id']: r for r in a1['cases'] if r['mode'] == 'joint_loading'}
    generator = (ROOT / 'research/port_deembedding_20261103/a1_generate.m').read_text(encoding='utf-8')
    basis = (ROOT / 'HRG_WA_Digital_ASIC_MATLAB_v4_6_5_FRP_validation_fix/HRG_WA_v46_frp_basis.m').read_text(encoding='utf-8')
    a2 = load('research/causal_deembedding_20261103/config.json')
    rtl = load('research/physical_adapter_a4_20261105/evidence/rtl_results.json')

    # 同一输出变换下比较各向同性、共轴、非共轴约束秩。
    H = np.array([[1.2, .15], [-.08, .85]])
    invH = np.linalg.inv(H)
    D = np.diag([1.0, 1.2])
    K = np.diag([4.0, 4.3])
    R = np.array([[math.cos(.3), -math.sin(.3)], [math.sin(.3), math.cos(.3)]])
    constraints = {
        'isotropic': metric_constraints(np.eye(2), 4 * np.eye(2)),
        'coaxial': metric_constraints(H @ D @ invH, H @ K @ invH),
        'noncoaxial': metric_constraints(H @ D @ invH, H @ R @ K @ R.T @ invH),
    }
    ranks = {k: int(np.linalg.matrix_rank(v, tol=1e-10)) for k, v in constraints.items()}
    # W对输出映射H的右正交因子不敏感：不能恢复绝对物理方向。
    W1 = invH.T @ invH
    inverse_rotated = np.linalg.inv(H @ R)
    W2 = inverse_rotated.T @ inverse_rotated

    checks = {
        'rate_budget_converts_degrees_to_radians': 10 < rate_rows[1]['dt_limit_us_for_0p001_deg_s'] < 11,
        '100deg_s_peak_rate_is_about_43p5_deg_h': 43 < rate_rows[1]['peak_rate_deg_h'] < 44,
        'A1_AFE_counterexample_uses_1p3_0p75': 'cal.afe_bw=cal.afe_bw.*[1.3 .75]' in generator,
        'A1_Cs_counterexample_uses_20pct': 'cal.Cs=cal.Cs*1.2' in generator,
        'A1_7p95pct_is_heldout_voltage_error': .079 < primary['case_003']['heldout_max_relative'] < .080,
        'A1_12p18pct_is_heldout_voltage_error': .121 < primary['case_009']['heldout_max_relative'] < .123,
        'FRP_uses_scan_rate_harmonics_not_temperature_harmonics': 'scanNormalized.*sin(4*theta)' in basis and 'scanNormalized.*cos(4*theta)' in basis,
        'existing_A2_has_statistical_parameters': a2['calibration_false_reject_alpha'] == .001 and a2['sigma_multiplier'] == 3,
        'W_constraint_rank_depends_on_available_operators': ranks == {'isotropic': 0, 'coaxial': 1, 'noncoaxial': 2},
        'W_has_unresolved_right_rotation': bool(np.allclose(W1, W2, rtol=0, atol=1e-14)),
        'A4_D0_replay_is_64003_cycles': rtl['core_cycles'] == 64003 and rtl['actual_bit_identical'],
    }
    source_names = [
        'DSH_md/17_汇总结论与仍没想到的_20261105.md',
        'DSH_md/16_对17号复核的回应_单位错误与修正口径_20261105.md',
        'research/port_deembedding_20261103/a1_generate.m',
        'research/port_deembedding_20261103/evidence/scores.json',
        'research/causal_deembedding_20261103/config.json',
        'research/reference_covariance_20261103/config.json',
        'research/reference_covariance_20261103/a3_process.py',
        'research/physical_adapter_a4_20261105/config.json',
        'research/physical_adapter_a4_20261105/evidence/rtl_results.json',
        'research/physical_adapter_a4_20261105/a4_adapter_config.m',
        'HRG_WA_simulink/piezo_v10/revision_v10_2_cn/pcn_plant.m',
        'HRG_WA_Digital_ASIC_MATLAB_v4_6_5_FRP_validation_fix/HRG_WA_v46_frp_basis.m',
    ]
    result = dict(scope='read_only_evidence_and_simplified_math_review_not_closed_loop_validation',
                  source_commit=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT).decode().strip(),
                  rate_budget_is_hypothetical=True, rate_rows=rate_rows,
                  A1_primary_case_003_heldout_voltage_error_percent=100 * primary['case_003']['heldout_max_relative'],
                  A1_primary_case_009_heldout_voltage_error_percent=100 * primary['case_009']['heldout_max_relative'],
                  W_constraint_ranks=ranks,
                  frame_8_times_600us=dict(period_ms=4.8, update_Hz=1 / .0048,
                                          ZOH_phase_at_5Hz_deg=360 * 5 * .0048 / 2,
                                          one_extra_frame_phase_at_5Hz_deg=360 * 5 * .0048),
                  zero_failures_upper_bound_95pct_if_100_independent_trials=1 - .05 ** (1 / 100),
                  checks=checks, passed=all(checks.values()),
                  source_sha256={p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in source_names},
                  script_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest())
    (HERE / 'review_evidence.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')
    print(json.dumps({k: v for k, v in result.items() if k not in ['source_sha256']}, ensure_ascii=False, indent=2))
    assert result['passed'], checks


if __name__ == '__main__':
    run()
