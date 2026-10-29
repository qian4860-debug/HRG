"""Independent, deliberately small counterexamples for the V10 design review.

No plant/controller duplication. These checks validate mathematical examples,
not the proposed future implementation or real head performance.
"""
from pathlib import Path
import json
import numpy as np

HERE = Path(__file__).resolve().parent


def theta(c):
    ix, iy, qx, qy = np.asarray(c).T
    u = ix * ix + qx * qx - iy * iy - qy * qy
    v = 2 * (ix * iy + qx * qy)
    return np.arctan2(v, u) / 4


def delta(a, b):
    return np.angle(np.exp(4j * (a - b))) / 4


def main():
    results = {}
    values = {}
    c = np.array([.8, .5, -.04, .07])
    ix, iy, qx, qy = c
    u = ix**2 + qx**2 - iy**2 - qy**2
    v = 2 * (ix * iy + qx * qy)
    du = 2 * np.array([ix, -iy, qx, -qy])
    dv = 2 * np.array([iy, ix, qy, qx])
    gradient = (u * dv - v * du) / (4 * (u * u + v * v))
    h = 1e-6
    fd = np.array([(theta(c + h * np.eye(4)[i]) - theta(c - h * np.eye(4)[i])) / (2 * h) for i in range(4)])
    results['angle_jacobian_finite_difference'] = bool(np.max(np.abs(fd - gradient)) < 1e-9)

    grid = np.arange(2048) * np.pi / (2 * 2048)
    e = 1e-5
    c = np.c_[np.cos(2 * grid), (1 + e) * np.sin(2 * grid), np.zeros((len(grid), 2))]
    gain_error = delta(theta(c), grid)
    predicted = e / 4 * np.sin(4 * grid)
    results['detection_gain_first_order'] = bool(np.max(np.abs(gain_error - predicted)) < e * e)
    B = .27699096196168066
    values['gain_residual_for_0001deg_carrier_angle_ppm'] = 4 * B * np.deg2rad(.001) * 1e6

    # Q=a is a circular orbit: nonzero energy cannot provide a unique angle.
    u = 1**2 + 0**2 - 0**2 - 1**2
    v = 2 * (1 * 0 + 0 * 1)
    results['finite_energy_can_have_undefined_pattern_angle'] = (u == 0 and v == 0)

    # Matched symmetric quantizers, fixed coherent carrier: NOT universal 4theta.
    phase = 2 * np.pi * np.arange(40) / 40
    amp, step = .1, 2 / 2**12
    y = amp * np.c_[np.cos(2 * grid), np.sin(2 * grid)][:, :, None] * np.cos(phase)
    yq = np.round(y / step) * step
    iq = 2 * np.mean(yq * np.cos(phase), axis=2)
    err = delta(theta(np.c_[iq, np.zeros_like(iq)]), grid)
    spectrum = np.abs(np.fft.rfft(err)) * 2 / len(grid)
    values['coherent_quantizer_4theta_rad'] = float(spectrum[1])
    values['coherent_quantizer_8theta_rad'] = float(spectrum[2])
    values['coherent_quantizer_max_error_rad'] = float(np.max(np.abs(err)))
    results['fourth_harmonic_is_not_universal'] = bool(spectrum[1] < 1e-10 and np.max(spectrum[2:]) > 1e-6)
    residual = (yq[37, 0] - y[37, 0])
    results['coherent_quantizer_error_repeats_each_carrier_period'] = bool(np.var(residual) > 0)
    # Explicit second period, not an assumption of independent white samples.
    phase2 = 2 * np.pi * np.arange(80) / 40
    x = .1 * np.cos(phase2 + .17)
    eq = np.round(x / step) * step - x
    results['coherent_quantizer_error_repeats_each_carrier_period'] &= bool(np.max(np.abs(eq[:40] - eq[40:])) < 1e-14)

    # TDM, referenced to the earlier X observation: delay Y by dt.
    d = 1e-5  # physical standing-wave angle accumulated between X and Y
    c = np.c_[np.cos(2 * grid), np.sin(2 * (grid + d)), np.zeros((len(grid), 2))]
    tdm = delta(theta(c), grid)
    predicted = d / 2 * (1 + np.cos(4 * grid))
    results['tdm_first_order_against_exact_samples'] = bool(np.max(np.abs(tdm - predicted)) < 3 * d**2)
    values['tdm_error_at_X_axis_rad'] = float(tdm[0])
    values['tdm_error_at_Y_axis_rad'] = float(tdm[len(grid) // 2])
    results['tdm_X_and_Y_axes_are_not_equivalent_with_fixed_Y_delay'] = bool(abs(tdm[0]) > .99 * d and abs(tdm[len(grid)//2]) < d**2)

    # Printed Yan Eq.(7) has identical expanded rows. Test a simple basis vector.
    rotation = np.eye(2)  # theta = 0
    correct = rotation @ np.array([1., 0.])
    literal_printed = np.array([0., 0.])  # Fa cosine only, printed sin(2theta)
    results['printed_force_expansion_counterexample'] = bool(not np.allclose(correct, literal_printed))

    # Piezo port loading: exact complex force impedance vs stiffness+damping.
    w, cs, rs, th = 2*np.pi*1000, 1e-9, 1e5, 1e-5
    g = 1 / rs
    z = th**2 * 1j*w / (g + 1j*w*cs)
    dk = th**2 * w*w*cs / (g*g+(w*cs)**2)
    dc = th**2 * g / (g*g+(w*cs)**2)
    results['piezo_load_stiffness_and_damping'] = bool(abs(z - (dk+1j*w*dc)) < 1e-14)
    values['Rs100k_added_amplitude_decay_s_inv'] = dc / (2*1e-4)

    # Electrical IO invariance of two physical heads under scale change.
    s = 1j*2*np.pi*np.array([900., 1000., 1100.]);m,ts,td = 1e-4,1e-5,2e-5
    mechanical = s*s + 2*.3*s + (2*np.pi*1000)**2
    Y1 = s*cs + s*(ts*ts/m)/mechanical
    Y2 = s*cs + s*((3*ts)**2/(9*m))/mechanical
    F1 = s*(ts*td/m)/mechanical
    F2 = s*((3*ts)*(3*td)/(9*m))/mechanical
    results['mass_coupling_not_separately_identifiable_from_electrical_IO'] = bool(np.allclose(Y1,Y2,rtol=1e-13,atol=0) and np.allclose(F1,F2,rtol=1e-13,atol=0))

    # Low-speed damping lock: theta_dot=-B*Omega+damp*sin(4theta).
    damp = .001
    omega = .5*damp/B
    equilibrium = (np.pi-np.arcsin(B*omega/damp))/4
    results['low_rate_damping_stable_fixed_point_exists'] = bool(abs(-B*omega+damp*np.sin(4*equilibrium))<1e-15 and 4*damp*np.cos(4*equilibrium)<0)

    # Existing DAC arithmetic can emit one code beyond signed positive rail.
    step = 2/2**18
    emitted = np.round(np.clip(1.,-1.,1.)/step)*step
    top = 1-step
    results['existing_DAC_positive_rail_counterexample_confirmed'] = bool(emitted > top)
    values['signed_18bit_DAC_top_V'] = top
    values['existing_DAC_at_vmax_V'] = emitted
    values['ideal_white_20bit_block_carrier_sigma_deg'] = float(np.rad2deg((2/2**20)/(.1*B*np.sqrt(24*40))))
    output = dict(synthetic_only=True,checks=results,values=values,
                  boundary='Analytical examples and confirmed limitations, not validation of future algorithms; full V10 latency uses a separate MATLAB audit.')
    (HERE/'formula_audit.json').write_text(json.dumps(output,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    assert all(results.values()),results
    print('PASS:',len(results),'independent review examples')
    print(json.dumps(values,ensure_ascii=False,indent=2))


if __name__ == '__main__':
    main()
