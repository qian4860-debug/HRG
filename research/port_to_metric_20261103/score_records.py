"""独立离线评分器；只有该阶段读取private_score中的真实参数与角度。"""
from pathlib import Path
import argparse
import math
import numpy as np
from a0_common import read_json, write_json, constraints


def score(root):
    root = Path(root)
    public = read_json(root/'data/observations/protocol.json')
    truth = read_json(root/'data/private_score/truth.json')
    estimates = read_json(root/'evidence/estimates.json')
    thresholds = read_json(root/'acceptance.json')
    rows = []
    for actual, estimated in zip(truth['cases'], estimates['cases']):
        assert actual['id'] == estimated['id']
        cid = actual['id']; h = np.array(actual['H']); hi = np.linalg.inv(h)
        true_model = dict(D=h@np.array(actual['D'])@hi, K=h@np.array(actual['K'])@hi)
        errors = {name:float(np.linalg.norm(np.array(estimated[name])-true_model[name])/np.linalg.norm(true_model[name])) for name in ['D','K']}
        ols_errors = {name:float(np.linalg.norm(np.array(estimated['OLS_mean'][name])-true_model[name])/np.linalg.norm(true_model[name])) for name in ['D','K']}
        ctrue = constraints(true_model, public['reference_omega'])
        cerror = float(np.linalg.norm(np.array(estimated['C'])-ctrue, 2))
        angles = np.loadtxt(root/'evidence'/f'{cid}_angles.csv', delimiter=',', skiprows=1)
        reference = np.loadtxt(root/'data/private_score'/actual['reference'], delimiter=',', skiprows=1)
        assert np.array_equal(angles[:, 0], reference[:, 0])
        target = reference[:, 1]-reference[0, 1]
        raw_rms = float(np.sqrt(np.mean((angles[:, 1]-target)**2)))
        candidate_rms = float(np.sqrt(np.mean((angles[:, 2]-target)**2))) if np.all(np.isfinite(angles[:, 2])) else None
        eligible = estimated['calibration_update_eligible']
        checks = dict(expected_eligibility=(eligible == actual['expected_eligible']),
                      raw_measurement_remains_valid=bool(np.all(angles[:, 4] == 1)))
        if actual['expected_eligible']:
            clean = actual['kind'] == 'A_clean'
            checks.update(operator_D=errors['D'] <= thresholds['clean_operator_relative' if clean else 'noisy_D_relative'],
                          operator_K=errors['K'] <= thresholds['clean_operator_relative' if clean else 'noisy_K_relative'],
                          heldout_angle=(candidate_rms is not None and candidate_rms <= thresholds['clean_angle_rms_rad' if clean else 'noisy_angle_rms_rad']),
                          angle_improves=(candidate_rms is not None and candidate_rms < raw_rms),
                          heldout_transfer=estimated['heldout_transfer_NRMSE'] <= thresholds['clean_transfer_NRMSE' if clean else 'noisy_transfer_NRMSE'],
                          observed_C_error_inside_empirical_margin=cerror <= estimated['epsilon_C'])
            if estimated['W'] is not None and estimated['null_direction_sine_bound'] is not None:
                w0 = hi.T@hi; w0 *= 2/np.trace(w0); w = np.array(estimated['W'])
                v0 = np.array([w0[0,0], np.sqrt(2)*w0[0,1], w0[1,1]]); v0 /= np.linalg.norm(v0)
                v = np.array([w[0,0], np.sqrt(2)*w[0,1], w[1,1]]); v /= np.linalg.norm(v)
                sine = math.sqrt(max(0., 1-float(v@v0)**2))
                checks['null_direction_bound_observed'] = sine <= estimated['null_direction_sine_bound']+2e-7
            else:
                checks['null_direction_bound_observed'] = False
        else:
            checks['rejected_publication_is_NaN'] = bool(np.all(np.isnan(angles[:, 3])))
            checks['calibration_flag_stays_false'] = bool(np.all(angles[:, 5] == 0))
        rows.append(dict(id=cid, kind=actual['kind'], cohort=actual.get('cohort','development'),
            eligible=eligible, expected_eligible=actual['expected_eligible'], checks=checks,
            passed=all(checks.values()), IV_relative_errors=errors, OLS_relative_errors=ols_errors,
            raw_modal_increment_RMS_rad=raw_rms, candidate_modal_increment_RMS_rad=candidate_rms,
            actual_C_error=cerror, empirical_C_margin=estimated['epsilon_C'],
            constraint_gap=estimated['constraint_singular_values'][-1],
            heldout_transfer_NRMSE=estimated['heldout_transfer_NRMSE']))
    summary = dict(cases=len(rows), checks_matched=sum(r['passed'] for r in rows),
                   accepted=sum(r['eligible'] for r in rows), rejected=sum(not r['eligible'] for r in rows),
                   false_accepts=sum(r['eligible'] and not r['expected_eligible'] for r in rows),
                   false_rejects=sum(not r['eligible'] and r['expected_eligible'] for r in rows),
                   independent_cases=sum(r['cohort']=='independent' for r in rows),
                   independent_checks_matched=sum(r['cohort']=='independent' and r['passed'] for r in rows),
                   scope='条件二阶归一化模型、相对模态角；拒绝不等于精度通过；经验裕量不是严格置信保证')
    write_json(root/'evidence/scores.json', dict(summary=summary, cases=rows))
    return summary


if __name__ == '__main__':
    parser = argparse.ArgumentParser(); parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parent)
    print(score(parser.parse_args().root))
