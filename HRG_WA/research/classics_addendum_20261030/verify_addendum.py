"""Independent matrix, energy, numerical integral and counterexample checks.

Synthetic checks validate mathematics, not the unidentified physical HRG.
No PDF text or rendered pages are copied into the release.
"""
from pathlib import Path
import json
import math
import numpy as np

HERE = Path(__file__).resolve().parent
J = np.array([[0., -1.], [1., 0.]])


def run():
    checks = {}
    def check(name, error, tolerance=1e-10):
        error = float(error)
        checks[name] = dict(error=error, tolerance=tolerance, passed=bool(error <= tolerance))
        assert checks[name]['passed'], (name, error, tolerance)

    rng = np.random.default_rng(20261030)
    es = []
    # Recover slow rates from force, then reconstruct both carrier coefficients.
    for _ in range(256):
        a = rng.uniform(.5, 2); b = rng.uniform(-.4, .4)*a
        t = rng.uniform(-np.pi, np.pi); v = np.array([np.cos(t),np.sin(t)]); w=J@v
        fc, fs = rng.normal(size=(2,2)); mass=.7; om=3.1
        adot=-v@fs/(2*mass*om); bdot=w@fc/(2*mass*om)
        dw,td=np.linalg.solve([[a,b],[b,a]],[-v@fc/(2*mass*om),v@J@fs/(2*mass*om)])
        rc=-2*om*(a*dw+b*td)*v+2*om*bdot*w
        rs=-2*om*adot*v-2*om*(b*dw+a*td)*w
        es.append(np.max(abs(np.r_[rc-fc/mass,rs-fs/mass])))
    check('R05_256_force_projection_reconstruction', max(es))
    check('R05_circle_determinant_zero', abs(np.linalg.det([[1,1],[1,1]])))
    # Exact differentiation of a linearly varying envelope; first-order residual
    # error must decrease quadratically as all slow rates decrease.
    def remainder(eps):
        a,b,t,phi=1.2,.2,.7,.9
        da,db,dt,dw=np.array([.3,-.2,.4,.1])*eps; om=4.
        v=np.array([np.cos(t),np.sin(t)]); w=J@v
        p=a*v; q=b*w; dp=da*v+a*dt*w; dq=db*w-b*dt*v
        ddp=2*da*dt*w-a*dt**2*v; ddq=-2*db*dt*v-b*dt**2*w
        exact=(ddp+2*(om+dw)*dq-((om+dw)**2-om**2)*p)*np.cos(phi)+(ddq-2*(om+dw)*dp-((om+dw)**2-om**2)*q)*np.sin(phi)
        first=(-2*om*(a*dw+b*dt)*v+2*om*db*w)*np.cos(phi)+(-2*om*da*v-2*om*(b*dw+a*dt)*w)*np.sin(phi)
        return np.linalg.norm(exact-first)
    ratio=remainder(.02)/remainder(.01)
    check('R04_first_order_remainder_quadratic',abs(ratio-4),1e-8)
    v=np.array([1.,0.]); fs=np.array([0.,-2.])
    check('R08_printed_minus_counterexample_correct_plus',abs(v@J@fs/2-1))
    check('R08_printed_minus_is_not_equal',float(abs(v@J@fs/2+1)<1))
    # Small positive parallel restoring control must raise exact eigenfrequency.
    om=100.; cr=.001
    shift=math.sqrt(om**2+2*om*cr)-om
    check('R16_frequency_control_positive_from_exact_spring',abs(shift-cr),1e-8)
    es=[]
    for _ in range(256):
        t=rng.uniform(-3,3); v=np.array([np.cos(t),np.sin(t)]); w=J@v
        u,z,dc,ds=rng.normal(size=4); om=20.; gamma=.4
        H=om/2*np.array([[u,z],[z,-u]]); G=gamma*(np.eye(2)+np.array([[dc,ds],[ds,-dc]]))
        h=om/2*math.hypot(u,z); th=math.atan2(z,u)/2
        d=gamma*math.hypot(dc,ds); tg=math.atan2(ds,dc)/2
        es.append(max(abs(v@H@v-h*np.cos(2*(t-th))),abs(-w@H@v-h*np.sin(2*(t-th))),abs(v@G@v-(gamma+d*np.cos(2*(t-tg)))),abs(-w@G@v-d*np.sin(2*(t-tg)))))
    check('R16_R17_256_matrix_vs_harmonic_projections',max(es))
    v=np.ones(2)/np.sqrt(2); w=J@v
    check('R16_damping_positive_rotation_counterexample',abs(-w@np.diag([2.,1.])@v-.5))
    check('R16_quadrature_positive_counterexample',abs(-w@np.diag([1.,-1.])@v-1))
    H=np.array([[0.,1.],[1.,0.]])
    good=np.array([1.,1.])/np.sqrt(2); bad=np.array([0.,1.])
    check('R17_half_angle_eigenaxis',np.linalg.norm(H@good-good))
    check('R17_missing_half_angle_rejected',float(np.linalg.norm(H@bad-bad)<1))
    # Pure energy balance, independently from projection equations.
    p=2*np.pi*np.arange(10000)/10000; mass=.4; a=1.3; om=8.; ca=.12
    power=np.mean((-2*mass*a*om*ca*np.sin(p))*(-a*om*np.sin(p)))
    check('R09_average_power_amplitude_growth',abs(power-mass*a*a*om*om*ca))
    A=np.array([[1.2,.04],[-.03,.8]]); B=np.array([[.8,-.01],[.02,1.1]])
    M=np.array([[1.,2.],[3.,4.]]); eta=rng.normal(size=2)
    check('R20_similarity_direct_identity',np.max(abs(A@(M@eta)-(A@M@np.linalg.inv(A))@(A@eta))))
    check('R20_scale_gauge_same_AB',np.max(abs(A@B-(3*A)@(B/3))))
    check('R20_scale_gauge_same_similarity',np.max(abs(A@M@np.linalg.inv(A)-(3*A)@M@np.linalg.inv(3*A))))
    Ad=np.diag([1.2,.8]); C=Ad@J@np.linalg.inv(Ad); r=1.5
    check('R21_skew_symmetric_decomposition',np.max(abs(C-((r+1/r)/2*J+(1/r-r)/2*np.array([[0,1],[1,0]])))))
    t=.73; v=np.array([np.cos(t),np.sin(t)]); w=J@v; z=A@v; dz=A@w
    cross=(z[0]*dz[1]-z[1]*dz[0])/(z@z)
    check('R22_exact_angle_derivative_determinant',abs(cross-np.linalg.det(A)/(z@z)))
    Ac=np.linalg.inv(A); Bc=np.linalg.inv(B)
    check('R23_compensation_order',max(np.max(abs(Ac@A-np.eye(2))),np.max(abs(B@Bc-np.eye(2)))))
    t=np.pi*np.arange(65536)/65536
    b=np.sin(2*t); rho=.2
    mean=np.mean(b/(1+rho*b))/np.mean(1/(1+rho*b))
    check('R26_uniform_angle_bias_zero',abs(np.mean(b)))
    check('R26_nonuniform_time_bias_nonzero',float(abs(mean)<.09))
    gamma,d,h=.3,.01,.6; t0,t1,p0,p1=.0001,.0003,.0002,.0004; tg,tt,tp,th=.2,-.1,.7,-.3
    bias=d*np.sin(2*(t-tg))+(t0+t1*np.cos(2*(t-tt)))*(gamma+d*np.cos(2*(t-tg)))+(p0+p1*np.cos(2*(t-tp)))*h*np.sin(2*(t-th))
    dc=t0*gamma+t1*d/2*np.cos(2*(tg-tt))+p1*h/2*np.sin(2*(tp-th))
    check('R30_numerical_integral_vs_product_DC',abs(np.mean(bias)-dc))
    s,r=.02,2.; meanb=float(np.mean(bias))
    check('R29_equal_reversal_cancels_scale',abs(((s*r-meanb)+(-s*r-meanb))/2+meanb))
    sp,sm=.021,.019
    check('R29_drift_residual_survives',abs(((sp*r-meanb)+(-sm*r-meanb))/2+meanb-(sp-sm)*r/2))
    c=np.linspace(-.1,.1,51); y=.7-c/(1+s)
    slope=np.linalg.lstsq(np.c_[np.ones(len(c)),c],y,rcond=None)[0][1]
    check('R31_slope_inverse',abs(-1/slope-1-s))
    Z=np.array([[1+.2j,.1+.3j],[-.2+.1j,.9-.1j]])
    check('R35_ordinary_transpose_not_adjoint',float(np.linalg.norm(Z.T/(1+s)-Z.conj().T/(1+s))<.1))
    check('J03_Q_time_constant_numeric',abs((np.pi*1e4/1e7)*180/np.pi-.18))
    check('J04_full_vs_half_frequency_two',abs((2*np.pi*.0005)/(np.pi*.0005)-2))
    x=1e4*1e3/(10*(1e3**2-1e4**2)); inverseq=.001/(2*np.pi)*np.arctan(x)
    check('J08_literal_negative_loss_counterexample',float(inverseq>=0))
    check('J09_exact_vs_approx_budget',abs(180*1e4*(1e-7+1.6e-6)-3.06))
    # Passive coupled support: imaginary Schur complement vs positive formula.
    errors=[]; minloss=float('inf')
    for w2 in np.geomspace(.1,10,100):
        w1=1.; m1=2.; m2=3.; kappa=.02; q2=10.; c2=m2*w2/q2
        dk=-kappa**2*w1**4/(m2*(w2*w2-w1*w1)+1j*w1*c2)
        loss=dk.imag/(m1*w1*w1); mu=kappa*kappa/(m1*m2)
        formula=mu*w1**3*w2/q2/((w2*w2-w1*w1)**2+(w1*w2/q2)**2)
        errors.append(abs(loss-formula)); minloss=min(minloss,loss)
    check('J_support_passive_schur_vs_formula',max(errors))
    check('J_support_nonnegative_loss',max(0.,-minloss))
    # General ellipse: derive S from four I/Q coordinates, recover a,b,theta.
    a,b,theta,phase=1.2,-.2,.61,.8
    R=np.array([[np.cos(theta),-np.sin(theta)],[np.sin(theta),np.cos(theta)]])
    P=R@np.diag([a,b])@np.array([[np.cos(phase),-np.sin(phase)],[np.sin(phase),np.cos(phase)]])
    S=P@P.T; N=S[0,0]-S[1,1]; M=2*S[0,1]; D=np.hypot(N,M)
    check('Z04_quadratic_matrix_reconstruction',np.max(abs(S-R@np.diag([a*a,b*b])@R.T)))
    check('Z04_angle_and_axes',max(abs(.5*np.arctan2(M,N)-theta),abs((np.trace(S)+D)/2-a*a),abs(np.linalg.det(P)-a*b)))
    psi=.7; dk=.2; om=3.; a=1.4
    pump=np.mean((-dk*np.cos(2*p+psi)*a*np.cos(p))*(-a*om*np.sin(p)))
    check('Z05_parametric_power_integral',abs(pump+dk*a*a*om*np.sin(psi)/4))
    direct=np.mean(np.cos(2*p+psi)*np.sin(p))
    check('Z05_linear_piezo_2f_no_fundamental_power',abs(direct))
    check('Z06_thermal_frequency_0p1C',abs(7500*84e-6*.1-.063))
    check('Z07_table_ratios',max(abs(0.014/.001-14),abs(.00060/.00006-10),abs(100/1-100)))
    # Finite-difference measurement-angle derivative versus analytic gradient.
    N,M=1.3,.8; dN,dM=.2,-.1; e=1e-6
    finite=(np.arctan2(M+e*dM,N+e*dN)-np.arctan2(M-e*dM,N-e*dN))/(8*e)
    check('Z04_beta_noise_gradient',abs(finite-(N*dM-M*dN)/(4*(N*N+M*M))),1e-9)
    report=dict(seed=20261030,random_cases=512,total=len(checks),passed=sum(c['passed'] for c in checks.values()),
                checks=checks,diagnostics=dict(nonuniform_time_bias=mean,product_DC=dc,printed_support_inverse_Q=inverseq,slow_remainder_ratio=ratio),
                boundary='Synthetic algebra and quadrature checks, including rejection of literal inconsistent print; no hardware validation')
    (HERE/'checks.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    print(f"PASS {report['passed']}/{report['total']} independent checks")


if __name__=='__main__':run()
