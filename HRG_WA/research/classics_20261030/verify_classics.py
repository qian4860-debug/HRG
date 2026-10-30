"""Independent numerical checks of the scanned Lynch equations and derivations.

Only NumPy is required. Matrix complex dynamics, canonical scalar dynamics,
quadratic-signal derivatives and finite differences are separate routes.
No real-head or new Simulink-performance claim is made.
"""
from pathlib import Path
import json
import numpy as np

HERE=Path(__file__).resolve().parent
I=np.eye(2,dtype=complex)
J=np.array([[0.,-1.],[1.,0.]])
P1=np.array([[0.,1.],[1.,0.]],dtype=complex)
P2=np.array([[0.,-1j],[1j,0.]])
P3=np.diag([1.,-1.]).astype(complex)


def rot(x):
    c,s=np.cos(x),np.sin(x)
    return np.array([[c,-s],[s,c]])


def anis(x):
    return np.array([[np.cos(2*x),np.sin(2*x)],[np.sin(2*x),-np.cos(2*x)]])


def gamma(w,decay,damping,split,td,tw,k,omega,phidot):
    return decay*I+damping/2*anis(td)-1j*k*omega*P2-1j*phidot*I-1j*split/2*anis(tw)


def canonical(a,q,t,delta):
    return rot(t)@np.array([a,1j*q])*np.exp(1j*delta)


def measures(C):
    x,y=C
    return np.array([np.vdot(C,C),np.vdot(C,P2@C),np.vdot(C,P3@C),np.vdot(C,P1@C),x*x+y*y,x*x-y*y,2*x*y])


def slow(a,q,t,delta,F,w,decay,damping,split,td,tw,k,omega,phidot):
    """Expanded Eq35/38 route. F is in fixed pickoff coordinates."""
    fa,fq=rot(t).T@F*np.exp(-1j*delta)
    ua,va,uq,vq=fa.real,fa.imag,fq.real,fq.imag
    u,v=2*(t-td),2*(t-tw);D=a*a-q*q;E=a*a+q*q;Q=2*a*q
    ad=-(decay+damping/2*np.cos(u))*a+split/2*np.sin(v)*q-va/(2*w)
    qd=-(decay-damping/2*np.cos(u))*q-split/2*np.sin(v)*a+uq/(2*w)
    tdot=-k*omega+damping/2*np.sin(u)*E/D+split/2*np.cos(v)*Q/D+(-a*vq+q*ua)/(2*w*D)
    pprime=-damping/2*np.sin(u)*Q/D-split/2*np.cos(v)*E/D+(-a*ua+q*vq)/(2*w*D)
    ddot=phidot-pprime
    return np.array([ad,qd,tdot,ddot]),np.array([-2*decay*E-damping*np.cos(u)*D+(-a*va+q*uq)/w,
                                                -2*decay*Q-split*np.sin(v)*D+(a*uq-q*va)/w])


