"""Independent algebra and coherent-RF counterexamples for source equations.

This is an isolated ADC/geometry oracle, not a closed-loop gyro qualification.
"""
from pathlib import Path
import json
import numpy as np

ROOT=Path(__file__).resolve().parents[1]

def main():
    e=ROOT/'evidence';e.mkdir(parents=True,exist_ok=True);checks=[];examples={}
    def check(name,error,limit):
        checks.append(dict(name=name,error=float(error),limit=float(limit),pass_=bool(error<=limit)))
    # Eq(7): theta=0, Fa=1, Fq=0 must yield x=1,y=0. The two printed
    # expanded rows both multiply Fa by sin(2 theta), hence yield zero.
    correct=np.array([1.,0.]);printed=np.array([0.,0.])
    examples['source_eq7']=dict(theta_rad=0,Fa=1,Fq=0,matrix_result=correct.tolist(),printed_expansion=printed.tolist())
    check('source_eq7_counterexample_is_nonzero',abs(np.linalg.norm(correct-printed)-1),1e-14)
    # Eq(6) returns K*a, K*q unless the IQ normalization K=k0*Aref/2=1.
    K=3.;a=2.;q=.2;energy=K*K*(a*a+q*q);quad=2*K*K*a*q
    reported=(np.sqrt(energy+quad)+np.sqrt(energy-quad))/2
    check('physical_amplitude_requires_inverse_K',abs(reported/K-a),1e-14)
    examples['source_eq6']=dict(K=K,physical_amplitude=a,printed_result=float(reported))
    # Voltage-domain ADC error must not receive the preceding transducer gain again.
    phase=np.arange(8000)*2*np.pi/8;ex=.01*np.cos(phase);Aref=2.;k0=3.
    actual=np.mean(Aref*ex*np.cos(phase));printed=k0*actual
    check('voltage_error_demodulation',abs(actual-.01),1e-13)
    examples['source_eq10']=dict(k0=k0,Aref=Aref,error_voltage_peak=.01,
        correct_IQ_error=float(actual),printed_IQ_error=float(printed))
    # Hu/Gallacher author manuscript Eq(17): substituting a cubic measurement
    # into a single cubic subtraction leaves O(rho^4), not only O(rho^8).
    rho=.1;cubic=.75;t=cubic*rho*rho;measured=rho*(1+t)
    subtracted=measured-cubic*measured**3
    exact_relative=-3*t*t-3*t**3-t**4
    check('single_cubic_subtraction_residual_expansion',abs((subtracted/rho-1)-exact_relative),1e-15)
    examples['Hu_manuscript_eq17']=dict(rho=rho,actual_relative_residual=float(subtracted/rho-1),
        printed_relative_residual=-cubic**4*rho**8,
        boundary='Equation checked in the locally supplied author manuscript; published-version equation not asserted identical')
    # Positive cubic: Newton initialized at r stays between the true root and r.
    # If t=beta*r^2<=.05, E0<=t, E(n+1)<=3*t*E(n)^2;
    # three iterations give E3<=2187*t^15, before floating-point roundoff.
    maximum=0.;samples=0
    for beta in (0.,.001,.0048,.02,.2):
        a=np.linspace(0,1.5,3001);r=a+beta*a**3;mask=beta*r*r<=.05
        a=a[mask];r=r[mask];estimate=r.copy()
        for _ in range(3):estimate-=(estimate+beta*estimate**3-r)/(1+3*beta*estimate**2)
        maximum=max(maximum,float(np.max(abs(estimate-a))));samples+=len(a)
    check('three_Newton_steps_in_declared_small_cubic_region',maximum,2e-15)
    examples['Newton_simplification']=dict(gate='beta*r^2 <= 0.05',samples=samples,
        maximum_absolute_error=maximum,analytic_relative_bound=2187*.05**15,
        boundary='Three iterations only inside this gate; retain the original fallback outside it')
    # Symmetric ADCs plus identical coherent windows have C4 symmetry in the
    # modal x/y plane. In physical azimuth theta that means pi/4 periodicity.
    N=4096;theta=(np.arange(N)+.314)*np.pi/N
    carrier=np.arange(40)*2*np.pi/8+.173;amplitude=.2;step=4/2**10
    x=amplitude*np.cos(2*theta[:,None])*np.cos(carrier)
    y=amplitude*np.sin(2*theta[:,None])*np.cos(carrier)
    xq=np.clip(np.round(x/step)*step,-2,2-step);yq=np.clip(np.round(y/step)*step,-2,2-step)
    cx=2*np.mean(xq*np.cos(carrier),axis=1);cy=2*np.mean(yq*np.cos(carrier),axis=1)
    sx=2*np.mean(xq*np.sin(carrier),axis=1);sy=2*np.mean(yq*np.sin(carrier),axis=1)
    R=cx*cx+sx*sx-cy*cy-sy*sy;S=2*(cx*cy+sx*sy)
    error=.25*np.angle((R+1j*S)*np.exp(-4j*theta))
    periodic=np.max(np.abs(error-np.roll(error,N//4)))
    def harmonic(k):return float(2*abs(np.mean(error*np.exp(-1j*k*theta))))
    a4=harmonic(4);a8=harmonic(8)
    check('equal_channel_RF_quantizer_pi_over_4_symmetry',periodic,1e-12)
    check('four_theta_term_is_not_mandatory',a4,1e-12)
    assert np.max(np.abs(error))>1e-5 and a8>1e-7
    examples['RF_quantization']=dict(fs_hz=40000,f0_hz=5000,window_samples=40,bits=10,
        full_scale_peak_v=2,signal_peak_v=amplitude,peak_physical_pattern_error_rad=float(np.max(np.abs(error))),
        four_theta_amplitude_rad=a4,eight_theta_amplitude_rad=a8,
        interpretation='The angular weights in a first-order Jacobian do not imply a universal pure 4-theta error. This symmetric coherent example has 8-theta symmetry.')
    # For isotropic IQ noise and q=0, squared Jacobian norm is independent of azimuth.
    variance=(np.sin(2*theta)**2+np.cos(2*theta)**2)/(4*amplitude**2)
    check('isotropic_IQ_noise_variance_independent_of_theta',np.max(abs(variance-1/(4*amplitude**2))),1e-12)
    window=np.array([[1.,0.],[2**-.5,2**-.5]])
    eigen=np.linalg.eigvalsh(window.T@window)
    check('TDM_two_sample_Gram_eigenvalues',np.max(abs(eigen-np.array([1-2**-.5,1+2**-.5]))),1e-14)
    check('TDM_one_guarded_sample_is_rank_one',abs(np.linalg.matrix_rank(window[1:])-1),0)
    examples['TDM_window']=dict(eigenvalues=eigen.tolist(),condition_number=float(eigen[-1]/eigen[0]),
        samples_per_detection_window=2,rank_after_one_sample_guard=1,
        boundary='Illustrative four-slot schedule at 8 ADC samples per carrier cycle; not a validation of the paper hardware')
    # An isotropic stiffness must retain omega0^2 I. Dead-area paper PDF4
    # Eq(8), as printed, cancels stiffness at beta=0, omega_x=omega_y.
    omega=2*np.pi*5000;mass=1e-6;gap=5e-6;quality=2e6;cap=1e-12;bias=10.
    printed_stiffness=omega**2-((omega**2+omega**2)/2)
    check('dead_area_printed_stiffness_isotropic_counterexample',abs(printed_stiffness),0)
    examples['dead_area_eq8']=dict(omega0_squared=omega**2,printed_x_stiffness_per_mass=printed_stiffness,
        boundary='Rendered local PDF4 equation; not a claim about the authors simulation code')
    # Independent eigenvalue derivation of the double-frequency pump threshold.
    gamma=omega/(2*quality);vcrit=mass*omega**2*gap**2/(4*quality*cap*bias)
    delta=8*cap*bias*vcrit/(mass*gap**2)
    matrix=np.array([[-gamma,delta/(4*omega)],[delta/(4*omega),-gamma]])
    check('parametric_threshold_has_zero_growth_eigenvalue',abs(max(np.linalg.eigvalsh(matrix))),1e-14)
    examples['parametric_pump']=dict(critical_voltage_v=vcrit,critical_delta_per_s2=delta,
        damping_per_s=gamma,growth_eigenvalues_per_s=np.linalg.eigvalsh(matrix).tolist(),
        boundary='Eight identical electrodes, small signal, resonant ideal pump; not implemented in the carrier model')
    np.savetxt(e/'coherent_adc_azimuth.csv',np.column_stack((theta,error)),delimiter=',',header='physical_pattern_azimuth_rad,error_rad',comments='')
    result=dict(date='2026-10-24',checks=checks,examples=examples,pass_=all(x['pass_'] for x in checks),
                boundary='Printed-equation tests and isolated RF ADC test; no claim of reproducing the source closed-loop simulation')
    (e/'quantization_audit.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    print(json.dumps(result,ensure_ascii=True));assert result['pass_']

if __name__=='__main__':main()
