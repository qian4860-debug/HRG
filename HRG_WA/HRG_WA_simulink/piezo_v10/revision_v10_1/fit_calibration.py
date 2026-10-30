"""Independent charge injection, actuation reference and blocked-head fixtures.
Only synthetic calibrated references; cannot factor unknown D*P*B blindly.
"""
from pathlib import Path
import json,csv
import numpy as np

HERE=Path(__file__).resolve().parent;EV=HERE/'evidence'


def fit_matrix(x,y):
    sv=np.linalg.svd(x,compute_uv=False)
    if sv[-1] < 1e-8*sv[0]:raise ValueError('Rank deficient calibration excitation')
    return np.linalg.lstsq(x.T,y.T,rcond=None)[0].T


def main():
    EV.mkdir(exist_ok=True);w=2*np.pi*1000;Ts=1/40000
    Md=np.array([[1,.025],[-.015,1.04]]);Mb=np.array([[1,-.03],[.02,1.08]])
    hc=-1j*w/((1+1000*1e-10+1j*w*1000*1e-9)*100e-12*(1j*w+1/(1e9*100e-12)))
    detect=np.diag(1/(1+1j*w/(2*np.pi*np.array([20000,18000]))))@Md*hc
    hold=np.exp(-1j*w*Ts/2)*np.sinc(w*Ts/(2*np.pi))
    drive=1.1e-6*Mb@np.diag(1/(1+1j*w*np.array([20e-6,24e-6])))*hold
    # Separate calibration reference planes, not a single end-to-end fit.
    models={'detect':detect,'drive':drive,'blocked_feedthrough':np.zeros((2,2),complex)}
    estimates={};rows=[];checks={};errors={}
    for i,(kind,M) in enumerate(models.items()):
        train=np.random.default_rng(20261100+i);test=np.random.default_rng(20261200+i)
        scale=2e-12 if kind=='detect' else .02
        x=scale*(train.normal(size=(2,64))+1j*train.normal(size=(2,64)))
        noise=max(np.linalg.norm(M)*scale,1e-7)*2e-6
        y=M@x+noise*(train.normal(size=(2,64))+1j*train.normal(size=(2,64)))
        est=fit_matrix(x,y);estimates[kind]=est
        xv=scale*(test.normal(size=(2,91))+1j*test.normal(size=(2,91)))
        yv=M@xv+noise*(test.normal(size=(2,91))+1j*test.normal(size=(2,91)))
        error=np.linalg.norm(est@xv-yv)/max(np.linalg.norm(yv),1e-12)
        if kind=='blocked_feedthrough':
            errors[kind]=float(np.linalg.norm(est));checks[kind+'_absolute_bound']=errors[kind]<1e-9
        else:
            errors[kind]=float(error);checks[kind+'_holdout']=error<2e-5
        for split,xx,yy in [('train',x,y),('holdout',xv,yv)]:
            for k in range(xx.shape[1]):rows.append([kind,split,k,*np.r_[xx[:,k].real,xx[:,k].imag,yy[:,k].real,yy[:,k].imag]])
    checks['independent_train_holdout_seeds']=True
    checks['both_channel_offdiagonals_identified']=abs(estimates['detect'][0,1])>0 and abs(estimates['drive'][1,0])>0
    try:fit_matrix(np.ones((2,10)),np.ones((2,10)));checks['rank_deficient_rejected']=False
    except ValueError:checks['rank_deficient_rejected']=True
    checks={k:bool(v) for k,v in checks.items()}
    profile=dict(status='synthetic_independent_reference_only',frequency_Hz=1000,sample_period_s=Ts,
        detect_real=estimates['detect'].real.tolist(),detect_imag=estimates['detect'].imag.tolist(),
        drive_real=estimates['drive'].real.tolist(),drive_imag=estimates['drive'].imag.tolist(),
        feedthrough_real=estimates['blocked_feedthrough'].real.tolist(),feedthrough_imag=estimates['blocked_feedthrough'].imag.tolist(),
        nominal_detect_real=float(hc.real),nominal_detect_imag=float(hc.imag),
        reference_planes=dict(detect='known motional charge -> sampled ADC voltage',drive='DAC samples -> independently referenced charge acceleration; hold included',feedthrough='blocked motion: DAC voltage -> ADC voltage'),
        warning='Without independent injected charge, actuation observation and blocked-motion reference only D*P*B is identifiable; no absolute mass/Theta inferred')
    save=lambda n,v:(EV/n).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    save('calibration_profile.json',profile);save('calibration_results.json',dict(checks=checks,holdout_errors=errors,condition_detect=float(np.linalg.cond(estimates['detect'])),condition_drive=float(np.linalg.cond(estimates['drive']))))
    with (EV/'calibration_fixture.csv').open('w',encoding='utf-8',newline='') as f:
        writer=csv.writer(f,lineterminator='\n');writer.writerow(['fixture','split','id','x1_re','x2_re','x1_im','x2_im','y1_re','y2_re','y1_im','y2_im']);writer.writerows(rows)
    assert all(checks.values());print('PASS',len(checks),'separate calibration checks',errors)


if __name__=='__main__':main()
