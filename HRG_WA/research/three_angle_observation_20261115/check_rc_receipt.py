"""独立核对第46号JSON的单位、筛选结论和证据覆盖；只依赖Python标准库。"""
import json
import math
from pathlib import Path


def check(folder):
    data = json.loads((folder / 'rc_verification.json').read_text(encoding='utf-8'))
    assert len(data['cases']) == 32 and len(data['estimates']) == 8
    assert len(data['native_parity']) == 7
    for estimate in data['estimates']:
        # 理想极点配对满足含泄漏的电气方程，估计只应使用独立尾波参数。
        cap = estimate['true_C_F']
        tau = estimate['true_driver_tau_s']
        conductance = data['assumed_leakage_S']
        assert math.isclose(cap / tau, 1 / estimate['ideal_R_ohm'] + conductance, rel_tol=1e-12)
        estimated_cap = estimate['bleed_fit']['tau_s'] * (1 / data['reference_R_ohm'] + conductance)
        estimated_r = 1 / (estimated_cap / estimate['drive_fit']['tau_s'] - conductance)
        assert math.isclose(estimated_r, estimate['estimated_R_ohm'], rel_tol=1e-12)
    for row in data['cases']:
        # 同一评分窗内三条误差的斜率必须可加；这与原生对拍是不同的检查。
        angles = row['angles']
        total = sum(angles[key] for key in (
            'mechanical_slope_error_rad_s', 'readout_slope_error_rad_s', 'publication_slope_error_rad_s'))
        assert math.isclose(total * 1000, row['total_slope_mrad_s'], abs_tol=1e-8)
        alignment = (row['full_publication'] and row['no_clipping'] and row['peak_adc_V'] < .8
                     and abs(row['topology_delta_mrad_s']) <= .05 and row['topology_rms_mrad'] <= .01)
        absolute = row['full_publication'] and row['no_clipping'] and abs(row['total_slope_mrad_s']) <= .25
        assert row['alignment_screen_pass'] == alignment
        assert row['absolute_rate_screen_pass'] == absolute
    for parity in data['native_parity']:
        assert parity['event_flags_equal'] and parity['max_angle_delta_rad'] < 1e-7
        if parity['exact_codes_required']:
            assert parity['converter_mismatches'] == 0
    assert all(not row['quality_pass'] for row in data['tail_tests']['rejected_fits'])
    assert data['tail_tests']['positive_negative_equal']
    assert data['unequal_axis_single_R_rejected']
    print('32 closed-loop cases, 7 native comparisons, 5 rejection cases: receipt verified.')
    for row in data['cases']:
        if row['mode'] == 'estimated_matched':
            print(row['scenario'], row['R_ohm'], row['topology_delta_mrad_s'], row['alignment_screen_pass'])


if __name__ == '__main__':
    check(Path(__file__).resolve().parent)
