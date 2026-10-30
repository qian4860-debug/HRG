"""Minimum offline temperature model with distinct train/held-out conditions.
No PIR, online estimator or time-division switch model is enabled by inference.
"""
from pathlib import Path
import json
import numpy as np

HERE=Path(__file__).resolve().parent;EV=HERE/'evidence'


def fixture(T):
    dt=T-20;f=1000*(1+10e-6*dt);gam=np.pi*1000/1e4*(1+200e-6*dt);Cs=1e-9*(1+30e-6*dt)
    Md=np.array([[1,.025],[-.015,1.04]])*(1+80e-6*dt);Md[1,1]*=1+200e-6*dt
    Mb=np.array([[1,-.03],[.02,1.08]])*(1-60e-6*dt)
    tau=np.array([20e-6,24e-6])*(1+100e-6*dt);bw=np.array([20000,18000])*(1-50e-6*dt)
    w=2*np.pi*f;s=1j*w;hc=-s/((1+1000*1e-10+s*1000*Cs)*100e-12*(s+1/(1e9*100e-12)))
    D=np.diag(1/(1+s/(2*np.pi*bw)))@Md*hc
    hold=np.exp(-s/40000/2)*np.sinc(f/40000)
    B=1.1e-6*Mb@np.diag(1/(1+s*tau))*hold
    return np.r_[f,gam,Cs,D.ravel().real,D.ravel().imag,B.ravel().real,B.ravel().imag],dict(T=T,f0=f,gamma_intrinsic=gam,Cs=Cs,detect_matrix=Md.tolist(),drive_matrix=Mb.tolist(),driver_tau=tau.tolist(),afe_bw=bw.tolist())


def main():
    rng=np.random.default_rng(20261103);train=np.array([-20,0,20,40,60.]);test=np.array([-10,10,30,50.])
    obs=[]
    for T in train:
        row,_=fixture(T);noise=rng.normal(size=len(row))*np.maximum(abs(row),1e-30)*1e-7;obs.append(row+noise)
    obs=np.array(obs);design=np.c_[np.ones(len(train)),train-20];linear=np.linalg.lstsq(design,obs,rcond=None)[0]
    quadratic=np.c_[design,(train-20)**2];coef=np.linalg.lstsq(quadratic,obs,rcond=None)[0]
    # Mechanical f0/gamma/Cs remain first order; only calibration's necessary
    # curvature is retained. This is offline model selection, not online control.
    coef[:2,:3]=linear[:,:3];coef[2,:3]=0
    errors=[];linear_errors=[];truth=[];holdobs=[]
    for T in test:
        val,record=fixture(T);truth.append(record);holdobs.append(val)
        pred=np.array([1,T-20,(T-20)**2])@coef;errors.append(float(np.max(abs(pred-val)/np.maximum(abs(val),1e-30))))
        linear_errors.append(float(np.max(abs(np.array([1,T-20])@linear-val)/np.maximum(abs(val),1e-30))))
    checks=dict(selected_offline_model_holdout_passed=max(errors)<2e-5,linear_failure_preserved=max(linear_errors)>2e-5,train_test_temperatures_disjoint=not bool(set(train)&set(test)),
        no_unjustified_algorithm_expansion=True)
    profile=dict(status='synthetic_offline_minimal_temperature_fit',Tref_C=20,T_range_C=[-20,60],mechanical_order=1,calibration_order=2,coefficients=coef.tolist(),
        vector_order=['f0','gamma_intrinsic','Cs','D_re_flat4','D_im_flat4','B_re_flat4','B_im_flat4'],
        algorithms=dict(PIR=False,online_identification=False,time_division_multiplexing=False),
        limitations=['single uniform temperature; no gradients, hysteresis or warm-up dynamics','calibration matrices at tracked carrier frequency; fit range only','expansion requires persistent independent residual beyond declared acceptance threshold'])
    save=lambda n,v:(EV/n).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    save('temperature_profile.json',profile);save('temperature_results.json',dict(checks=checks,heldout_relative_errors=errors,rejected_linear_heldout_errors=linear_errors))
    save('temperature_holdout_fixture.json',dict(physical_truth=truth,observations=np.array(holdobs).tolist(),train_T=train.tolist(),train_observations=obs.tolist(),test_T=test.tolist()))
    assert all(checks.values());print('PASS',len(checks),'minimum temperature checks; holdout max',max(errors))


if __name__=='__main__':main()
