"""Independent algebra and ideal-physics checks for the piezo derivation.

Synthetic assumptions only. No measured-head or complete closed-loop claim.
"""
from pathlib import Path
import json, math
import numpy as np

OUT=Path(__file__).resolve().parent
checks=[]
def check(name,ok,**evidence):
    checks.append(dict(name=name,pass_=bool(ok),**evidence))
    assert ok,name

def main():
    rng=np.random.default_rng(20261029)
    J=np.array([[0.,-1.],[1.,0.]])
    m=1e-4; f=5000.;w=2*math.pi*f;Q=1e6;a=1e-6;theta=1e-5;C=1e-9
    k=m*w*w;c=m*w/Q;gamma=c/(2*m)
    values=dict(m_kg=m,f_Hz=f,omega_rad_s=w,Q=Q,amplitude_m=a,
        stiffness_N_m=k,damping_Ns_m=c,amplitude_tau_s=1/gamma,
        energy_J=.5*m*w*w*a*a,hold_force_N=c*w*a,hold_voltage_V=c*w*a/theta,
        P01_Q_from_nominal_f_and_tau=math.pi*126000*23)
    check('amplitude_and_energy_decay',np.isclose(np.exp(-2*gamma*.7),np.exp(-gamma*.7)**2))
    v=rng.normal(size=(100,2))
    check('gyroscopic_force_does_no_work',np.max(abs(np.einsum('bi,ij,bj->b',v,J,v)))<1e-12)
    # Independent quadrature of hemisphere mode integrals versus polynomial antiderivatives.
    th=np.linspace(0,np.pi/2,20001);tt=np.tan(th/2)**2
    U=V=-tt*np.sin(th);W=(2+np.cos(th))*tt
    num=-2*np.trapezoid(V*(U*np.cos(th)+W*np.sin(th))*np.sin(th),th)
    den=np.trapezoid((U*U+V*V+W*W)*np.sin(th),th)
    na=32*math.log(2)-64/3;da=20*math.log(2)-37/3
    check('hemisphere_gyro_integral_vs_antiderivative',abs(num-na)<1e-8)
    check('hemisphere_modal_mass_integral_vs_antiderivative',abs(den-da)<2e-8)
    values.update(ideal_hemisphere_N=na,ideal_hemisphere_D=da,ideal_hemisphere_B=na/da/2)
    # Rigid z-translation: u=-A sin(theta), w=A cos(theta), v=0.
    # Both membrane normal strains must vanish, including the radial metric term.
    th=np.linspace(.01,np.pi/2,100);AA=.2
    u=-AA*np.sin(th);du=-AA*np.cos(th);ww=AA*np.cos(th)
    check('sphere_rigid_translation_zero_membrane_strain',np.max(abs(du+ww))<1e-12 and np.max(abs(u/np.tan(th)+ww))<1e-12)
    C0=1e-9
    for G in [0.,1e-12,1e-9,1e-6,1.,1e12]:
        dz=theta**2*1j*w/(G+1j*w*C0)
        dk=theta**2*w*w*C0/(G*G+w*w*C0*C0)
        dc=theta**2*G/(G*G+w*w*C0*C0)
        check('passive_load_'+str(G),np.allclose(dz,dk+1j*w*dc,rtol=1e-12,atol=1e-18) and dc>=0)
    check('open_circuit_stiffness',np.isclose((theta**2*1j*w/(1j*w*C0)).real,theta**2/C0))
    s=1j*w*.93;Y=s*C0+s*theta**2/(m*s*s+c*s+k)
    Lm=m/theta**2;Rm=c/theta**2;Cm=theta**2/k
    check('BVD_admittance',abs(Y-(s*C0+1/(s*Lm+Rm+1/(s*Cm))))<1e-15)
    lam=3.7
    Y2=s*C0+s*(lam*theta)**2/(lam**2*(m*s*s+c*s+k))
    check('impedance_scale_nonidentifiability',abs(Y-Y2)<1e-15)
    for _ in range(100):
        aa=rng.uniform(.1,2);bb=rng.uniform(-.09,.09);alpha=rng.uniform(-3,3);phase=rng.uniform(-3,3)
        e=np.array([np.cos(alpha),np.sin(alpha)]);ep=J@e
        # Changing carrier phase must leave ellipse invariants unchanged.
        I=aa*e*np.cos(phase)+bb*ep*np.sin(phase)
        QQ=-aa*e*np.sin(phase)+bb*ep*np.cos(phase)
        E=I@I+QQ@QQ;U=I[0]**2+QQ[0]**2-I[1]**2-QQ[1]**2
        V=2*(I[0]*I[1]+QQ[0]*QQ[1]);L=I[0]*QQ[1]-I[1]*QQ[0]
        assert np.allclose([E,U,V,L],[aa**2+bb**2,(aa**2-bb**2)*np.cos(2*alpha),(aa**2-bb**2)*np.sin(2*alpha),aa*bb])
        assert abs(E*E-U*U-V*V-4*L*L)<1e-12
    check('ellipse_invariants_and_common_carrier_phase_100_cases',True)
    # Hessian of a single generating enthalpy gives reciprocal mixed coupling.
    Th=np.array([[1e-5,2e-6],[-3e-6,8e-6]])
    q=np.array([.7e-6,-.3e-6]);vv=np.array([.1,-.2]);eps=1e-8
    H=lambda q,v:.5*k*(q@q)-q@Th@v-.5*C0*(v@v)
    grad=np.array([(H(q+eps*np.eye(2)[i],vv)-H(q-eps*np.eye(2)[i],vv))/(2*eps) for i in range(2)])
    check('enthalpy_mechanical_derivative',np.allclose(grad,k*q-Th@vv,rtol=1e-8))
    # Counterexample verified against the printed P05/P13 conditions.
    sig1=sig2=-1.;sigp=1.
    printed=np.sign(sig1)*np.sign(sigp) if np.sign(sig1)==np.sign(sigp) else 0
    original=np.sign(sig1)*np.sign(sigp) if np.sign(sig1)==np.sign(sig2) else 0
    check('P05_printed_beta_cannot_represent_negative_case',printed==0 and original==-1)
    eig=np.linalg.eigvalsh(np.array([[3.,2.],[2.,-1.]]))
    check('principal_stress_characteristic_equation',np.allclose(eig,[1-math.sqrt(8),1+math.sqrt(8)]))
    # Independent carrier ODE integration versus exact rotating-frame solution.
    # ddq +2gOmega J dq +w0^2 q=0, constant Omega, no damping.
    w0=2*math.pi*100;g=.6;Omega=.3;dt=1e-4;steps=10000
    state=np.r_[1.,0.,-g*Omega*(J@np.array([1.,0.]))]
    def rhs(y):return np.r_[y[2:],-w0*w0*y[:2]-2*g*Omega*(J@y[2:])]
    for _ in range(steps):
        k1=rhs(state);k2=rhs(state+dt*k1/2);k3=rhs(state+dt*k2/2);k4=rhs(state+dt*k3)
        state+=dt*(k1+2*k2+2*k3+k4)/6
    t=steps*dt;al=-g*Omega*t
    expected=np.array([math.cos(al),math.sin(al)])*math.cos(math.sqrt(w0*w0+(g*Omega)**2)*t)
    err=float(np.linalg.norm(state[:2]-expected))
    check('carrier_ODE_vs_exact_rotating_frame',err<1e-5,position_error=err,step_s=dt,steps=steps)
    Psi_sigma=math.radians(.001);n=2;B=.3;Vs=.1
    values.update(output_noise_rms_V=n*B*Vs*Psi_sigma,
        output_noise_density_V_sqrtHz=n*B*Vs*Psi_sigma/math.sqrt(10),
        residual_gain_match=2*n*B*Psi_sigma,
        conservative_static_ADC_bits=math.ceil(math.log2(2/(math.sqrt(12)*1e-6))))
    result=dict(scope='Synthetic algebra, passivity and ideal ODE checks only; not piezo head, Simulink or RTL acceptance',
        values=values,checks=checks,all_passed=all(x['pass_'] for x in checks))
    (OUT/'formula_checks.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(len(checks),'checks passed')

if __name__=='__main__':main()
