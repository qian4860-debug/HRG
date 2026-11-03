"""仅读取公开t/u/y记录及协议；无仿真器导入、无真参数输入。"""
from pathlib import Path
import argparse
import math
import numpy as np
from a0_common import (read_json, write_json, read_record, regress, pack, unpack,
                       constraints, solve_metric, angle_increment, write_csv, phasors, sha)


def estimate(observations, output, method='crossfit_iv'):
    observations, output = Path(observations).resolve(), Path(output).resolve()
    used = []

    def load(name, protocol=False):
        path = (observations/name).resolve()
        assert path.is_relative_to(observations), '观测输入路径越界'
        used.append(dict(path=name, sha256=sha(path)))
        return read_json(path) if protocol else read_record(path)

    protocol = load('protocol.json', True)
    allowed = {'schema','synthetic','normalized_model','sample_rate','samples','train_bins','holdout_bins','repeats',
               'reference_omega','uncertainty_inflation','numeric_constraint_floor','null_direction_budget_rad',
               'known_handedness','uncertainty_scope','cases'}
    assert set(protocol) == allowed and protocol['known_handedness'] == 1
    cases = []
    for case in protocol['cases']:
        fits, ols, batches = [], [], []
        for pair in case['train']:
            records = [load(name) for name in pair]
            assert all(len(r) == protocol['samples'] for r in records)
            batches.append(records)
            ols.append(regress(records, protocol['train_bins'], protocol['sample_rate'], 'OLS'))
        for index, records in enumerate(batches):
            # 留一重复试验作当前观测；工具只来自其他重复的OLS模型及当前已知输入。
            pilot = unpack(np.mean([pack(f) for j, f in enumerate(ols) if j != index], axis=0))
            fits.append(regress(records, protocol['train_bins'], protocol['sample_rate'],
                                'OLS' if method == 'ols' else 'IV',
                                pilot if method == 'crossfit_iv' else None))
        vectors = np.array([pack(f) for f in fits]); mean = vectors.mean(axis=0)
        model = unpack(mean)
        matrices = np.array([constraints(f, protocol['reference_omega']) for f in fits])
        cm = matrices.mean(axis=0)
        standard_error = math.sqrt(float(np.sum((matrices-cm)**2)/(len(fits)*(len(fits)-1))))
        epsilon = protocol['numeric_constraint_floor']+protocol['uncertainty_inflation']*standard_error
        metric, singular = solve_metric(cm)
        gap = float(singular[-1])
        bound = epsilon/(gap-epsilon) if gap > epsilon else None
        eligible = metric is not None and bound is not None and bound <= math.sin(protocol['null_direction_budget_rad'])
        reason = 'empirical_gap_and_SPD_pass' if eligible else 'insufficient_information_gap' if bound is None or bound > math.sin(protocol['null_direction_budget_rad']) else 'non_positive_metric'
        # Eligibility freezes here, before any held-out records are opened.
        held_error, held_norm = 0., 0.
        for name in case['holdout_transfer']:
            rec = load(name); p = phasors(rec, protocol['holdout_bins'])
            for index, freq_bin in enumerate(protocol['holdout_bins']):
                w = 2*np.pi*freq_bin*protocol['sample_rate']/len(rec)
                predicted = np.linalg.solve(-w*w*np.eye(2)+1j*w*model['D']+model['K'], model['B']@p[index, :2])
                held_error += float(np.sum(abs(predicted-p[index, 2:])**2)); held_norm += float(np.sum(abs(p[index, 2:])**2))
        rec = load(case['holdout_motion']); y = rec[:, 3:5]
        raw = angle_increment(y)
        candidate = angle_increment(y, metric) if metric is not None else np.full(len(y), np.nan)
        published = candidate if eligible else np.full(len(y), np.nan)
        measurement_valid = np.linalg.norm(y, axis=1) > .05
        write_csv(output/f'{case["id"]}_angles.csv', np.c_[rec[:, 0], raw, candidate, published,
                  measurement_valid.astype(int), np.full(len(y), int(eligible))],
                  ['t','raw_increment','candidate_increment','published_increment','measurement_valid','calibration_update_eligible'])
        result = dict(id=case['id'], selected_method=method,
            D=model['D'].tolist(), K=model['K'].tolist(), B=model['B'].tolist(),
            OLS_mean=unpack(np.mean([pack(f) for f in ols], axis=0)),
            repeat_IV_vectors=vectors.tolist(), repeat_OLS_vectors=[pack(f).tolist() for f in ols],
            maximum_IV_moment_condition=max(f['condition'] for f in fits),
            C=cm.tolist(), constraint_singular_values=singular.tolist(),
            empirical_C_standard_error=standard_error, epsilon_C=epsilon,
            null_direction_sine_bound=bound, W=metric.tolist() if metric is not None else None,
            calibration_update_eligible=bool(eligible), reason=reason,
            heldout_transfer_NRMSE=math.sqrt(held_error/max(held_norm, 1e-30)),
            certification_scope='经验扰动裕量+二阶/实常数检测模型条件；非严格概率保证或硬件认证')
        result['OLS_mean'] = {key:value.tolist() for key,value in result['OLS_mean'].items()}
        cases.append(result)
    write_json(output/'estimates.json', dict(schema='A0-estimates-v1', cases=cases,
        protocol_sha256=sha(observations/'protocol.json'), source_inputs=used,
        estimator_sha256=sha(Path(__file__)), empirical_only=True))
    return cases


if __name__ == '__main__':
    parser = argparse.ArgumentParser(); parser.add_argument('--observations', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--method', choices=['crossfit_iv', 'polynomial_iv', 'ols'], default='crossfit_iv')
    args = parser.parse_args()
    for row in estimate(args.observations, args.output, args.method):
        print(row['id'], 'eligible='+str(row['calibration_update_eligible']), 'gap='+format(row['constraint_singular_values'][-1], '.4g'),
              'epsilon='+format(row['epsilon_C'], '.4g'), 'heldout='+format(row['heldout_transfer_NRMSE'], '.4g'))
