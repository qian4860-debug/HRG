"""独立核对选题主张中的代数恒等式和反例；不代表新 RTL 或硬件已验收。"""
from fractions import Fraction
from pathlib import Path
import hashlib
import json
import math
import numpy as np

HERE = Path(__file__).resolve().parent


def rotation(phi):
    return np.array([[math.cos(phi), -math.sin(phi)],
                     [math.sin(phi), math.cos(phi)]])


def invariants(iq):
    ix, iy, qx, qy = iq
    energy = ix*ix + iy*iy + qx*qx + qy*qy
    area = ix*qy - iy*qx
    r = ix*ix + qx*qx - iy*iy - qy*qy
    s = 2*(ix*iy + qx*qy)
    return np.array([energy, area, r, s])


def run():
    rng = np.random.default_rng(20261102)
    results = {}
    # 同一系统在未知模态坐标缩放/旋转后的输入输出完全相同。
    j = np.array([[0., -1.], [1., 0.]])
    d = np.array([[.15, .02], [.02, .21]])
    k = np.array([[4., .03], [.03, 4.2]])
    g = np.array([[.9, -.02], [.05, 1.1]])
    h = np.array([[1.1, .08], [-.03, .9]])
    t = 1.7*rotation(.37)
    ti = np.linalg.inv(t)
    worst = 0.
    for input_scale in (0.2, 1., 3.):
        x = rng.normal(size=4)
        xp = np.r_[t@x[:2], t@x[2:]]
        ys, yps = [], []
        for idx in range(256):
            u = input_scale*rng.normal(size=2)
            omega = .3*math.sin(idx/30)
            ys.append(h@x[:2])
            yps.append((h@ti)@xp[:2])
            dx = np.r_[x[2:], g@u-k@x[:2]-(d+.4*omega*j)@x[2:]]
            dxp = np.r_[xp[2:], (t@g)@u-(t@k@ti)@xp[:2]
                        -(t@d@ti+.4*omega*j)@xp[2:]]
            x += .005*dx
            xp += .005*dxp
        error = np.linalg.norm(np.array(ys)-np.array(yps))/np.linalg.norm(ys)
        worst = max(worst, float(error))
    assert worst < 1e-12
    results['scaled_rotation_gauge_relative_output_error'] = worst

    # 一个采样的反馈延迟改变闭环特征多项式，即使载波相位已校准。
    delayed_poles = np.roots([1., -.8, .5])
    assert abs(max(abs(delayed_poles))-math.sqrt(.5)) < 1e-12
    results['delay_counterexample'] = {
        'original_pole': .8-.5,
        'delayed_poles_real_imag': [[float(z.real), float(z.imag)] for z in delayed_poles],
        'delayed_spectral_radius': float(max(abs(delayed_poles)))}

    old_fir, new_fir = [1, 2, 3, 2, 1], [1, 2, 4, 2, 1]
    assert sum(new_fir) == 10 and 10 & 9
    old_nyquist = sum(c*(-1)**i for i, c in enumerate(old_fir))/sum(old_fir)
    new_nyquist = sum(c*(-1)**i for i, c in enumerate(new_fir))/sum(new_fir)
    assert abs(old_nyquist-new_nyquist) > .08
    results['fir_change'] = {'old_sum': sum(old_fir), 'new_sum': sum(new_fir),
                             'old_nyquist_gain': old_nyquist, 'new_nyquist_gain': new_nyquist}

    divisor = 2**17-1
    r3 = sum((Fraction(1, 2**(17*n)) for n in (1, 2, 3)), Fraction())
    approx_product = divisor*r3
    assert approx_product < 1 and approx_product.numerator//approx_product.denominator == 0
    results['reciprocal_counterexample'] = {
        'n': divisor, 'exact_floor_quotient': 1, 'approx_floor_quotient': 0,
        'exact_product_minus_approx_product': str(1-approx_product),
        'scope': '反例针对先用截断倒数后向下取整；不宣称当前 RTL 最近舍入必在此输入失败'}

    iq_error = 0.
    for _ in range(256):
        iq = rng.normal(size=4)
        energy, area, r, s = invariants(iq)
        iq_error = max(iq_error, abs(r*r+s*s-(energy*energy-4*area*area))/energy**2)
    assert iq_error < 1e-12
    linear = invariants([1., 0., 0., 0.])
    circular = invariants([1/math.sqrt(2), 0., 0., 1/math.sqrt(2)])
    assert linear[1] == 0 and abs(np.linalg.norm(linear[2:])-linear[0]) < 1e-12
    assert abs(np.linalg.norm(circular[2:])) < 1e-12
    results['invariant_identity'] = {'max_relative_error': iq_error,
        'linear_E_L_R_S': linear.tolist(), 'circular_E_L_R_S': circular.tolist()}

    r, s, eps = .8, .6, 1e-6
    numerical = np.array([(math.atan2(s, r+eps)-math.atan2(s, r-eps))/(8*eps),
                          (math.atan2(s+eps, r)-math.atan2(s-eps, r))/(8*eps)])
    analytic = np.array([-s, r])/(4*(r*r+s*s))
    assert np.max(abs(numerical-analytic)) < 1e-9
    results['angle_jacobian_max_error'] = float(np.max(abs(numerical-analytic)))

    # 已经失配的同一对信号仅做数字旋转，再还原角度，偏差不变。
    worst = 0.
    for beta in np.linspace(-.6, .6, 31):
        y = np.diag([1.1, .9])@np.array([math.cos(2*beta), math.sin(2*beta)])
        base = math.atan2(y[1], y[0])/2
        for alpha in np.arange(4)*math.pi/8:
            yr = rotation(-2*alpha)@y
            reconstructed = math.atan2(yr[1], yr[0])/2+alpha
            # 四倍角相位比较，避免不同支路的角度包装。
            worst = max(worst, abs(np.exp(4j*reconstructed)-np.exp(4j*base)))
    assert worst < 1e-12
    factors = [abs(np.mean(np.exp(-4j*m*np.arange(4)*math.pi/8))) for m in range(1, 5)]
    assert max(factors[:3]) < 1e-12 and abs(factors[3]-1) < 1e-12
    results['commutation'] = {'digital_rotation_bias_invariance': float(worst),
                              'ideal_four_view_harmonic_factors_m1_to_m4': [float(x) for x in factors]}

    # E,L,R,S 丢失公共载波相位；不能单独重建 FTR 所需的完整状态。
    iq = np.array([.8, .3, .07, -.04])
    z = iq[:2] + 1j*iq[2:]
    zr = z*np.exp(.71j)
    phase_error = float(np.max(abs(invariants(iq)-invariants(np.r_[zr.real, zr.imag]))))
    assert phase_error < 1e-12 and np.linalg.norm(z-zr) > .1
    results['common_carrier_phase_invariance_error'] = phase_error

    # 两种模式测同一未知速率，不会自动产生绝对尺度/零偏参考。
    omega = np.linspace(-2, 2, 101)
    scales, biases, a, c = np.array([1.03, .97]), np.array([.02, -.03]), 1.4, .17
    before = scales[:, None]*omega+biases[:, None]
    after = (scales/a)[:, None]*(a*omega+c)+(biases-scales*c/a)[:, None]
    affine_error = float(np.max(abs(before-after)))
    assert affine_error < 1e-12
    results['dual_mode_absolute_calibration_gauge_error'] = affine_error
    results['checks_passed'] = 10
    results['scope'] = '代数反例与局部恒等式核验；不是完整可辨识性证明、RTL 等价证明或新颖性鉴定'
    results['script_sha256'] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    return results


if __name__ == '__main__':
    output = run()
    (HERE/'audit_results.json').write_bytes((json.dumps(output, ensure_ascii=False, indent=2)+'\n').encode('utf-8'))
    print(json.dumps(output, ensure_ascii=False, indent=2))
