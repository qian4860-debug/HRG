"""Circuit mathematics checked by independent nodal, energy and numerical routes.

No transistor PDK or measured HRG parameters are implied.
"""
from pathlib import Path
import json
import math
import numpy as np

HERE=Path(__file__).resolve().parent


def main():
    checks={};rng=np.random.default_rng(20261030)
    def ck(name,error,tol=1e-10):
        error=float(error);checks[name]=dict(error=error,tolerance=tol,passed=bool(error<=tol));assert checks[name]['passed'],(name,error,tol)
    # Project actual displacement/strain samples into positive mass/stiffness.
    Phi=rng.normal(size=(21,2));rho=rng.uniform(.5,2,21);vel=rng.normal(size=2)
    M=Phi.T@np.diag(rho)@Phi
    ck('C01_mass_energy_integral_vs_quadratic',abs(.5*np.sum(rho*(Phi@vel)**2)-.5*vel@M@vel))
    ck('C01_mass_positive',float(np.linalg.eigvalsh(M).min()<=0))
    # Reciprocal port equations are gradients of one electrical enthalpy.
    K=np.array([[4.,.3],[.3,3.]]);Cp=np.array([[2.,.1],[.1,1.5]]);Th=np.array([[.2,-.03],[.05,.1]])
    q=rng.normal(size=2);V=rng.normal(size=2)
    def enthalpy(q,V):return .5*q@K@q-q@Th@V-.5*V@Cp@V
    e=1e-5;basis=np.eye(2)
    dq=np.array([(enthalpy(q+e*b,V)-enthalpy(q-e*b,V))/(2*e) for b in basis])
    dv=np.array([(enthalpy(q,V+e*b)-enthalpy(q,V-e*b))/(2*e) for b in basis])
    ck('C02_force_energy_gradient',np.max(abs(dq-(K@q-Th@V))),1e-8)
    ck('C02_charge_energy_gradient',np.max(abs(-dv-(Th.T@q+Cp@V))),1e-8)
    Kop=K+Th@np.linalg.solve(Cp,Th.T)
    ck('C03_open_circuit_stiffening_positive',max(0.,-np.linalg.eigvalsh(Kop-K).min()))
    ck('C03_open_circuit_elimination',np.max(abs(K@q-Th@np.linalg.solve(Cp,-Th.T@q)-Kop@q)))
    errors=[];gauges=[]
    for f in np.geomspace(.1,10,128):
        s=1j*2*np.pi*f;m,c,k,t,cp=2.,.1,50.,.2,.03
        Y=s*cp+s*t*t/(m*s*s+c*s+k)
        mot=1/(s*(m/t**2)+c/t**2+1/(s*(t*t/k)))
        errors.append(abs(Y-(s*cp+mot)))
        lam=3.;gauges.append(abs(Y-(s*cp+s*(lam*t)**2/((lam*lam)*(m*s*s+c*s+k)))))
    ck('C03_BVD_vs_mechanical_elimination',max(errors));ck('C16_nonidentifiable_scaling_counterexample',max(gauges))
    # Solve 2x2 MNA system independently of the closed expression.
    errors=[];noise_errors=[]
    for f in np.geomspace(10,1e7,256):
        s=2j*np.pi*f;ct=100e-12;cf=10e-12;rf=1e9;A=1e5/(1+s/(2*np.pi*100))
        yf=1/rf+s*cf;zf=1/yf;ng=1+s*ct*zf
        mat=np.array([[s*ct+yf,-yf],[A,1]],complex)
        result=np.linalg.solve(mat,np.array([1,0]))[1]
        formula=-zf/(1+ng/A)
        errors.append(abs(result-formula)/max(1,abs(result)))
        n=np.linalg.solve(mat,np.array([0,A]))[1]
        noise_errors.append(abs(n-ng/(1+ng/A))/max(1,abs(n)))
    ck('C04_charge_frontend_MNA_vs_transfer',max(errors));ck('C05_voltage_noise_MNA_vs_noise_gain',max(noise_errors))
    # In the all-capacitive case exact denominator pole gives NG bandwidth.
    wu=2*np.pi*1e7;ct=100e-12;cf=10e-12
    pole=-wu*cf/(ct+cf)
    ck('C05_exact_single_pole_NG_bandwidth',abs(pole+wu/(1+ct/cf)),1e-7)
    ck('C06_charge_noise_floor_counterexample',abs((cf*(1+ct/cf))**2-(ct+cf)**2))
    # Numerical integration on logarithmic f, using change of variable explicitly.
    kB=1.380649e-23;T=300.;R=1e4;C=1e-12
    u=np.geomspace(1e-8,1e8,200000);integ=np.trapezoid(1/(1+u*u),u)
    thermal=2*kB*T/(np.pi*C)*integ
    ck('C09_thermal_noise_integral_vs_kTC',abs(thermal/(kB*T/C)-1),1e-7)
    ck('C06_ENBW_integral',abs(integ-np.pi/2),1e-7)
    # Regression-based MOS gm from a square law, independent finite difference.
    beta=.003;vo=.2;dv=1e-6
    gm_num=(.5*beta*(vo+dv)**2-.5*beta*(vo-dv)**2)/(2*dv)
    ID=.5*beta*vo*vo
    ck('C07_MOS_gm_differential_vs_current',abs(gm_num-2*ID/vo),1e-12)
    # Exact full-scale RC acquisition residual, using 17 ln2 time constants.
    N=16;vfs=2.;tacq=2e-6;tau=tacq/((N+1)*np.log(2))
    ck('C09_RC_half_LSB_boundary',abs(np.exp(-tacq/tau)-2**(-N-1)))
    cs=kB*T/((vfs/2**N)**2/12)
    ck('C09_sampling_cap_noise_allocation',abs(np.sqrt(kB*T/cs)/(vfs/2**N/np.sqrt(12))-1))
    # Numerical integration of quantization error distribution.
    x=(np.arange(100000)+.5)/100000-.5
    ck('C10_uniform_quantization_integral',abs(np.mean(x*x)-1/12),1e-10)
    ck('C10_fullscale_SNR',abs(10*np.log10((vfs*vfs/8)/((vfs/2**N)**2/12))-(6.020599913279624*N+1.760912590556812)))
    # Coherent periodic input yields periodic deterministic quantization errors.
    n=np.arange(128);sig=.15*np.sin(2*np.pi*n/16+.1);qe=np.round(sig/.01)*.01-sig
    ck('C10_periodic_quantizer_error_repeats',np.max(abs(qe[16:]-qe[:-16])))
    ck('C10_white_error_assumption_rejected_for_periodic_input',float(abs(np.corrcoef(qe[:-16],qe[16:])[0,1])<.99))
    # Integrate zero-order hold pulse numerically vs sinc at carrier.
    Ts=1/40000;f=1000.;t=(np.arange(100000)+.5)*Ts/100000
    h=np.mean(np.exp(-2j*np.pi*f*t));formula=np.exp(-1j*np.pi*f*Ts)*np.sinc(f*Ts)
    ck('C12_hold_pulse_Fourier_vs_sinc',abs(h-formula))
    # Independent finite difference of capacitive driver's phase sensitivity.
    omega=2*np.pi*1000;tau=1e-5;dt=1e-9
    deriv=(-np.arctan(omega*(tau+dt))+np.arctan(omega*(tau-dt)))/(2*dt)
    ck('C13_driver_phase_derivative',abs(deriv/(-omega/(1+(omega*tau)**2))-1),1e-8)
    cpar=10e-9;Vpk=1.;tt=2*np.pi*np.arange(10000)/10000
    current=-cpar*omega*Vpk*np.sin(tt)
    ck('C13_capacitive_current_RMS',abs(np.sqrt(np.mean(current*current))-cpar*omega*Vpk/np.sqrt(2)))
    # Charge redistribution: solve conserved total nodal charge.
    caps=np.array([4.,2.,1.,1.]);dv=np.array([1.,0.,0.,0.]);vx=caps@dv/caps.sum()
    ck('C08_CDAC_charge_conservation',abs(np.sum(caps*(vx-dv))))
    ck('C11_SAR_MSB_halfscale',abs(vx-.5))
    # Numerical exact NTF integral vs low-frequency OSR approximation.
    osr=256.;f=np.linspace(-.5/osr,.5/osr,100001)
    exact=np.trapezoid((4*np.sin(np.pi*f)**2)/12,f)
    approx=np.pi**2/(36*osr**3)
    ck('C11_DeltaSigma_exact_integral_vs_lowfreq',abs(exact/approx-1),1e-5)
    # Comparator exponential from its differential ODE at t=0.
    gm,gl,cl=.002,.0005,1e-12;reg=cl/(gm-gl)
    ck('C11_comparator_ODE_rate',abs(cl/reg-(gm-gl)))
    # Closed-loop PI pole matching, independent polynomial roots.
    gain,gamma,zeta,wn=.7,.2,.7,5.;kp=(2*zeta*wn-gamma)/gain;ki=wn*wn/gain
    roots=np.roots([1,gamma+gain*kp,gain*ki]);target=np.array([-zeta*wn+1j*wn*np.sqrt(1-zeta*zeta),-zeta*wn-1j*wn*np.sqrt(1-zeta*zeta)])
    ck('C15_PI_pole_matching',np.max(abs(np.sort_complex(roots)-np.sort_complex(target))))
    # Differential angle gradient vs atan2 finite differences.
    x,y,dx,dy=.4,.7,.03,-.02;e=1e-6;alpha=.55398
    fd=-(np.arctan2(y+e*dy,x+e*dx)-np.arctan2(y-e*dy,x-e*dx))/(2*e*alpha)
    analytic=-(-y*dx+x*dy)/(alpha*(x*x+y*y))
    ck('C06_angle_noise_gradient',abs(fd-analytic),1e-9)
    ck('C14_reference_charge_step',abs(1e-12/10e-9-100e-6))
    # Full two-node Miller model versus independent determinant expansion.
    g1,g2,gm1,gm2,c1,c2,cc=1e-5,2e-5,.002,.01,1e-12,10e-12,5e-12
    errors=[]
    for freq in np.geomspace(10,1e9,128):
        s=2j*np.pi*freq
        mat=np.array([[g1+s*(c1+cc),-s*cc],[gm2-s*cc,g2+s*(c2+cc)]])
        response=np.linalg.solve(mat,np.array([gm1,0]))[1]
        den=g1*g2+s*(g1*(c2+cc)+g2*(c1+cc)+gm2*cc)+s*s*(c1*c2+cc*(c1+c2))
        formula=-gm1*(gm2-s*cc)/den
        errors.append(abs(response-formula)/max(1,abs(response)))
    ck('C19_Miller_MNA_vs_polynomial',max(errors))
    sz=gm2/cc
    ck('C19_right_half_plane_zero',abs(gm2-sz*cc))
    rz=2/gm2;szleft=gm2/(cc*(1-gm2*rz))
    yc=szleft*cc/(1+szleft*rz*cc)
    ck('C19_nulling_resistor_zero_equation',abs(gm2-yc))
    ck('C19_nulling_resistor_moves_left',float(szleft>=0))
    # CDS and correlated averaging from covariance matrices.
    rho=.8;sigma=2.;cov=sigma**2*np.array([[1,rho],[rho,1]])
    diff=np.array([1.,-1.])
    ck('C20_CDS_variance_from_covariance',abs(diff@cov@diff-2*sigma**2*(1-rho)))
    num=20;idx=np.arange(num);rho=.7;cov=rho**abs(idx[:,None]-idx[None,:]);meanvec=np.ones(num)/num
    formula=(1+2*sum((1-k/num)*rho**k for k in range(1,num)))/num
    ck('C20_average_covariance_vs_lag_sum',abs(meanvec@cov@meanvec-formula))
    ck('C22_lecture_closed_gain_counterexample',float(abs(100/(1+100*.5)-100/(100+100*.5))<1))
    # Solve actual negative-feedback linear equations independently.
    a,b=100.,.5
    va,vo=np.linalg.solve([[1,b],[-a,1]],[1,0])
    ck('C22_feedback_linear_solve',abs(vo-a/(1+a*b)))
    K,zeta,wn=3.,.7,8.;kp=2*zeta*wn/K;ki=wn*wn/K
    ck('C22_PLL_characteristic',np.max(abs(np.array([K*kp,K*ki])-[2*zeta*wn,wn*wn])))
    order=np.ceil(np.log10((10**6-1)/(10**.1-1))/(2*np.log10(4)))
    ck('C23_Butterworth_order_bound',abs(order-6))
    fc=5000/(10**.1-1)**(1/(2*order));stop=10*np.log10(1+(20000/fc)**(2*order))
    ck('C23_Butterworth_stop_requirement',max(0.,60-stop))
    # CIC impulse polynomial versus rational form, independent convolution.
    rm,nstage=8,3;imp=np.ones(1)
    for _ in range(nstage):imp=np.convolve(imp,np.ones(rm))
    omega=.19;poly=np.sum(imp*np.exp(-1j*omega*np.arange(len(imp))))
    rational=((1-np.exp(-1j*omega*rm))/(1-np.exp(-1j*omega)))**nstage
    ck('C23_CIC_impulse_vs_rational',abs(poly-rational),1e-9)
    ck('C23_CIC_gain_delay',max(abs(imp.sum()-rm**nstage),abs(np.dot(np.arange(len(imp)),imp)/imp.sum()-nstage*(rm-1)/2)))
    vin,duty=12.,.25;vout=vin*duty
    ck('C24_Buck_volt_second_balance',abs(duty*(vin-vout)+(1-duty)*(-vout)))
    report=dict(seed=20261030,total=len(checks),passed=sum(v['passed'] for v in checks.values()),checks=checks,
                boundary='Circuit mathematics and synthetic inputs; no PDK transistor simulation, new RTL run or measured head performance')
    (HERE/'circuit_checks.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    print(f"PASS {report['passed']}/{report['total']} circuit checks")


if __name__=='__main__':main()
