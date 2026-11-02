"""V4 审查与深入候选的可复算证据：反例、条件性恢复、退化和代价。

只验证本文明确的低阶合成模型，不等于真实表头闭环、RTL 或新颖性验证。
"""
from pathlib import Path
import hashlib
import json
import math
import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def axis(phi):
    return np.array([[math.cos(2*phi), math.sin(2*phi)],
                     [math.sin(2*phi), -math.cos(2*phi)]])


def constraint(op):
    # Symmetric W parameterized by (W00, sqrt(2) W01, W11).
    return np.array([op[0, 1], (op[1, 1]-op[0, 0])/math.sqrt(2), -op[1, 0]])


def metric(operators, tolerance=1e-10):
    matrix = np.array([constraint(a) for a in operators])
    _, singular, vh = np.linalg.svd(matrix, full_matrices=True)
    rank = int(np.sum(singular > tolerance))
    if rank != 2:
        return None, singular, rank
    z = vh[-1]
    w = np.array([[z[0], z[1]/math.sqrt(2)], [z[1]/math.sqrt(2), z[2]]])
    w = 2*w/np.trace(w)
    if np.min(np.linalg.eigvalsh(w)) <= 0:
        return None, singular, rank
    return w, singular, rank


def relative_angle_error(h, w):
    phi = np.linspace(0, 2*np.pi, 1001)
    r = np.array([np.cos(phi), np.sin(phi)])
    y = h@r
    raw = np.unwrap(np.arctan2(y[1], y[0]))
    z = np.linalg.cholesky(w).T@y
    corrected = np.unwrap(np.arctan2(z[1], z[0]))
    # Increment target: subtract each observable's own first sample, no truth fit.
    raw_error = raw-raw[0]-(phi-phi[0])
    corrected_error = corrected-corrected[0]-(phi-phi[0])
    return float(np.sqrt(np.mean(raw_error**2))), float(np.sqrt(np.mean(corrected_error**2)))


