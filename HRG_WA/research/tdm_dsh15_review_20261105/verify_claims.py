"""独立复核DSH15的单位、角度映射、窗口和谐波混淆；非整机验收。"""
import hashlib
import json
import math
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def run():
    B, omega_deg_s, budget_rad = 0.277, 100.0, 0.003
    omega = math.radians(omega_deg_s)
    rows = []
    for dt_us in [125, 25, 5]:
        dt = dt_us * 1e-6
        peak = B * omega * dt
        rows.append(dict(dt_us=dt_us, alpha_peak_deg=math.degrees(peak),
                         alpha_peak_rad=peak, absolute_A2_budget_percent=100 * peak / budget_rad,
                         relative_A2_upper_bound_percent=200 * peak / budget_rad,
                         beta_peak_deg=math.degrees(peak / 2), body_peak_deg=omega_deg_s * dt / 2))

    # 独立几何对照：精确非同时采样 atan2 对比中点一阶展开。
    alpha = np.linspace(-math.pi, math.pi, 8192, endpoint=False)
    def geometry(dt):
        d = -2 * B * omega * dt
        exact = np.arctan2(np.sin(alpha + d), np.cos(alpha))
        error = np.angle(np.exp(1j * (exact - alpha - d / 2)))
        approx = d / 2 * np.cos(2 * alpha)
        return float(np.max(abs(error - approx)))
    remainder = geometry(125e-6)
    half_remainder = geometry(62.5e-6)

    # 一阶线性AFE整量程阶跃；它不代表压电端口全链建立。
    tau = 1 / (2 * math.pi * 20000)
    settling = -tau * math.log(0.001)
    windows = []
    for slot_us in [50, 75, 100, 150, 600]:
        valid = slot_us * 1e-6 - settling
        windows.append(dict(slot_us=slot_us, valid_us=valid * 1e6,
                            feasible=valid > 0,
                            nominal_fs_for_20_samples_Hz=20 / valid if valid > 0 else None,
                            nominal_samples_at_40k=40000 * valid if valid > 0 else 0))

    # 恒定驻波速率s时，机体角误差导数有(2Δt/B)*s^2*sin(4β)。
    # 固定|s|的正反转并不能独立识别静态sin4β与s^2*sin4β。
    beta = np.linspace(0, math.pi / 2, 256, endpoint=False)
    def regressor(speeds):
        angle = np.tile(beta, len(speeds))
        speed = np.repeat(speeds, len(beta))
        return np.column_stack([np.sin(4 * angle), speed ** 2 * np.sin(4 * angle)])
    fixed = regressor([-1.0, 1.0])
    multiple = regressor([-2.0, -1.0, -0.5, 0.5, 1.0, 2.0])

    # 中点几何的时间差分独立核对速率误差项（恒Ω、无虚拟进动）。
    dt, t, beta0 = 125e-6, 0.2, 0.3
    def body_error(tm):
        a = 2 * (beta0 - B * omega * tm)
        d = -2 * B * omega * dt
        raw = math.atan2(math.sin(a + d), math.cos(a))
        e_alpha = math.atan2(math.sin(raw - a - d / 2), math.cos(raw - a - d / 2))
        return -e_alpha / (2 * B)
    h = 1e-4
    derivative = (body_error(t + h) - body_error(t - h)) / (2 * h)
    beta_mid = beta0 - B * omega * (t + dt / 2)
    derivative_approx = 2 * B * omega ** 2 * dt * math.sin(4 * beta_mid)

    checks = {
        "budget_unit_conversion": math.isclose(math.degrees(budget_rad), 0.17188733853924698),
        "125us_occupancy_about_2pct_not_100pct": 2.0 < rows[0]['absolute_A2_budget_percent'] < 2.1,
        "25us_occupancy_below_half_pct_not_23pct": rows[1]['absolute_A2_budget_percent'] < 0.5,
        "nonlinear_geometry_remainder_is_second_order": 3.9 < remainder / half_remainder < 4.1,
        "50us_slot_has_no_valid_window_after_55us": not windows[0]['feasible'],
        "100us_slot_requires_about_445k_nominal": 440000 < windows[2]['nominal_fs_for_20_samples_Hz'] < 450000,
        "600us_slot_counterexample_to_all_40k_TDM_impossible": windows[-1]['nominal_samples_at_40k'] > 20,
        "fixed_magnitude_reverse_scan_is_confounded": int(np.linalg.matrix_rank(fixed)) == 1,
        "multiple_magnitudes_can_separate_two_terms": int(np.linalg.matrix_rank(multiple)) == 2,
        "angle_and_rate_error_have_distinct_scaling": abs(derivative - derivative_approx) < 5e-8,
    }
    sources = ['DSH_md/15_对16号分时复用与高速采样的分析_20261105.md',
               'codex_md/16_分时复用与相位校准是否需要高速采样_20261105.md',
               'research/causal_deembedding_20261103/config.json',
               'research/causal_deembedding_20261103/a2_dsp.py',
               'HRG_WA_simulink/piezo_v10/revision_v10_2_cn/pcn_config.m',
               'HRG_WA_simulink/piezo_v10/revision_v10_2_cn/pcn_plant.m',
               'HRG_WA_Digital_ASIC_MATLAB_v4_6_5_FRP_validation_fix/HRG_WA_v46_params.m',
               'HRG_WA_Digital_ASIC_MATLAB_v4_6_5_FRP_validation_fix/HRG_WA_v46_frp_basis.m',
               'HRG_WA_Digital_ASIC_MATLAB_v4_6_5_FRP_validation_fix/HRG_WA_v46_simulate.m']
    result = dict(scope='simplified_mathematical_review_not_TDM_or_closed_loop_validation',
                  budget_rad=budget_rad, budget_deg=math.degrees(budget_rad),
                  B=B, omega_deg_s=omega_deg_s, angle_rows=rows,
                  instantaneous_alpha_only_dt_limit_ms=1000 * budget_rad / (B * omega),
                  relative_alpha_two_endpoint_bound_dt_limit_ms=500 * budget_rad / (B * omega),
                  first_order_AFE_20k_settling_us=settling * 1e6, window_examples=windows,
                  exact_geometry_remainder_rad=remainder, half_dt_remainder_rad=half_remainder,
                  rate_derivative_numeric_rad_s=derivative, rate_derivative_first_order_rad_s=derivative_approx,
                  checks=checks, passed=all(checks.values()),
                  primary_sources_rechecked=[
                      {'url': 'https://pmc.ncbi.nlm.nih.gov/articles/PMC11944256/',
                       'scope': 'section 4.2 alternating demodulation'},
                      {'url': 'https://www.analog.com/media/en/technical-documentation/data-sheets/AD9215.pdf',
                       'scope': 'table 4; minimum conversion rate definition; low-rate degradation note'}],
                  source_sha256={p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in sources},
                  script_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest())
    (HERE / 'review_checks.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')
    print(json.dumps(result, ensure_ascii=False, indent=2))
    assert result['passed'], checks


if __name__ == '__main__':
    run()
