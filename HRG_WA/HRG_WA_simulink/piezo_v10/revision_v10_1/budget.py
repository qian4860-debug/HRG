"""Stage-by-stage covariance propagation at the declared IQ reference plane.
White quantization budgets are conditional and tested separately from coherent
undithered quantization. Saturation invalidates the local linear budget.
"""
from pathlib import Path
import json,csv
import numpy as np

HERE=Path(__file__).resolve().parent;EV=HERE/'evidence'


def angle(iq,alpha):
    I=iq[...,0:2];Q=iq[...,2:4]
    N=I[...,0]**2+Q[...,0]**2-I[...,1]**2-Q[...,1]**2
    M=2*(I[...,0]*I[...,1]+Q[...,0]*Q[...,1])
    return -np.arctan2(M,N)/(2*alpha)


def main():
    cal=json.loads((EV/'calibration_profile.json').read_text());D=np.array(cal['detect_real'])+1j*np.array(cal['detect_imag'])
    Drive=np.array(cal['drive_real'])+1j*np.array(cal['drive_imag']);inv=np.linalg.inv(D)
    L=np.block([[inv.real,inv.imag],[-inv.imag,inv.real]])
    fs=40000.;N=40;alpha=2*.27699096196168066;a=1e-11;omega=2*np.pi*1000
    phase=omega*np.arange(N)/fs;K=np.zeros((N,4,2))
    for n in range(N):K[n]=2/N*np.vstack([np.cos(phase[n])*np.eye(2),np.sin(phase[n])*np.eye(2)])
    # Detector/AFE noise quoted at ADC input; 5 uV RMS, flat over fs/2.
    sigma_v=5e-6;quant_delta=2/2**20;common_jitter=1e-9;ind_jitter=1e-9
    rows=[];worst={};checks={};rng=np.random.default_rng(20261101);ratios=[]
    for theta in np.linspace(-.65,.65,9):
        v=np.array([np.cos(theta),np.sin(theta)]);z=D@(a*v)
        clean=np.real(np.exp(1j*phase)[:,None]*z)
        derivative=np.real(1j*omega*np.exp(1j*phase)[:,None]*z)
        iq=np.r_[a*v,[0.,0.]];nn=a*a*np.cos(2*theta);mm=a*a*np.sin(2*theta)
        dN=np.array([2*iq[0],-2*iq[1],0.,0.]);dM=np.array([2*iq[1],2*iq[0],0.,0.])
        g=-(nn*dM-mm*dN)/(2*alpha*(nn*nn+mm*mm))
        white_adc=2*sigma_v**2/N*np.eye(4);white_quant=2*(quant_delta**2/12)/N*np.eye(4)
        jitter_common=np.zeros((4,4));jitter_ind=np.zeros((4,4))
        for k in range(N):
            q=K[k]@derivative[k]
            jitter_common+=common_jitter**2*np.outer(q,q)
            jitter_ind+=ind_jitter**2*K[k]@np.diag(derivative[k]**2)@K[k].T
        covs={'AFE_detector':white_adc,'ADC_quantization_white':white_quant,'clock_common':jitter_common,'clock_independent':jitter_ind}
        variance=0.
        for source,S in covs.items():
            Sc=L@S@L.T;val=float(g@Sc@g);variance+=val
            deg=np.sqrt(max(0,val))*180/np.pi;worst[source]=max(worst.get(source,0.),deg)
            rows.append([theta,source,np.trace(S),np.trace(Sc),deg])
        # A known, fixed differential timing error is a bias, never RSS noise.
        skew=np.array([0.,.5e-9]);zskew=z*np.exp(1j*omega*skew)
        qskew=inv@zskew;bias=float(angle(np.r_[qskew.real,-qskew.imag],alpha)-angle(iq,alpha))
        rows.append([theta,'fixed_0p5ns_skew_bias',0,0,abs(bias)*180/np.pi])
        # Independent time-domain MC, including actual integer quantization.
        trials=5000
        jt=common_jitter*rng.normal(size=(trials,N,1))+ind_jitter*rng.normal(size=(trials,N,2))
        waveform=np.real(np.exp(1j*(phase[None,:,None]+omega*jt))*z[None,None,:])
        waveform+=sigma_v*rng.normal(size=waveform.shape)
        digitized=np.clip(np.copysign(np.floor(abs(waveform/quant_delta)+.5),waveform),-2**19,2**19-1)*quant_delta
        raw=np.einsum('nij,tnj->ti',K,digitized);charge=raw@L.T
        error=angle(charge,alpha)-angle(iq,alpha);measured=float(np.std(error,ddof=1));pred=np.sqrt(variance)
        ratios.append(measured/pred)
    checks['nine_angles_time_domain_MC_vs_covariance']=bool(max(abs(np.array(ratios)-1))<.08)
    checks['quantization_has_dither_in_MC']=bool(sigma_v>2*quant_delta)
    # Coherent undithered fixture: deterministic periodic error is not white.
    n=np.arange(4000);wave=.1*np.sin(2*np.pi*n/40+.13);dq=2/2**12
    error=np.round(wave/dq)*dq-wave
    checks['coherent_quantization_not_assumed_white']=bool(np.max(abs(error[40:]-error[:-40]))<1e-12)
    # Actuator quantization -> force envelope -> angle-rate white PSD, conditional
    # on dither/whiteness and no clipping. It is not a measured ARW claim.
    vd_lsb=2/2**18;Sv=2*(vd_lsb**2/12)/fs
    Srate=(np.linalg.norm(Drive,2)/(2*omega*a*alpha))**2*2*Sv
    arw=float(np.sqrt(Srate/2)*180/np.pi*60)
    # Linear range is checked at the hardware code boundary, not via covariance.
    bad=1.05*np.sin(phase);raw=np.round(bad/vd_lsb);clipped=np.any(raw>2**17-1)|np.any(raw< -2**17)
    checks['saturation_budget_is_invalid_not_RSS']=bool(clipped)
    budget=dict(status='conditional_local_linear_budget_verified_by_independent_MC',checks=checks,worst_body_angle_rms_deg=worst,
        MC_sigma_to_prediction=ratios,ADC_input_noise_rms_V=sigma_v,demod_samples=N,
        DAC_angle_rate_white_PSD_rad2_s2_per_Hz=float(Srate),DAC_conditional_ARW_deg_sqrt_h=arw,
        saturation=dict(test_peak_V=1.05,linear_budget_valid=False,clipped=True),
        assumptions=['ADC white noise flat over Nyquist; nonoverlapping complete carrier windows','full real 4x4 covariance of inverse complex calibration','DAC white/ARW estimate conditional on whitening; coherent quantization separately rejected','fixed skew is a bias; common/independent random jitter covariances differ','AFE spec is at ADC input, before deembedding; no measured hardware or closed-loop ARW claim'])
    (EV/'budget_results.json').write_text(json.dumps(budget,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    with (EV/'budget_chain.csv').open('w',encoding='utf-8',newline='') as f:
        wr=csv.writer(f,lineterminator='\n');wr.writerow(['theta_rad','source','ADC_IQ_cov_trace','charge_IQ_cov_trace','body_angle_deg']);wr.writerows(rows)
    assert all(checks.values()),budget;print('PASS',len(checks),'budget checks; MC ratios',min(ratios),max(ratios))


if __name__=='__main__':main()