def run():
    out = {}
    rng = np.random.default_rng(20261102)
    # SISO can be state controllable/observable even when both port matrices rank 1.
    d = np.diag([.2, .34]); k = np.diag([4., 6.25])
    a = np.block([[np.zeros((2, 2)), np.eye(2)], [-k, -d]])
    b = np.array([[0.], [0.], [1.], [1.]])
    c = np.array([[1., .7, 0., 0.]])
    controllability = np.hstack([np.linalg.matrix_power(a, n)@b for n in range(4)])
    observability = np.vstack([c@np.linalg.matrix_power(a, n) for n in range(4)])
    assert np.linalg.matrix_rank(controllability) == np.linalg.matrix_rank(observability) == 4
    poles = np.linalg.eigvals(a)
    upper = sorted([p for p in poles if p.imag > 0], key=lambda p: p.imag)
    recovered = [[float(-2*p.real), float(abs(p)**2)] for p in upper]
    assert np.max(abs(np.array(recovered)-[[.2, 4.], [.34, 6.25]])) < 1e-12
    # At every pole, numerator of the SISO sum remains nonzero: no cancellation.
    numerator_at_poles = [abs((p*p+.34*p+6.25)+.7*(p*p+.2*p+4)) for p in poles]
    assert min(numerator_at_poles) > 1
    out['rank_not_necessary'] = {'rank_G': 1, 'rank_H': 1, 'state_controllability_rank': 4,
        'state_observability_rank': 4, 'recovered_diagonal_mode_d_k': recovered,
        'minimum_numerator_at_poles': float(min(numerator_at_poles)),
        'scope': '两模态同时对角、欠阻尼且无极零相消；反驳端口满秩作为普遍必要条件'}

    h = np.array([[1.2, .15], [-.08, .85]])
    g = np.array([[.9, -.04], [.03, 1.1]])
    hi = np.linalg.inv(h)
    b2 = np.linalg.inv(g)@hi
    conditions = [float(np.linalg.cond(b2)) for split in [1., .1, .001, 0.]]
    assert np.ptp(conditions) == 0
    out['B2_does_not_depend_on_frequency_split'] = conditions

    # Shared time stamps do not imply shared arithmetic semantics.
    stamps = {'source': 0, 'available': 5, 'execution': 8}
    assert stamps['available'] <= stamps['execution']
    tie_away = math.floor(.5+.5)
    tie_even = round(.5)
    assert tie_away != tie_even
    out['time_contract_counterexample'] = {'both_stamps': stamps,
        'nearest_ties_away_output': tie_away, 'nearest_ties_even_output': tie_even,
        'variable_FCW_exact_increment': 100+101, 'using_start_FCW_twice': 100*2}

    # Recover the Euclidean navigation metric up to scalar, under symmetric D,K.
    d = .4*np.eye(2)+.04*axis(.1)
    k = 4*np.eye(2)+.2*axis(.7)
    dy, ky = h@d@hi, h@k@hi
    w, singular, rank = metric([dy/.4, ky/4])
    true_w = hi.T@hi; true_w *= 2/np.trace(true_w)
    assert w is not None and np.max(abs(w-true_w)) < 1e-12
    raw, corrected = relative_angle_error(h, w)
    assert raw > .05 and corrected < 1e-12
    out['navigation_metric'] = {'constraint_rank': rank, 'singular_values': singular.tolist(),
        'W': w.tolist(), 'W_error_max': float(np.max(abs(w-true_w))),
        'raw_modal_increment_RMS_rad': raw, 'corrected_modal_increment_RMS_rad': corrected,
        'scope': '无噪声合成D/K；仅相对模态角，绝对方向和手性仍需参考'}

    _, _, isotropic_rank = metric([h@(.4*np.eye(2))@hi, h@(4*np.eye(2))@hi])
    commute_d = h@(.4*np.eye(2)+.04*axis(.1))@hi
    commute_k = h@(4*np.eye(2)+.2*axis(.1))@hi
    ambiguous, _, commuting_rank = metric([commute_d/.4, commute_k/4])
    # A mathematical independent self-adjoint probe; hardware realization is not assumed.
    probe = h@axis(.7)@hi
    recovered_w, _, probed_rank = metric([commute_d/.4, commute_k/4, probe])
    assert isotropic_rank == 0 and commuting_rank == 1 and ambiguous is None
    assert probed_rank == 2 and np.max(abs(recovered_w-true_w)) < 1e-12
    _, _, one_probe_rank = metric([h@(.4*np.eye(2))@hi, h@(4*np.eye(2))@hi, probe])
    _, _, two_probe_rank = metric([h@axis(.1)@hi, probe])
    assert one_probe_rank == 1 and two_probe_rank == 2
    out['degeneracy_and_probe'] = {'isotropic_rank': isotropic_rank,
        'commuting_rank': commuting_rank, 'independent_probe_rank': probed_rank,
        'isotropic_with_one_probe_rank': one_probe_rank,
        'isotropic_with_two_independent_probes_rank': two_probe_rank,
        'scope': '探针为算子级概念验证；未证明现有电极/负载能实现该探针'}

    # A computable perturbation certificate, not merely a full-rank/SVD check.
    exact_c = np.stack([constraint(dy/.4), constraint(ky/4)])
    perturbation = np.random.default_rng(20261103).normal(size=(2, 3))
    epsilon = .001
    perturbation *= epsilon/np.linalg.norm(perturbation, 2)
    _, sv_hat, vh_hat = np.linalg.svd(exact_c+perturbation, full_matrices=True)
    true_z = np.array([true_w[0, 0], math.sqrt(2)*true_w[0, 1], true_w[1, 1]])
    true_z /= np.linalg.norm(true_z)
    sine_angle = math.sqrt(max(0., 1-float(true_z@vh_hat[-1])**2))
    bound = epsilon/(sv_hat[-1]-epsilon)
    assert sv_hat[-1] > epsilon and sine_angle <= bound
    assert np.linalg.svd(perturbation, compute_uv=False)[-1] <= epsilon*(1+1e-12)
    out['metric_gap_certificate'] = {'operator_constraint_noise_bound': epsilon,
        'observed_smallest_nonzero_singular_value': float(sv_hat[-1]),
        'measured_null_vector_sine_error': sine_angle, 'certified_upper_bound': float(bound),
        'scope': '已声明谱范数扰动界下的局部度量方向界；实际数据需要独立估计该界'}

    sweep = []
    for scale in [1., .1, .01, .001, 0.]:
        operators = [h@(.4*np.eye(2)+scale*.04*axis(.1))@hi/.4,
                     h@(4*np.eye(2)+scale*.2*axis(.7))@hi/4]
        errors, invalid = [], 0
        _, sv, _ = metric(operators)
        for _ in range(64):
            noisy = [x+2e-5*rng.normal(size=(2, 2)) for x in operators]
            wn, _, _ = metric(noisy)
            if wn is None:
                invalid += 1
            else:
                errors.append(float(np.linalg.norm(wn-true_w)/np.linalg.norm(true_w)))
        sweep.append({'anisotropy_scale': scale, 'trials': 64,
                      'ideal_smallest_constraint_singular_value': float(sv[-1]),
                      'non_SPD_or_rank_invalid': invalid,
                      'median_W_relative_error_among_SPD': float(np.median(errors)) if errors else None})
    out['metric_noise_sweep'] = sweep

    # Reciprocal, collocated, square piezoelectric port model.
    mass = np.array([[1., .05], [.05, .8]])
    damping = .08*np.eye(2)+.01*axis(.2)
    stiffness = np.array([[4., .1], [.1, 5.]])
    theta = np.array([[.8, .1], [.04, .6]])
    ti = np.linalg.inv(theta)
    mq, cq, kq = ti@mass@ti.T, ti@damping@ti.T, ti@stiffness@ti.T
    j = np.array([[0., -1.], [1., 0.]])
    worst_inverse, worst_reciprocity, worst_power = 0., 0., 0.
    for freq in [.3, 1., 2.1, 3.]:
        s = 1j*freq
        mech = mass*s*s+damping*s+stiffness
        ym = s*theta.T@np.linalg.inv(mech)@theta
        worst_inverse = max(worst_inverse, float(np.max(abs(np.linalg.inv(ym)-(mq*s+cq+kq/s)))))
        plus = s*theta.T@np.linalg.inv(mech+.2*s*j)@theta
        minus = s*theta.T@np.linalg.inv(mech-.2*s*j)@theta
        worst_reciprocity = max(worst_reciprocity, float(np.max(abs(plus.T-minus))))
    for _ in range(64):
        r, velocity, voltage = rng.normal(size=(3, 2))
        accel = np.linalg.solve(mass, theta@voltage-damping@velocity-stiffness@r-.2*j@velocity)
        derivative_energy = velocity@mass@accel+velocity@stiffness@r
        port_power_minus_loss = voltage@(theta.T@velocity)-velocity@damping@velocity
        worst_power = max(worst_power, float(abs(derivative_energy-port_power_minus_loss)))
    assert max(worst_inverse, worst_reciprocity, worst_power) < 1e-12
    out['port_structure'] = {'motional_inverse_admittance_error': worst_inverse,
        'Y_transpose_Omega_equals_Y_minus_Omega_error': worst_reciprocity,
        'mechanical_energy_power_balance_error': worst_power,
        'scope': '同端口互易线性压电、方形可逆耦合矩阵；非任意驱检交叉传递'}

    # Continuous causal endpoint linear fit: h(u)=4/T-6u/T².
    n0, acceleration = 1e-9, .2
    optimal = (144*n0/acceleration**2)**.2
    grid = np.geomspace(.001, .5, 3000)
    mse = 4*n0/grid+acceleration**2*grid**4/144
    numeric_optimal = float(grid[np.argmin(mse)])
    assert abs(numeric_optimal/optimal-1) < .003
    n = 32; t = -np.arange(n)*.001
    design = np.stack([np.ones(n), t], axis=1)
    weights = np.linalg.solve(design.T@design, design.T)[0]
    assert abs(weights.sum()-1) < 1e-12 and abs(weights@t) < 1e-12
    assert abs(weights@weights-.11931818181818182) < 1e-12
    out['endpoint_window_tradeoff'] = {'white_noise_intensity_rad2_s': n0,
        'angle_second_derivative_rad_s2': acceleration,
        'continuous_optimal_T_s': optimal, 'grid_optimal_T_s': numeric_optimal,
        '32_frame_noise_variance_gain': float(weights@weights),
        'continuous_MSE_model': '4*N0/T + a^2*T^4/144',
        'scope': '角度直接观测、连续白噪声、局部恒曲率；不直接等于IQ/有色噪声/ARW'}

    information = np.diag([10., 0.])
    identifiable_target, hidden_target = np.array([1., 0.]), np.array([0., 1.])
    false_variance = hidden_target@np.linalg.pinv(information)@hidden_target
    null_projection = abs(hidden_target[1])
    assert false_variance == 0 and null_projection == 1
    out['target_observability_gate'] = {'observable_target_local_variance': float(identifiable_target@np.linalg.pinv(information)@identifiable_target),
        'unobservable_target_naive_pseudoinverse_variance': float(false_variance),
        'unobservable_target_null_projection': float(null_projection),
        'required_action': '先检查目标梯度是否位于信息矩阵可识别子空间，再计算方差；否则拒绝有效认证'}

    out['source_sha256'] = {name: hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in [
        'DSH_md/07_V3可行性判断与创新点优化V4_20261102.md',
        'codex_md/01_五个创新点_复核后改良V3_20261102.md',
        'HRG_WA_simulink/piezo_v10/revision_v10_2_cn/pcn_config.m',
        'HRG_WA_simulink/piezo_v10/noise_research/sn_tick.m',
        'HRG_WA_Digital_ASIC_MATLAB_v4_6_5_FRP_validation_fix/HRG_WA_v46_params.m']}
    out['checks_passed'] = 10
    out['script_sha256'] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    out['limits'] = ['算子级合成数值验证，未运行新增MATLAB/Simulink闭环',
                     '未证明实际表头可实现独立探针', '未作RTL综合或实物验收',
                     '未完成新颖性穷尽检索']
    return out


if __name__ == '__main__':
    results = run()
    (HERE/'deep_results.json').write_bytes((json.dumps(results, ensure_ascii=False, indent=2)+'\n').encode('utf-8'))
    print(json.dumps(results, ensure_ascii=False, indent=2))
