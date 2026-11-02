"""Synthetic independent reference measurements, not blind online inference."""
from pathlib import Path
import json
import numpy as np
HERE=Path(__file__).resolve().parent;OLD=HERE.parent
def matrix_cal(p,kind):
    w=2*np.pi*p['f0'];ts=p['Ts']
    if kind=='detect':
        hc=-1j*w/((1+p['Rs']*p['G0']+1j*w*p['Rs']*p['Cs'])*p['Cf']*(1j*w+1/(p['Rf']*p['Cf'])))
        return np.diag(1/(1+1j*w/(2*np.pi*np.array(p['afe_bw']))))@np.array(p['detect_matrix'])*hc
    return p['b']*np.array(p['drive_matrix'])@np.diag(1/(1+1j*w*np.array(p['driver_tau'])))*np.exp(-1j*w*ts/2)*np.sinc(w*ts/(2*np.pi))
def fit(p,seed):
    train=np.random.default_rng(seed);test=np.random.default_rng(seed+10000);cal={};errors={}
    for kind in ['detect','drive']:
        H=matrix_cal(p,kind);scale=2e-12 if kind=='detect' else .02
        x=scale*(train.normal(size=(2,100))+1j*train.normal(size=(2,100)))
        sigma=np.linalg.norm(H)*scale*2e-6
        y=H@x+sigma*(train.normal(size=x.shape)+1j*train.normal(size=x.shape))
        est=np.linalg.lstsq(x.T,y.T,rcond=None)[0].T
        xv=scale*(test.normal(size=(2,137))+1j*test.normal(size=(2,137)))
        yv=H@xv+sigma*(test.normal(size=xv.shape)+1j*test.normal(size=xv.shape))
        errors[kind]=float(np.linalg.norm(est@xv-yv)/np.linalg.norm(yv))
        cal[kind+'_real']=est.real.tolist();cal[kind+'_imag']=est.imag.tolist()
    w=2*np.pi*p['f0'];R=lambda a:np.array([[np.cos(a),-np.sin(a)],[np.sin(a),np.cos(a)]])
    rk=R(p['stiffness_axis']);rd=R(p['damping_axis'])
    dK=rk@np.diag((w+np.array([-1,1])*np.pi*p['split_hz'])**2)@rk.T-w*w*np.eye(2)
    dD=rd@np.diag(2*np.array([1,-1])*p['damping_half_difference'])@rd.T
    # Calibrated trajectory and force-reference fixture: residual force after
    # nominal inertia and mean damping, with independently seeded noise.
    true=np.c_[dK/w,dD];x=train.normal(size=(4,500));sigma=2e-5
    y=true@x+sigma*train.normal(size=(2,500));est=np.linalg.lstsq(x.T,y.T,rcond=None)[0].T
    k=(est[:,:2]+est[:,:2].T)*w/2;d=(est[:,2:]+est[:,2:].T)/2
    xv=test.normal(size=(4,211));yv=true@xv+sigma*test.normal(size=(2,211))
    errors['mechanical_absolute_RMS']=float(np.sqrt(np.mean((np.c_[k/w,d]@xv-yv)**2)))
    cal.update(dK=k.tolist(),dD=d.tolist(),holdout=errors,reference_boundary='Known independent injected charge / actuation acceleration / calibrated motion and force observations. Synthetic references only; not identifiable from one unknown end-to-end response.')
    assert errors['detect']<2e-5 and errors['drive']<2e-5 and errors['mechanical_absolute_RMS']<4e-5
    return cal
def main():
    data=json.loads((OLD/'nonideal_validation/evidence/all_results.json').read_text());records={}
    for i,(name,v) in enumerate(data.items()):records[name]=fit(v['case']['p'],20261110+i)
    base=data['baseline']['case']['p']
    for i,(rate,angle) in enumerate([(.8,.65),(-1.2,-.3),(1.5,.9)]):
        p=dict(base,Omega=rate,theta0=angle,noise_rms_V=8e-6,noise_seed=20261200+i,split_hz=.007,damping_half_difference=.0013,stiffness_axis=.51,damping_axis=-.19)
        records['holdout'+str(i+1)]=fit(p,20261300+i);records['holdout'+str(i+1)]['plant']=p
    (HERE/'independent_profiles.json').write_text(json.dumps(records,indent=2)+'\n',encoding='utf-8',newline='\n')
    print('PASS: 21 independent calibration/tensor fixtures with disjoint observation holdouts')
if __name__=='__main__':main()
