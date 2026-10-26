"""Independent physical/solver predictions and CSV-only scoreboards.

Uses closed-form 2x2 propagation and damped oscillators, not MATLAB estimators.
No claim of independent experimental certification.
"""
from pathlib import Path
import argparse
import hashlib
import json
import subprocess
import sys
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
REPO=ROOT.parents[1]
E=ROOT/'evidence'

def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def csv(name):return np.loadtxt(E/name,delimiter=',')
def envelope_oracle(t,p,rate):
    gamma=np.pi*p['f0_hz']/p['quality_factor'];d=p['damping_anisotropy_per_s']/2
    beta=p['damping_axis_rad'];omega=rate*np.pi/180;J=np.array([[0.,-1],[1,0]])
    Gamma=gamma*np.eye(2)+d*np.array([[np.cos(4*beta),np.sin(4*beta)],[np.sin(4*beta),-np.cos(4*beta)]])
    C=-Gamma+gamma*np.eye(2)-2*p['bryan']*omega*J
    nu2=(2*p['bryan']*omega)**2-d*d;z0=np.array([np.cos(.274),np.sin(.274)])
    if nu2>0:
        nu=np.sqrt(nu2);co=np.cos(nu*t);si=np.sin(nu*t)/nu
    else:
        nu=np.sqrt(-nu2);co=np.cosh(nu*t);si=np.sinh(nu*t)/nu
    return np.exp(-gamma*t[:,None])*(co[:,None]*z0+si[:,None]*(C@z0))

def damping_fit(t,y):
    energy=np.sum(y*y,axis=1);theta=np.unwrap(np.angle((y[:,0]+1j*y[:,1])**2))/4
    columns=[t-t[0]]
    for f in (np.cos(4*theta),np.sin(4*theta)):
        columns.append(np.r_[0,np.cumsum((f[:-1]+f[1:])*.5*np.diff(t))])
    X=np.column_stack(columns)[1:];target=-.5*np.log(energy[1:]/energy[0]);scale=np.linalg.norm(X,axis=0)
    return np.linalg.lstsq(X/scale,target,rcond=None)[0]/scale

