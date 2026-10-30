"""Fit intrinsic charge-domain parameters using terminal Y, multiple known loads
and loaded ringdowns. The loading pole is inside the prediction, not gamma.

Requires independently calibrated terminal current/voltage. Without these
references voltage ratios alone retain a charge-scale ambiguity.
"""
from pathlib import Path
import json,csv
import numpy as np

HERE=Path(__file__).resolve().parent;EV=HERE/'evidence'
NOM=np.array([.28,.9e-9,.7e-10,1.2e-6,1e-6,.12e-12])


def unpack(x):return np.r_[1000+x[0],NOM*np.exp(x[1:])]


def response(p,f,R):
    f0,gamma,C,G,kappa,b,Cds=p;s=2j*np.pi*np.asarray(f);D=s*s+2*gamma*s+(2*np.pi*f0)**2
    Y=G+s*C+s*kappa/D
    H=(s*Cds*D-s*b)/((1/R+G+s*C)*D+kappa*s)
    return Y,H


def loaded_pole(p,R):
    f0,gamma,C,G,kappa,b,Cds=p
    # Scale charge state to dielectric voltage for a well-conditioned eigensolve.
    w=2*np.pi*f0
    A=np.array([[0,w,0],[-w,-2*gamma,kappa/(C*w)],[0,-w,-(1/R+G)/C]])
    eig=np.linalg.eigvals(A);return eig[eig.imag>0][0]


def residual(x,data):
    p=unpack(x);yy,_=response(p,data['f'],1000);parts=[(yy-data['Y'])/data['Y_scale']]
    for R,H,meas in zip(data['loads'],data['H'],data['poles']):
        _,hh=response(p,data['f'],R);parts.append((hh-H)/max(np.sqrt(np.mean(abs(H)**2)),1e-10))
        pole=loaded_pole(p,R)
        parts.append(np.array([(pole.real-meas.real)*.2+1j*(pole.imag-meas.imag)*.02]))
    out=np.concatenate(parts);return np.r_[out.real,out.imag]


def fit(data):
    x=np.zeros(7);x[0]=.03;lam=1e-3;history=[]
    for step in range(100):
        r=residual(x,data);J=np.empty((len(r),len(x)));eps=2e-5
        for j in range(len(x)):
            dx=np.zeros_like(x);dx[j]=eps
            J[:,j]=(residual(x+dx,data)-residual(x-dx,data))/(2*eps)
        g=J.T@r;H=J.T@J
        dx=np.linalg.solve(H+lam*np.diag(np.maximum(np.diag(H),1e-14)), -g)
        dx=np.clip(dx,-.3,.3);candidate=x+dx
        score=float(r@r);nextscore=float(residual(candidate,data)@residual(candidate,data))
        history.append(dict(step=step,score=score,damping=lam))
        if nextscore<score:
            x=candidate;lam=max(1e-10,lam/3)
            if np.linalg.norm(dx)<1e-8:break
        else:lam=min(1e8,lam*10)
    # Dimensionless local parameter Jacobian, with rank/condition explicit.
    r=residual(x,data);J=np.empty((len(r),len(x)))
    for j in range(len(x)):
        dx=np.zeros_like(x);dx[j]=2e-5;J[:,j]=(residual(x+dx,data)-residual(x-dx,data))/(4e-5)
    sv=np.linalg.svd(J,compute_uv=False)
    return unpack(x),sv,history


def fixture(truth,f,loads,seed):
    rng=np.random.default_rng(seed);Y,_=response(truth,f,1000)
    Y=Y+1e-12*(rng.normal(size=len(f))+1j*rng.normal(size=len(f)))
    hs=[];poles=[];ringrows=[];t=np.arange(10000)*1e-4
    for R in loads:
        _,H=response(truth,f,R);H=H+1e-9*(rng.normal(size=len(f))+1j*rng.normal(size=len(f)));hs.append(H)
        pole=loaded_pole(truth,R)
        z=np.exp(pole*t)+1e-7*(rng.normal(size=len(t))+1j*rng.normal(size=len(t)))
        rho=np.vdot(z[:-1],z[1:])/np.vdot(z[:-1],z[:-1]);est=(np.log(abs(rho))+1j*np.angle(rho))/1e-4;poles.append(est)
        for i in range(0,len(t),10):ringrows.append([R,t[i],z[i].real,z[i].imag])
    return dict(f=f,Y=Y,Y_scale=np.sqrt(np.mean(abs(Y)**2)),loads=loads,H=hs,poles=poles),ringrows


