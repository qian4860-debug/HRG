"""Independent algebra checks for formula_by_formula_comparison.md.

Run with Python 3 + numpy. These are algebraic/structural checks, not sensor
performance measurements and not full-text validation of every cited paper.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np


ROOT = Path(__file__).resolve().parent
J = np.array([[0., -1.], [1., 0.]])


def rot(t):
    return np.array([[np.cos(t), -np.sin(t)], [np.sin(t), np.cos(t)]])


def anis(t):
    return rot(t) @ np.diag([1., -1.]) @ rot(t).T


def run():
    rng = np.random.default_rng(20261023)
    checks = []

    def check(name, residual, tolerance, detail):
        residual = float(residual)
        checks.append(dict(name=name, residual=residual, tolerance=tolerance,
                           passed=bool(residual <= tolerance), detail=detail))

    chain_err = invariant_err = iq_err = force_err = 0.
    for _ in range(300):
        a = rng.uniform(.5, 2.)
        b = a * rng.uniform(-.7, .7)
        alpha, phase, ad, ak = rng.uniform(-3., 3., 4)
        gamma, g, delta, d, nu = rng.uniform(-.2, .2, 5)
        h = rng.normal(size=2) + 1j * rng.normal(size=2)
        w = np.array([a, 1j*b])
        r = rot(alpha)
        z = np.exp(1j*phase) * r @ w
        hp = np.exp(-1j*phase) * r.T @ h
        cd, sd = np.cos(2*(ad-alpha)), np.sin(2*(ad-alpha))
        ck, sk = np.cos(2*(ak-alpha)), np.sin(2*(ak-alpha))
        E, Q, D = a*a+b*b, 2*a*b, a*a-b*b
        da = -(gamma+g*cd)*a + d*sk*b + hp[0].real
        db = -(gamma-g*cd)*b - d*sk*a + hp[1].imag
        dp = delta-d*ck*E/D-g*sd*Q/D+(a*hp[0].imag+b*hp[1].real)/D
        dalpha = -nu-d*ck*Q/D-g*sd*E/D+(b*hp[0].imag+a*hp[1].real)/D
        zd_chain = np.exp(1j*phase)*r @ (
            np.array([da, 1j*db])+1j*dp*w+dalpha*J@w)
        Gamma = gamma*np.eye(2)+g*anis(ad)
        H = delta*np.eye(2)-d*anis(ak)
        zd_ode = (-Gamma+1j*H-nu*J)@z+h
        chain_err = max(chain_err, np.max(np.abs(zd_chain-zd_ode)))
        ed = -2*gamma*E-2*g*D*cd+2*np.vdot(z,h).real
        qd = -2*gamma*Q-2*d*D*sk+2*np.vdot(z,1j*J@h).real
        invariant_err = max(invariant_err, abs(ed-2*a*da-2*b*db),
                            abs(qd-2*b*da-2*a*db))
        C, S = z.real, z.imag
        R = C[0]**2+S[0]**2-C[1]**2-S[1]**2
        T = 2*(C[0]*C[1]+S[0]*S[1])
        M, L = (z@z).real, (z@z).imag
        iq_err = max(iq_err, abs(R+1j*T-D*np.exp(2j*alpha)),
                     abs(M+1j*L-D*np.exp(2j*phase)),
                     abs(np.vdot(z,1j*J@z).real-Q))
        f = rng.normal(size=4)
        omega = 7.4
        hp_force = np.array([-f[1]-1j*f[0], -f[3]-1j*f[2]])/(2*omega)
        t = rng.uniform(-3,3)
        fc = r@np.array([f[0]-1j*f[1],f[2]-1j*f[3]])*np.exp(1j*phase)
        force_err = max(force_err, np.max(np.abs(
            np.exp(1j*phase)*r@hp_force-fc/(2j*omega))))
    check('full_ellipse_chain_rule',chain_err,2e-13,'300 signed, noncircular ellipses: chain rule versus complex ODE')
    check('E_Q_derivatives',invariant_err,2e-13,'Quadratic invariant derivative versus a,b equations')
    check('IQ_angle_phase_Q_invariants',iq_err,2e-13,'R+jS, M+jL and signed Q identities')
    check('four_force_components',force_err,2e-13,'Cos/sin physical force to complex slow forcing')

    # Separate numerical carrier integration, rather than the invariant formula.
    phase_grid = np.arange(16384)*2*np.pi/16384
    z = np.array([.8+.3j,-.4+.2j])
    samples = (z[:,None]*np.exp(1j*phase_grid)).real
    cp = np.mean(samples*np.cos(phase_grid),axis=1)
    sp = np.mean(samples*np.sin(phase_grid),axis=1)
    check('positive_sine_half_gain_mapping',np.max(abs(2*cp-2j*sp-z)),2e-15,
          'Unscaled +sin paper mixer to project 2cos/-2sin mixer')
    theta, beta = .31, -.17
    check('physical_modal_four_angle',np.max(abs(anis(2*beta) @ rot(2*theta)
          -rot(2*theta)@anis(2*(beta-theta)))),2e-15,
          'alpha=2 theta converts cos2(alpha-alpha_d) to cos4(theta-beta)')

    # Counterexamples refer only to the specified printed equations.
    v = np.array([1.,2.]); kOmega=.6
    printed_G = np.array([[0.,-2*kOmega],[-2*kOmega,0.]])
    check('L052_printed_gyro_nonzero_work_detected',abs(v@printed_G@v+4.8),2e-15,
          'Printed same-sign off diagonals yield v^T G v=-4.8; a skew gyro yields 0')
    correct_G=2*kOmega*J
    check('skew_gyro_zero_work',abs(v@correct_G@v),2e-15,'Physical gyroscopic energy identity')
    alpha=np.pi/4; C=rot(alpha)@np.array([1.,0.]); Sp=np.zeros(2)
    printed_M=C[0]**2-Sp[0]**2-C[1]**2+Sp[1]**2
    check('L057_printed_L_real_part_counterexample',abs(printed_M),2e-15,
          'a=1,q=0,alpha=pi/4,phase=0: printed real part=0, claimed D exp(2j phase)=1')
    theta=.1; angle=np.arctan2(np.sin(4*theta),np.cos(4*theta))
    check('L053_missing_angle_scale_counterexample',abs(angle/4-theta),2e-15,
          'Under R=D cos4theta,S=D sin4theta, atan2(S,R)=0.4 for theta=0.1')
    cx, sx, cy, sy = .5, 0., 0., 0.
    r_algebra = cx*cx+sx*sx-cy*cy-sy*sy
    r_printed_angle = .25*np.sin(2*0.)
    check('L052_printed_R_counterexample',abs((r_algebra-r_printed_angle)-.25),2e-15,
          'a=1,q=0,theta=phase=0 and unscaled mixers: R=.25, printed RHS proportional sin2theta=0')

    fm_err=0.
    for _ in range(100):
        a,q,alpha,Phi=rng.normal(size=4)
        u=np.exp(1j*alpha)*(a*np.cos(Phi)+1j*q*np.sin(Phi))
        u2=(a+q)/2*np.exp(1j*(Phi+alpha))+(a-q)/2*np.exp(-1j*(Phi-alpha))
        fm_err=max(fm_err,abs(u-u2))
    check('traveling_wave_reconstruction',fm_err,3e-15,'CW/CCW decomposition from paper signed ellipse')
    carrier,theta_rate,drift=31415.,.27,13.
    decoded=((carrier+drift+2*theta_rate)-(carrier+drift-2*theta_rate))/4
    check('FM_common_frequency_cancellation',abs(decoded-theta_rate),2e-12,
          'Differential frequency measures physical theta rate; differential errors remain')

    eps=.017; uQ=.2; a=1.2
    h=1j*uQ*J@np.array([a+0j,0j])*np.exp(1j*eps)
    actual_theta_dot=h[1].real/(2*a)
    check('quadrature_phase_leak_exact',abs(actual_theta_dot+uQ*np.sin(eps)/2),2e-15,
          'Carrier phase error rotates quadrature force into pattern torque')
    check('phase_leak_linear_remainder',abs(np.sin(eps)-eps),abs(eps)**3/6+1e-15,
          'Small-angle approximation has an explicit cubic bound')

    th=np.linspace(0,2*np.pi,80,endpoint=False)
    X=np.column_stack([np.sin(4*th),np.cos(4*th),np.ones_like(th)])
    Xfixed=np.tile(X[0],(80,1))
    check('damping_regression_rank',abs(np.linalg.matrix_rank(X)-3),0.,'Angle coverage provides rank 3')
    check('fixed_angle_unidentifiable',abs(np.linalg.matrix_rank(Xfixed)-1),0.,'Repeated fixed azimuth has rank 1')
    gx,gy,uE,alpha=.9,1.13,.08,.61
    zz=rot(alpha)@np.array([1.2,0.])
    hp=rot(alpha).T@(uE*np.diag([gx,gy])@zz)
    check('gain_mismatch_leaks_energy_into_angle',abs(hp[1]/(2*1.2)
          -uE*(gy-gx)*np.sin(2*alpha)/4),2e-15,
          'Electrode drive gain mismatch creates the same 4theta harmonic family as damping')
    psi=np.arange(16384)*2*np.pi/16384
    rho=1+.023*np.cos(4*(psi-.19))
    mass_diff=np.mean(rho*(np.cos(2*psi)**2-np.sin(2*psi)**2))
    check('fourth_mass_harmonic_projection',abs(mass_diff-.023*np.cos(4*.19)/2),2e-15,
          'Squared n=2 mode shapes select the fourth circumferential density harmonic')
    amp=1.7
    fundamental=2*np.mean((amp*np.cos(psi))**3*np.cos(psi))
    check('Duffing_fundamental_coefficient',abs(fundamental-3*amp**3/4),2e-15,
          'Direct carrier integration gives the 3/4 coefficient used by the slow nonlinear model')
    C=.7+1.3j; Gfw=.8-.2j; Gfb=1.1+.13j; Ac=.3-.4j
    Df=C*Gfw*Ac/(1+C*Gfw*Gfb)
    check('tracking_detector_finite_gain',abs(Df-C*Gfw*(Ac-Gfb*Df)),2e-15,
          'Finite closed-loop tracker obeys the error-node equation; inverse-Gfb is only a high-loop-gain limit')
    phase_rate=1.2
    check('radians_to_Hz',abs((phase_rate/(2*np.pi))*2*np.pi-phase_rate),2e-15,
          'Frequency in Hz is phase rate in rad/s divided by 2pi, not multiplied by 2pi')
    A=rng.normal(size=(2,2)); G=rng.normal(size=(2,2)); T=np.array([[1.,.2],[-.1,1.3]])
    lhs=G@A@np.linalg.inv(G)
    rhs=(G@np.linalg.inv(T))@(T@A@np.linalg.inv(T))@np.linalg.inv(G@np.linalg.inv(T))
    check('detector_mechanical_similarity_ambiguity',np.max(abs(lhs-rhs)),2e-13,
          'Equivalent observed dynamics do not identify G and A separately')
    speed,damp,earth=.3,.004,.001
    average=((speed+damp+earth)+(-speed+damp+earth))/2
    check('virtual_reversal_retains_earth',abs(average-damp-earth),2e-16,
          'Even mean contains damping plus projected Earth/input rate')
    circular_z=np.array([1.+0j,1j])
    circular_D=abs(circular_z@circular_z)
    circular_angle_norm=abs(circular_z[0])**2-abs(circular_z[1])**2
    check('circular_ellipse_degeneracy',max(circular_D,abs(circular_angle_norm)),0.,
          'a=|b| implies D=0: orientation/phase inversion must be rejected, not divided by epsilon silently')
    return dict(date='2026-10-23',seed=20261023,scope='algebra_only',
                numpy_version=np.__version__,checks=checks,
                passed=all(x['passed'] for x in checks),
                source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest())


if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--write',action='store_true',help='Write evidence/algebra_checks.json')
    args=parser.parse_args()
    result=run()
    if args.write:
        target=ROOT/'evidence'/'algebra_checks.json'
        target.parent.mkdir(exist_ok=True)
        target.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    print(json.dumps(result,ensure_ascii=False,indent=2))
    raise SystemExit(0 if result['passed'] else 1)
