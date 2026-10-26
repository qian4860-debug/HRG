"""Independent numeric checks for the academic/intuitive HRG derivation.

These check equations and synthetic counterexamples, not a new Simulink run.
"""
from pathlib import Path
import hashlib
import json
import numpy as np

HERE=Path(__file__).resolve().parent
REPO=HERE.parents[1]

def main():
    checks=[];examples={}
    def check(name,error,limit):
        checks.append(dict(name=name,error=float(error),limit=float(limit),pass_=bool(np.isfinite(error) and error<=limit)))
    B=.277;w=2*np.pi*5000;mass=1e-6;gap=5e-6;cap=1e-12;bias=10.
    # C and force derivatives share the same electrode reference plane.
    q=.03*gap;h=1e-5*gap
    C=lambda x:cap/(1-x/gap)
    gradient=cap/gap/(1-q/gap)**2
    check('capacitor_gradient_vs_finite_difference',abs((C(q+h)-C(q-h))/(2*h)/gradient-1),1e-8)
    force=.5*bias*bias*gradient
    examples['electrode']=dict(gradient_F_per_m=gradient,force_N=force)
    # Measured geometric angle for diagonal sensing gains.
    theta=np.linspace(0,np.pi,4096,endpoint=False)+.00013;r=1.0001
    cx=np.cos(2*theta);cy=r*np.sin(2*theta)
    R=cx*cx-cy*cy;S=2*cx*cy
    error=.25*np.angle((R+1j*S)*np.exp(-4j*theta))
    first=(r-1)*np.sin(4*theta)/4
    check('gain_angle_first_order_remainder',np.max(abs(error-first)),2e-9)
    dt=1e-6
    phase=lambda t:.5*np.unwrap(np.angle(np.cos(2*t)+1j*r*np.sin(2*t)))
    derivative=(phase(theta+dt)-phase(theta-dt))/(2*dt)
    exact=r/(np.cos(2*theta)**2+r*r*np.sin(2*theta)**2)
    check('gain_exact_angle_jacobian',np.max(abs(derivative-exact)),1e-9)
    examples['gain']=dict(ratio_error=1e-4,peak_inertial_angle_error_rad=float(np.max(abs(error))/B),
        first_order_peak_rad=1e-4/(4*B),residual_gain_for_1urad=4*B*1e-6)
    # An uncalibrated energy derivative contains a gain/angle-velocity term.
    eps=.01;r=1+eps;theta_dot=-B*80*np.pi/180
    g=np.cos(2*theta)**2+r*r*np.sin(2*theta)**2
    gp=2*(r*r-1)*np.sin(4*theta)
    gamma=w/(2*2e6);dgamma=.00025
    true_loss=gamma+.5*dgamma*np.cos(4*theta)
    apparent=true_loss-.5*gp/g*theta_dot
    X=np.column_stack((np.ones_like(theta),np.cos(4*theta),np.sin(4*theta)))
    bad=np.linalg.lstsq(X,apparent,rcond=None)[0]
    good=np.linalg.lstsq(X,true_loss,rcond=None)[0]
    check('corrected_energy_recovers_damping',np.max(abs(good-[gamma,.5*dgamma,0])),1e-14)
    examples['false_damping']=dict(true_anisotropic_coefficient_per_s=.5*dgamma,
        uncalibrated_fitted_sine_per_s=float(bad[2]),first_order_false_sine_per_s=-2*eps*theta_dot,
        ratio_to_true_anisotropy=abs(float(bad[2]))/(.5*dgamma))
    # Common absolute-state scaling leaves the full input-output model unchanged.
    Ds=np.array([[1.1,.02],[-.01,.95]]);Da=np.array([[.9,.03],[.02,1.05]])
    A=np.array([[-.008,.12],[-.12,-.007]]);T=1.3*np.eye(2)
    Dsp=Ds@np.linalg.inv(T);Ap=T@A@np.linalg.inv(T);Dap=T@Da
    check('state_scaling_input_output_indistinguishability',max(np.max(abs(Ds@A@np.linalg.inv(Ds)-Dsp@Ap@np.linalg.inv(Dsp))),np.max(abs(Ds@Da-Dsp@Dap))),1e-14)
    # Voltage changes the anisotropy VECTOR linearly in V^2, not its norm.
    voltage=np.array([5.,7.,9.,11.]);a0=np.array([800.,-600.]);a2=np.array([-11.,8.])
    recovered=[]
    for V in voltage:
        u,v=a0+a2*V*V
        Kn=w*w*np.eye(2)+np.array([[u,v],[v,-u]])
        lam,U=np.linalg.eigh(Kn);axis=.5*np.arctan2(U[1,-1],U[0,-1])
        d=(lam[-1]-lam[0])/2
        recovered.append(d*np.array([np.cos(4*axis),np.sin(4*axis)]))
    fit=np.linalg.lstsq(np.column_stack((np.ones_like(voltage),voltage**2)),np.array(recovered),rcond=None)[0]
    check('voltage_squared_vector_fit_recovers_structure_and_electrode',np.max(abs(fit-np.stack((a0,a2)))),1e-5)
    examples['bias_sweep']=dict(voltage_V=voltage.tolist(),recovered_intercept_per_s2=fit[0].tolist(),
        recovered_slope_per_s2_V2=fit[1].tolist(),boundary='Synthetic fixed-shape mass-normalized model; not a unique reconstruction of mass distribution')
    # Reference-bias bookkeeping: do not subtract the same spring twice.
    wrong=np.sqrt(w*w-np.array([20.,12.])*100)/(2*np.pi)
    examples['double_counted_spring']=dict(reference_voltage_V=10,correct_frequencies_Hz=[5000,5000],
        wrong_frequencies_Hz=wrong.tolist(),false_split_Hz=float(abs(wrong[0]-wrong[1])))
    # A differential readout phase creates false quadrature at first order,
    # but pure standing-wave angle distortion only at second order.
    delta=.001;zx=np.cos(2*theta);zy=np.sin(2*theta)*np.exp(1j*delta)
    R=abs(zx)**2-abs(zy)**2;S=2*np.real(np.conj(zx)*zy)
    pe=.25*np.angle((R+1j*S)*np.exp(-4j*theta))
    check('differential_phase_static_angle_is_second_order',np.max(abs(pe+delta**2/16*np.sin(8*theta))),2e-13)
    quad=2*np.imag(np.conj(zx)*zy)
    check('differential_phase_false_quadrature',np.max(abs(quad-np.sin(4*theta)*np.sin(delta))),1e-14)
    split=.002;omega_error=2*np.pi*split;phase=np.pi/180
    rate_bias=omega_error*phase/(4*B)
    target=.1*np.pi/180/3600
    allowance=4*B*target/omega_error
    examples['phase_budget']=dict(split_Hz=split,residual_phase_deg=1,
        worst_rate_bias_deg_h=rate_bias*180/np.pi*3600,
        phase_allowance_for_point1deg_h_rad=allowance,
        equivalent_residual_delay_s=allowance/w,
        boundary='Quadrature force estimated from stiffness split; maximum spatial factor, small phase; equivalent residual loop delay, not raw ADC jitter')
    # Fundamental of a cubic displacement detector gives an 8-theta term
    # when theta is the physical n=2 rim angle.
    rho=.002;eta=.75*rho*rho;nx=np.cos(2*theta);ny=np.sin(2*theta)
    dx=nx*(1+eta*nx*nx);dy=ny*(1+eta*ny*ny)
    err=.25*np.angle(((dx*dx-dy*dy)+2j*dx*dy)*np.exp(-4j*theta))
    predicted=-3*rho*rho/32*np.sin(8*theta)
    check('cubic_sensing_physical_eight_theta_error',np.max(abs(err-predicted)),2e-12)
    # White-noise RMS plus deterministic spatial RMS: an illustrative objective,
    # not a declaration that deterministic error is white noise.
    rho0=.02;noise0=10e-6;calibration_fraction=.01
    nonlinear0=calibration_fraction*3*rho0*rho0/(32*B*np.sqrt(2))
    tstar=(noise0**2/(2*nonlinear0**2))**(1/6)
    objective=lambda t:(noise0/t)**2+(nonlinear0*t*t)**2
    grid=np.linspace(.5,4,10001);best=grid[np.argmin(objective(grid))]
    check('amplitude_tradeoff_stationary_point_vs_grid',abs(best-tstar),.00036)
    examples['amplitude_tradeoff']=dict(assumed_noise_at_rho_point02_rad=noise0,
        assumed_fractional_cubic_calibration_error=calibration_fraction,
        optimum_rho=float(rho0*tstar),optimum_amplitude_m=float(gap*rho0*tstar),
        combined_objective_RMS_rad=float(np.sqrt(objective(tstar))),
        boundary='Illustrative unconstrained spatial-RMS objective; not actual-head optimum or actual AFE performance')
    Vpk=.18740046286145592;fs=40000;Be=100;target_angle=1e-6
    bits=int(np.ceil(np.log2(4/(2*B*Vpk*target_angle)*np.sqrt(Be/(3*fs)))))
    eqnoise=4/2**18/np.sqrt(6*fs)
    rms=eqnoise*np.sqrt(2*Be)/(2*B*Vpk)
    check('ADC_two_white_noise_forms_agree',abs(rms-(4/2**18)/(2*B*Vpk)*np.sqrt(Be/(3*fs))),1e-18)
    examples['ADC']=dict(white_18bit_angle_RMS_rad=rms,ADC_only_ideal_lower_bound_bits=bits,
        total_voltage_noise_allowance_V_sqrtHz=2*B*Vpk*target_angle/np.sqrt(2*Be))
    zeta=.8;wn=2*np.pi*.8;E0=1;kp=zeta*wn/E0;ki=wn*wn/(2*E0)
    poles=np.roots([1,2*E0*kp,2*E0*ki])
    check('energy_PI_target_natural_frequency',abs(abs(poles[0])-wn),1e-12)
    examples['energy_PI']=dict(kp=kp,ki=ki,poles_real=np.real(poles).tolist(),poles_imag=np.imag(poles).tolist())
    # Cheng PDF6 Eq(6) has adot=-gamma*a+A/(2 omega). Its PDF11
    # A-channel expression introduces another a unless redefinition is supplied.
    a=2.;omega=10.;decay=.01
    correct=2*omega*decay*a;printed=2*a*omega*decay*a
    check('FTR_amplitude_equilibrium_rederived',abs(-decay*a+correct/(2*omega)),1e-14)
    examples['source_equilibrium_counterexample']=dict(a=a,omega=omega,decay=decay,
        correct_A=correct,printed_A_if_same_definition=printed,
        nonzero_adot_if_printed_used=-decay*a+printed/(2*omega),
        boundary='Only the displayed amplitude-channel equations under the same definitions; not the authors implementation')
    preserved={}
    for name in ('literature_v7','literature_v8_research','literature_zotero_research'):
        p=REPO/'HRG_WA_simulink'/name/'evidence/manifest.json'
        manifest=json.loads(p.read_text(encoding='utf-8-sig'))
        hashes=manifest.get('sha256')
        if hashes is None:
            # V7 uses a list of path/hash objects; defer its own read-only verifier.
            import subprocess,sys
            receipt=json.loads(subprocess.run([sys.executable,str(p.parents[1]/'tools/verify.py')],capture_output=True,text=True,check=True).stdout)
            preserved[name]=receipt['hashes'];continue
        for relative,expected in hashes.items():
            assert hashlib.sha256((REPO/relative).read_bytes()).hexdigest()==expected,relative
        preserved[name]=len(hashes)
    result=dict(date='2026-10-26',checks=checks,examples=examples,preserved=preserved,
        pass_=all(c['pass_'] for c in checks),boundary='Independent equation tests and synthetic examples; no new RF, Simulink, hardware or long-term noise validation')
    save=HERE/'derivation_checks.json';save.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    print(json.dumps(result,ensure_ascii=True));assert result['pass_']

if __name__=='__main__':main()