def main():
    tests={}
    def check(name,error,tol=1e-10):
        e=float(np.max(np.abs(error)))
        tests[name]=dict(max_abs_error=e,tolerance=tol,passed=bool(e<=tol))
    def true(name,condition):
        tests[name]=dict(passed=bool(condition))
    check('07_08_Pauli_squares',[np.max(abs(p@p-I)) for p in [P1,P2,P3]])
    check('08_all_six_Pauli_products',[np.max(abs(P1@P2-1j*P3)),np.max(abs(P2@P1+1j*P3)),
        np.max(abs(P2@P3-1j*P1)),np.max(abs(P3@P2+1j*P1)),np.max(abs(P3@P1-1j*P2)),np.max(abs(P1@P3+1j*P2))])
    check('07_rotation_generator',-1j*P2-J)
    rng=np.random.default_rng(19951030)
    errors={s:[] for s in ['02_rotation_inverse','03_stiffness_rotation','04_damping_rotation','10_scalar_vector_motion',
        '18_22_rotation_exponential','23_anisotropy_exponential','28_IQ_canonical_components','31_all_seven_quadratics',
        '31_quadratic_constraints','30_true_rotation_invariants','30_covariant_pairs','34_rotated_Gamma',
        '35_38_canonical_vs_complex_derivative','35_E_Q_chain_rule','38_independent_quadratic_derivatives',
        '37_two_by_two_elimination','39_signed_axis_recovery','46_expanded_real_forces','13_coherent_demodulation',
        'V10_positive_frequency_phasor_mapping']}
    for _ in range(128):
        a=rng.uniform(.5,2);q=a*rng.uniform(-.4,.4);t,delta,td,tw,eta=rng.uniform(-np.pi,np.pi,5)
        w=1000.;decay=.03;d=.02;h=.2;k=.6;om=.1;pd=.005
        R=rot(t);C=canonical(a,q,t,delta);F=rng.normal(size=2)+1j*rng.normal(size=2)
        errors['02_rotation_inverse'].append(np.max(abs(R.T@R-np.eye(2))))
        w1,w2=1000.2,999.8;wm=np.sqrt((w1*w1+w2*w2)/2);sp=(w1*w1-w2*w2)/(2*wm)
        errors['03_stiffness_rotation'].append(np.max(abs(rot(tw)@np.diag([w2*w2,w1*w1])@rot(tw).T-(wm*wm*np.eye(2)-wm*sp*anis(tw)))))
        errors['04_damping_rotation'].append(np.max(abs(rot(td)@np.diag([2*decay+d,2*decay-d])@rot(td).T-(2*decay*np.eye(2)+d*anis(td)))))
        z,vel=rng.normal(size=(2,2));omdot=.004;kp=.8
        vector=(2*decay*np.eye(2)+d*anis(td)+2*k*om*J)@vel+((w*w-kp*om*om)*np.eye(2)-w*h*anis(tw)+k*omdot*J)@z
        x,y=z;vx,vy=vel
        scalar=np.array([2*decay*vx+d*(vx*np.cos(2*td)+vy*np.sin(2*td))-2*k*om*vy+(w*w-kp*om*om)*x-w*h*(x*np.cos(2*tw)+y*np.sin(2*tw))-k*omdot*y,
                         2*decay*vy-d*(-vx*np.sin(2*td)+vy*np.cos(2*td))+2*k*om*vx+(w*w-kp*om*om)*y+w*h*(-x*np.sin(2*tw)+y*np.cos(2*tw))+k*omdot*x])
        errors['10_scalar_vector_motion'].append(np.max(abs(vector-scalar)))
        errors['18_22_rotation_exponential'].append(np.max(abs(np.cos(t)*I+1j*np.sin(t)*P2-rot(t).T)))
        errors['23_anisotropy_exponential'].append(np.max(abs(P3@(np.cos(2*t)*I+1j*np.sin(2*t)*P2)-anis(t))))
        c,s,cd,sd=np.cos(t),np.sin(t),np.cos(delta),np.sin(delta)
        explicit=np.array([a*c*cd+q*s*sd+1j*(a*c*sd-q*s*cd),a*s*cd-q*c*sd+1j*(a*s*sd+q*c*cd)])
        errors['28_IQ_canonical_components'].append(np.max(abs(C-explicit)))
        E,Q,D=a*a+q*q,2*a*q,a*a-q*q
        expected=np.array([E,Q,D*np.cos(2*t),D*np.sin(2*t),D*np.exp(2j*delta),
                           (E*np.cos(2*t)-1j*Q*np.sin(2*t))*np.exp(2j*delta),
                           (E*np.sin(2*t)+1j*Q*np.cos(2*t))*np.exp(2j*delta)])
        m=measures(C)
        errors['31_all_seven_quadratics'].append(np.max(abs(m-expected)))
        errors['31_quadratic_constraints'].append(max(abs(m[0]**2-m[1]**2-m[2]**2-m[3]**2),abs(m[4])**2-D*D,abs(m[5]**2+m[6]**2-m[4]**2)))
        mr=measures(rot(eta).T@C)
        errors['30_true_rotation_invariants'].append(np.max(abs(mr[[0,1,4]]-m[[0,1,4]])))
        errors['30_covariant_pairs'].append(max(np.max(abs(mr[[2,3]]-rot(2*eta).T@m[[2,3]])),np.max(abs(mr[[5,6]]-rot(2*eta).T@m[[5,6]]))))
        G=gamma(w,decay,d,h,td,tw,k,om,pd)
        Grot=(decay-1j*pd)*I+d/2*anis(td-t)+k*om*J-1j*h/2*anis(tw-t)
        errors['34_rotated_Gamma'].append(np.max(abs(R.T@G@R-Grot)))
        state_dot,eqdot=slow(a,q,t,delta,F,w,decay,d,h,td,tw,k,om,pd)
        ad,qd,thd,deld=state_dot
        zd=np.array([ad,1j*qd])+J@np.array([a,1j*q])*thd+1j*deld*np.array([a,1j*q])
        Cd=R@zd*np.exp(1j*delta)
        matrixCd=-G@C+1j*F/(2*w)
        errors['35_38_canonical_vs_complex_derivative'].append(np.max(abs(Cd-matrixCd)))
        errors['35_E_Q_chain_rule'].append(np.max(abs(eqdot-np.array([2*a*ad+2*q*qd,2*q*ad+2*a*qd]))))
        mdot=np.array([2*np.real(np.vdot(C,matrixCd)),
                       np.vdot(matrixCd,P2@C)+np.vdot(C,P2@matrixCd),
                       np.vdot(matrixCd,P3@C)+np.vdot(C,P3@matrixCd),
                       np.vdot(matrixCd,P1@C)+np.vdot(C,P1@matrixCd),2*np.dot(C,matrixCd)],dtype=complex)
        td2=(m[2]*mdot[3]-m[3]*mdot[2])/(2*(m[2]**2+m[3]**2))
        dd2=.5*np.imag(mdot[4]/m[4])
        errors['38_independent_quadratic_derivatives'].append(max(np.max(abs(mdot[:2]-eqdot)),abs(td2-thd),abs(dd2-deld)))
        fa,fq=rot(t).T@F*np.exp(-1j*delta);u,v=2*(t-td),2*(t-tw)
        rhs=np.array([d/2*a*np.sin(u)+h/2*q*np.cos(v)-fq.imag/(2*w),-h/2*a*np.cos(v)-d/2*q*np.sin(u)-fa.real/(2*w)])
        solved=np.linalg.solve(np.array([[a,q],[q,a]]),rhs)
        errors['37_two_by_two_elimination'].append(np.max(abs(solved-np.array([thd+k*om,pd-deld]))))
        recovered_a=np.sqrt((E+np.sqrt(E*E-Q*Q))/2);recovered_q=Q/(2*recovered_a)
        errors['39_signed_axis_recovery'].append(max(abs(recovered_a-a),abs(recovered_q-q)))
        fas,fqc,fqs=rng.normal(size=3);F=R@np.array([1j*fas,fqc+1j*fqs]);sdot,eqdot=slow(a,q,t,delta,F,w,decay,d,h,td,tw,k,om,pd)
        expected=np.array([-2*decay*E-d*np.cos(u)*D-a/w*fas*np.cos(delta)+q/w*(fqc*np.cos(delta)+fqs*np.sin(delta)),
                          -2*decay*Q-h*np.sin(v)*D+a/w*(fqc*np.cos(delta)+fqs*np.sin(delta))-q/w*fas*np.cos(delta),
                          -k*om+d/2*np.sin(u)*E/D+h/2*np.cos(v)*Q/D-a/(2*w*D)*(fqs*np.cos(delta)-fqc*np.sin(delta))+q/(2*w*D)*fas*np.sin(delta),
                          pd+h/2*np.cos(v)*E/D+d/2*np.sin(u)*Q/D+a/(2*w*D)*fas*np.sin(delta)-q/(2*w*D)*(fqs*np.cos(delta)-fqc*np.sin(delta))])
        errors['46_expanded_real_forces'].append(np.max(abs(expected-np.r_[eqdot,sdot[2:]])))
        phase=2*np.pi*np.arange(128)/128
        y=C.real[:,None]*np.cos(phase)+C.imag[:,None]*np.sin(phase)
        demod=2*np.mean(y*np.cos(phase),axis=1)+2j*np.mean(y*np.sin(phase),axis=1)
        errors['13_coherent_demodulation'].append(np.max(abs(demod-C)))
        H=.7*np.exp(-.2j);Cout=np.conj(H)*C
        positive_phasor=np.conj(Cout)/H
        errors['V10_positive_frequency_phasor_mapping'].append(np.max(abs(np.conj(positive_phasor)-C)))
    for name,es in errors.items():check(name,es,1e-8 if name in ['03_stiffness_rotation','10_scalar_vector_motion'] else 1e-10)

    # Exact differentiation before averaging; check every discarded term.
    discarded=[]
    for eps in [.02,.01,.005]:
        w=100.;k=.6;kp=.7;om=.8*eps*w;pd=.3*eps*w;omd=.4*eps*eps*w*w;pdd=.2*eps*eps*w*w
        Lam=.1*eps*w*I+.2*eps*w/2*anis(.3)+k*om*J
        C=np.array([.8+.3j,.4-.2j]);Cd=eps*w*np.array([.1+.4j,-.2+.5j]);Cdd=eps*eps*w*w*np.array([.3-.2j,.4+.1j]);h=.2*eps*w;nu=w+pd
        exact=Cdd+(2*Lam-2j*nu*I)@Cd+((w*w-nu*nu-kp*om*om)*I-1j*pdd*I-2j*nu*Lam-w*h*anis(.4)-1j*k*omd*P2)@C
        kept=-2j*w*Cd-2*w*pd*C-2j*w*Lam@C-w*h*anis(.4)@C
        rest=Cdd+2*Lam@Cd-2j*pd*Cd-1j*pdd*C-pd*pd*C-2j*pd*Lam@C-1j*k*omd*P2@C-kp*om*om*C
        check('16_full_derivative_remainder_eps_'+str(eps),exact-kept-rest,1e-10)
        discarded.append(float(np.linalg.norm(rest)))
    check('16_discarded_terms_second_order_scaling',np.array(discarded[:-1])/np.array(discarded[1:])-4,1e-10)
    C=np.array([1.,0.]);m=measures(C);mr=measures(rot(np.pi/4).T@C)
    true('30_R_S_individual_invariance_counterexample',abs(m[2]-mr[2])>.9)
    a,q=2.,-.2;E=a*a+q*q;Q=2*a*q;literal=np.sqrt((E-np.sqrt(E*E-Q*Q))/2)
    true('39_positive_root_loses_signed_Q',abs(2*a*literal-Q)>1)
    true('37_circle_singularity',np.linalg.det(np.array([[1.,1.],[1.,1.]]))==0)
    # Generator proof of energy conservation with stiffness split and rotation.
    C=np.array([.8+.1j,.4-.3j]);G=gamma(1000,0,0,.2,.3,.6,.6,.1,.02)
    check('38_unforced_lossless_E_conservation',2*np.real(np.vdot(C,-G@C)))
    # Eq40 is exactly the q=delta=0 limit, not a general decoupling theorem.
    a=1.3;w=1000.;td,tw,t=.2,.3,.7;ga,d,h,k,om,pd=.03,.02,.2,.6,.1,.005;fas,fqc,fqs=.3,-.4,.2
    sd,ed=slow(a,0,t,0,rot(t)@np.array([1j*fas,fqc+1j*fqs]),w,ga,d,h,td,tw,k,om,pd)
    expected=np.array([-(2*ga+d*np.cos(2*(t-td)))*a*a-a*fas/w,-h*np.sin(2*(t-tw))*a*a+a*fqc/w,
                       -k*om+d/2*np.sin(2*(t-td))-fqs/(2*w*a),pd+h/2*np.cos(2*(t-tw))])
    check('40_zero_short_axis_zero_phase_limit',np.r_[ed,sd[2:]]-expected)
    a0=1.;w=1000.;ga=.5;wn=5.;zeta=.7;b=a0/w;Kp=(2*zeta*wn-ga)/b;Ki=wn*wn/b;tauc=Kp/(2*Ki)
    check('42_local_PI_pole_matching',np.array([ga+b*Kp,b*Ki,tauc])-np.array([7.,25.,.13]))
    check('42_PI_zero_conversion',Kp/(2*tauc)-Ki)
    # Independent central finite difference of the energy-loop working point.
    E0=a0*a0;fs0=-2*ga*w*a0;de=1e-5
    fn=lambda E:-2*ga*E-np.sqrt(E)*fs0/w
    numerical=(fn(E0+de)-fn(E0-de))/(2*de)
    check('42_energy_linearization_is_gamma_not_2gamma',numerical+ga,1e-8)
    # Generic free solution: full carrier has sqrt(w²+(kΩ)²) frequency.
    w=10.;k=.7;om=.2
    dw1=np.sqrt(w*w+(k*om)**2)-w;dw2=np.sqrt(w*w+(k*om/2)**2)-w
    true('16_full_carrier_frequency_correction_is_second_order',abs(dw1/dw2-4)<.001)
    output=dict(synthetic_only=True,seed=19951030,random_cases=128,checks=tests,
                passed=sum(v['passed'] for v in tests.values()),total=len(tests),
                notes=['Positive-q and individual-invariance counterexamples confirm branch/wording limitations, not a repaired publication.',
                       'No real-head parameters, no claim of implemented new controller or complete Simulink/RTL verification.'])
    (HERE/'checks.json').write_text(json.dumps(output,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    failed=[k for k,v in tests.items() if not v['passed']]
    assert not failed,failed
    print('PASS:',len(tests),'Lynch derivation checks; 128 reproducible canonical/matrix comparisons')


if __name__=='__main__':main()
