"""复核 DSH 对 V2 补充论证的成立条件；仅做代数/数值检查。"""
import hashlib
import json
import math
from pathlib import Path
import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def axis(a):
    return np.array([[math.cos(2*a), math.sin(2*a)],
                     [math.sin(2*a), -math.cos(2*a)]])


def run():
    results = {}
    # 一个模态未被激励/观测，所有端口输出相同而机械谱不相同。
    d1, d2a, d2b = .2, .3, .9
    k1, k2a, k2b = 4., 4.3, 7.
    h = np.array([[1., 0.]])
    g = np.array([[1.], [0.]])
    worst = 0.
    for w in np.linspace(.05, 4., 200):
        s = 1j*w
        outputs = []
        for d2, k2 in [(d2a, k2a), (d2b, k2b)]:
            outputs.append(h@np.linalg.inv(s*s*np.eye(2)+s*np.diag([d1, d2])
                                          +np.diag([k1, k2]))@g)
        worst = max(worst, float(np.max(abs(outputs[0]-outputs[1]))))
    assert worst == 0 and d2a != d2b and k2a != k2b
    results['invariance_is_not_identifiability'] = {
        'transfer_difference': worst, 'damping_spectra': [[d1, d2a], [d1, d2b]],
        'stiffness_spectra': [[k1, k2a], [k1, k2b]],
        'scope': '缺少可控/可观模态时的反例；不否定满秩双输入双输出的条件性正结论'}

    # 满秩、去嵌电路后的二阶 2x2 传递矩阵，逆矩阵多项式可构造谱不变量。
    d = .3*np.eye(2)+.04*axis(.12)
    k = 4.*np.eye(2)+.13*axis(-.4)
    h2 = np.array([[1.1, .09], [-.03, .9]])
    g2 = np.array([[.9, -.04], [.05, 1.2]])
    samples = 1j*np.array([.3, 1.1, 2.7])
    inverse_p = []
    for s in samples:
        p = h2@np.linalg.inv(s*s*np.eye(2)+s*d+k)@g2
        inverse_p.append(np.linalg.inv(p).reshape(4))
    b2, b1, b0 = np.linalg.solve(np.vander(samples, 3), np.array(inverse_p)).reshape(3, 2, 2)
    recovered_d = np.linalg.solve(b2, b1)
    recovered_k = np.linalg.solve(b2, b0)
    expected_d = h2@d@np.linalg.inv(h2)
    expected_k = h2@k@np.linalg.inv(h2)
    coefficient_error = float(max(np.max(abs(recovered_d-expected_d)),
                                  np.max(abs(recovered_k-expected_k))))
    assert coefficient_error < 1e-12
    dt = recovered_d-np.trace(recovered_d)/2*np.eye(2)
    kt = recovered_k-np.trace(recovered_k)/2*np.eye(2)
    cosine = np.trace(dt@kt)/(2*.04*.13)
    assert abs(cosine-math.cos(2*(.12+.4))) < 1e-12
    results['conditional_identifiable_invariants'] = {
        'inverse_polynomial_coefficient_error': coefficient_error,
        'damping_eigenvalues': np.linalg.eigvals(recovered_d).real.tolist(),
        'stiffness_eigenvalues': np.linalg.eigvals(recovered_k).real.tolist(),
        'cos_2_axis_difference': float(cosine.real),
        'scope': '理想满秩传递矩阵；不包含实际有噪声数据拟合或闭环辨识偏差'}

    fs, decimation, stages = 40000., 40, 3
    tau_cic = stages*(decimation-1)/(2*fs)
    tau_fir, tau_pipeline, tau_zoh = 2/1000, 3/1000, .5/1000
    tau = tau_cic+tau_fir+tau_pipeline+tau_zoh
    f45 = 45/(360*tau)
    f15 = 15/(360*tau)
    assert abs(tau-.0069625) < 1e-15 and f15 < f45
    results['delay_budget'] = {
        'cic_s': tau_cic, 'fir_s': tau_fir, 'pipeline_s': tau_pipeline,
        'zoh_low_frequency_equivalent_s': tau_zoh, 'total_s': tau,
        'frequency_if_45deg_allocated_Hz': f45,
        'frequency_if_15deg_allocated_Hz': f15,
        '100Hz_delay_limit_with_45deg_allocation_s': 45/(360*100),
        'scope': '旧链参数示例；频率为相位预算条件，不是普适闭环带宽上限'}

    # 只有 N 个开关状态不等于 N 个独立方程。
    independent = np.eye(4)
    duplicate = np.ones((4, 4))
    assert np.linalg.matrix_rank(independent) == 4 and np.linalg.matrix_rank(duplicate) == 1
    results['electrode_observation_rank'] = {
        'four_independent_patterns_rank': 4, 'four_duplicate_patterns_rank': 1,
        'scope': '仅针对已指定的线性端口组合参数，非同时辨识增益/相位/位置全部未知量'}

    # 5kHz 载波在 1kHz 更新点采样退化，不能据慢包络 DAC 接口直接证明驱动完整。
    fast = np.cos(2*np.pi*5000*np.arange(80)/40000)
    slow = np.cos(2*np.pi*5000*np.arange(20)/1000)
    assert np.max(abs(slow-1)) < 1e-12 and np.ptp(fast) > 1.9
    results['carrier_and_envelope_contract'] = {
        'slow_samples_deviation_from_DC': float(np.max(abs(slow-1))),
        'fast_samples_peak_to_peak': float(np.ptp(fast)),
        'scope': '采样反例；慢包络加外部模拟调制器仍可形成合法硬件架构'}

    # 文档层末级相位码量级，不能当作完整闭环死区。
    pattern_lsb = 90/2**24
    body_lsb = pattern_lsb/.277
    assert pattern_lsb < 6e-6 and body_lsb < 2e-5
    results['phase_code_resolution_deg'] = {'pattern': pattern_lsb, 'body_at_B_0_277': body_lsb}

    paths = [
        'DSH_md/06_对V2修订意见的可行性复核_20261102.md',
        'HRG_WA_simulink/piezo_v10/noise_research/sn_tick.m',
        'HRG_WA_simulink/piezo_v10/noise_research/sn_reference.m',
        'HRG_WA_simulink/piezo_v10/revision_v10_2_cn/pcn_plant.m']
    results['sources_sha256'] = {p: hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in paths}
    results['checks_passed'] = 6
    results['script_sha256'] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    results['limits'] = ['未运行新MATLAB闭环试验', '未做综合/STA', '未证明五项选题的新颖性',
                         '可辨识正结论依赖文中明确的满秩/二阶/去嵌条件']
    return results


if __name__ == '__main__':
    output = run()
    (HERE/'review_checks.json').write_bytes((json.dumps(output, ensure_ascii=False, indent=2)+'\n').encode())
    print(json.dumps(output, ensure_ascii=False, indent=2))