def main():
    EV.mkdir(exist_ok=True)
    truth=np.array([1000,np.pi*1000/1e4,1e-9,1e-10,1e-6,1.1e-6,.15e-12])
    f=np.r_[np.linspace(900,1100,61),np.linspace(999.75,1000.25,101)]
    train,rings=fixture(truth,f,[1000.,20000.,100000.],20261031)
    estimate,sv,history=fit(train)
    validation,_=fixture(truth,np.linspace(999.63,1000.41,117),[3000.,50000.,200000.],20261032)
    rels=[]
    for R,H in zip(validation['loads'],validation['H']):
        _,pred=response(estimate,validation['f'],R);rels.append(float(np.linalg.norm(pred-H)/np.linalg.norm(H)))
    loaded_gamma=-loaded_pole(truth,100000).real
    wrong=truth.copy();wrong[1]=loaded_gamma
    wrong_pole=loaded_pole(wrong,100000)
    correct_pole=loaded_pole(estimate,100000)
    checks=dict(intrinsic_gamma_recovery=abs(estimate[1]/truth[1]-1)<.003,
        all_electrical_combinations_recovered=np.max(abs(estimate[2:]/truth[2:]-1))<.02,
        heldout_loads_and_frequencies=max(rels)<.003,
        full_rank_dimensionless_jacobian=sv[-1]/sv[0]>1e-7,
        double_loaded_damping_rejected=abs(-wrong_pole.real-loaded_gamma)>.02,
        actual_loaded_pole_matches=abs(-correct_pole.real-loaded_gamma)<.002)
    pnames=['f0_Hz','gamma_intrinsic_per_s','Cs_F','G0_S','kappa','b','Cds_F']
    profile=dict(schema='v10.1_identified_charge_domain',status='synthetic_validation_only',
        boundary='intrinsic mechanical parameters at short-circuit sensing boundary; explicit electrical load must remain in model',
        parameters=dict(zip(pnames,map(float,estimate))),bryan_factor=None,voltage_limit_V=None,displacement_limit_m=None,
        physical_mass=None,theta_s=None,theta_d=None,
        reference_requirement='calibrated terminal admittance and independently known load; voltage-ratio-only data cannot fix charge scale')
    result=dict(checks={k:bool(v) for k,v in checks.items()},relative_errors=dict(zip(pnames,map(float,abs(estimate/truth-1)))),
        heldout_load_errors=rels,jacobian_singular_values=sv.tolist(),jacobian_condition=float(sv[0]/sv[-1]),
        intrinsic_gamma=float(truth[1]),measured_loaded_gamma=float(loaded_gamma),wrong_double_counted_gamma=float(-wrong_pole.real),fit_history=history)
    save=lambda n,v:(EV/n).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    save('identified_multiload_profile.json',profile);save('multiload_results.json',result)
    with (EV/'multiload_fixture.csv').open('w',encoding='utf-8',newline='') as file:
        writer=csv.writer(file,lineterminator='\n');writer.writerow(['Rload_ohm','f_Hz','Y_re_S','Y_im_S','Vs_Vdrive_re','Vs_Vdrive_im'])
        for R,H in zip(train['loads'],train['H']):
            for k in range(len(f)):writer.writerow([R,f[k],train['Y'][k].real,train['Y'][k].imag,H[k].real,H[k].imag])
    with (EV/'ringdown_fixture.csv').open('w',encoding='utf-8',newline='') as file:
        writer=csv.writer(file,lineterminator='\n');writer.writerow(['Rload_ohm','t_s','z_re','z_im']);writer.writerows(rings)
    assert all(checks.values()),result
    print('PASS',len(checks),'multi-load checks; holdout',max(rels),'gamma intrinsic/loaded/double',truth[1],loaded_gamma,-wrong_pole.real)


if __name__=='__main__':main()