def bias_oracle(t,p,V,mode,h=None):
    w=2*np.pi*p['f0_hz'];gamma=np.pi*p['f0_hz']/p['quality_factor'];P=np.diag(p['electrostatic_P_per_s2_v2'])
    k=w*w+P*(p['reference_bias_v']**2-V*V) if mode!='double_count' else w*w-P*V*V
    wd=np.sqrt(k-gamma*gamma);lam=-gamma+1j*wd;coefficient=np.array([.8,.6])*(1-1j*gamma/wd)
    if h is None:prop=np.exp(t[:,None]*lam)
    else:
        x=h*lam;R4=1+x+x*x/2+x**3/6+x**4/24
        prop=np.exp(np.round(t/h)[:,None]*np.log(R4))
    q=np.real(prop*coefficient);v=np.real(prop*coefficient*lam/w)
    return np.column_stack((q,v)),wd/(2*np.pi)

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--core-only',action='store_true');args=parser.parse_args()
    report=read(E/'core_study.json');p=report['profile'];assert report['pass']
    checks=[]
    def check(name,error,limit):
        passed=bool(np.isfinite(error) and error<=limit)
        checks.append(dict(name=name,error=float(error),limit=float(limit),pass_=passed))
        if not passed:print('FAIL',name,error,limit)
    fixture=csv('detection_fixture.csv');D=np.linalg.lstsq(fixture[:,:2],fixture[:,2:],rcond=None)[0].T
    check('fixture_matrix_recomputed',np.max(abs(D-np.array(report['detectionFit']['matrix']))),1e-12)
    g=np.pi*p['f0_hz']/p['quality_factor'];d=p['damping_anisotropy_per_s']/2;b=p['damping_axis_rad']
    expected=np.array([g,d*np.cos(4*b),d*np.sin(4*b)])
    env_errors={};bias_errors={};hypotheses=[]
    for case in report['envelopeCases']:
        data=csv(case['name']+'.csv');t=data[:,0];truth=data[:,1:3];raw=data[:,3:5];cal=data[:,5:7]
        predicted=envelope_oracle(t,p,case['rateDegS'])
        err=float(np.max(abs(truth-predicted)));env_errors[(case['rateDegS'],case['stepS'])]=err
        check(case['name']+'_closed_form_state',err,p['acceptance']['oracle_envelope_state_error'])
        check(case['name']+'_passive_energy_never_increases',max(0,float(np.max(np.diff(np.sum(truth*truth,axis=1))))),1e-12)
        fit=damping_fit(t,cal);bad=damping_fit(t,raw)
        check(case['name']+'_independent_estimator',np.max(abs(fit-[case['corrected'][x] for x in ('gamma','dc','ds')])),1e-11)
        check(case['name']+'_physical_damping',np.linalg.norm(fit-expected)/np.linalg.norm(expected[1:]),p['acceptance']['envelope_damping_relative_error'])
        check(case['name']+'_uncalibrated_error_is_detected',float(np.linalg.norm(bad-expected)<10*np.linalg.norm(fit-expected)),0)
    for rate in p['holdout_rates_deg_s']:
        coarse=env_errors[(rate,p['envelope_step_s'])];fine=env_errors[(rate,p['envelope_step_s']/2)]
        check(f'envelope_rate_{rate}_step_halving',fine/max(coarse,1e-15),.2)
    bycase={}
    for case in report['biasCases']:
        data=csv(case['name']+'_probes.csv');t=data[:,0];physical,frequency=bias_oracle(t,p,case['voltageV'],case['mode'])
        numerical,_=bias_oracle(t,p,case['voltageV'],case['mode'],case['stepS'])
        check(case['name']+'_RK4_prediction',np.max(abs(data[:,1:]-numerical)),2e-8)
        error=float(np.max(abs(data[:,1:]-physical)))
        bias_errors[(case['voltageV'],case['mode'],case['stepS'])]=error
        events=csv(case['name']+'_crossings.csv');found=[]
        for channel in (1,2):
            v=events[events[:,0]==channel];cross=v[:,2]-v[:,4]*(v[:,3]-v[:,2])/(v[:,5]-v[:,4])
            slope=np.polyfit(v[:,1],cross,1)[0];found.append(1/slope)
        check(case['name']+'_crossing_frequency_recomputed',np.max(abs(np.array(found)-case['frequencyHz'])),2e-8)
        check(case['name']+'_frequency_split',abs((found[1]-found[0])-(frequency[1]-frequency[0])),p['acceptance']['bias_frequency_split_error_hz'])
        bycase[(case['voltageV'],case['mode'],case['stepS'])]=data
    for V in (p['reference_bias_v'],p['bias_holdout_v']):
        for h in (p['carrier_reference_step_s'],p['carrier_reference_step_s']/2):
            bare=bycase[(V,'bare',h)];reference=bycase[(V,'reference',h)]
            check(f'bias_V{V}_h{h}_equivalent_representation',np.max(abs(bare-reference)),p['acceptance']['bias_representation_state_difference'])
        for mode in ('bare','reference','double_count'):
            coarse=bias_errors[(V,mode,p['carrier_reference_step_s'])]
            fine=bias_errors[(V,mode,p['carrier_reference_step_s']/2)]
            check(f'bias_V{V}_{mode}_physical_convergence',fine/coarse,.12)
    wrong=next(c for c in report['biasCases'] if c['mode']=='double_count' and c['voltageV']==p['reference_bias_v'] and c['stepS']==p['carrier_reference_step_s']/2)
    false_split=abs(np.diff(wrong['frequencyHz'])[0])
    check('double_count_mutant_detected',float(false_split<p['acceptance']['bias_mutant_minimum_false_split_hz']),0)
    rf=None
    if not args.core_only:
        rf=read(E/'rf_study.json');assert rf['pass']
        for k,case in enumerate(rf['cases']):
            nav=csv(f'rf_{k}_navigation.csv');valid=nav[:,3]>.5;first=np.flatnonzero(valid)[0];use=valid&(nav[:,0]>=.5)
            error=(nav[:,1]-nav[first,1])*180/np.pi-80*(nav[:,0]-nav[first,0])
            rms=float(np.sqrt(np.mean(error[use]**2)))
            check(f'RF_{k}_angle_CSV_recompute',abs(rms-case['directAngle']['rmsDeg']),1e-9)
        fixture=csv('rf_independent_fixture.csv');x=fixture[:,:2]+1j*fixture[:,2:4];y=fixture[:,4:6]+1j*fixture[:,6:8]
        fit=read(E/'rf_frozen_fit.json');inv=np.array(fit['inverseReal'])+1j*np.array(fit['inverseImag'])
        for j in range(2):
            X=np.column_stack((x[:,j],abs(x[:,j])**2*x[:,j]));coef=np.linalg.lstsq(X,y[:,j],rcond=None)[0]
            check(f'RF_fixture_axis{j}_inverse',abs(1/coef[0]-inv[j,j]),1e-11)
            check(f'RF_fixture_axis{j}_cubic',abs((coef[1]/coef[0]).real-fit['cubicCoefficient'][j]),1e-11)
    preserved={}
    for name in ('literature_v7','literature_v8_research','literature_zotero_research'):
        path=ROOT.parent/name/'evidence/manifest.json';manifest=read(path)
        if 'sha256' in manifest:
            for rel,value in manifest['sha256'].items():assert hashlib.sha256((REPO/rel).read_bytes()).hexdigest()==value,rel
            preserved[name]=len(manifest['sha256'])
        else:
            v=json.loads(subprocess.run([sys.executable,str(path.parents[1]/'tools/verify.py')],capture_output=True,text=True,check=True).stdout)
            preserved[name]=v['hashes']
    receipt=dict(date='2026-10-26',checks=checks,pass_=all(c['pass_'] for c in checks),false_split_hz=false_split,
        rf_improvement_ratio=None if rf is None else rf['angleImprovementRatio'],preserved=preserved,
        evidence_level='Independent model and numerical consistency; no physical metrology or outside certification')
    target=E/('core_verification.json' if args.core_only else 'verification.json')
    target.write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    print(json.dumps(dict(pass_=receipt['pass_'],checks=len(checks),false_split_hz=false_split,rf_improvement_ratio=receipt['rf_improvement_ratio'],preserved=preserved)))
    assert receipt['pass_'],'Independent scoreboard failed; retain evidence'

if __name__=='__main__':main()
