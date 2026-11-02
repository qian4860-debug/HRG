from pathlib import Path
import argparse,json,hashlib,re
import numpy as np
HERE=Path(__file__).resolve().parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def score(iq,valid,t,p):
    I=iq[:,:2];Q=iq[:,2:];E=np.sum(iq**2,axis=1);N=I[:,0]**2+Q[:,0]**2-I[:,1]**2-Q[:,1]**2;M=2*(I[:,0]*I[:,1]+Q[:,0]*Q[:,1])
    # Only these declared cases have no invalid segments and no virtual rate.
    assert np.all(valid==1) and p['virtual_rate']==0
    beta=np.unwrap(np.arctan2(M,N))/4;truth=(p['theta0']-2*p['B']*p['Omega']*t)/2;h=t>.6*p['duration']
    return float(np.sqrt(np.mean(((beta[h]-truth[h])/p['B']*180/np.pi)**2)))
def verify():
    d=json.loads((HERE/'evidence/results.json').read_text());s=json.loads((HERE/'evidence/scoreboard.json').read_text());assert len(d)==12 and len(s)==5 and all(s.values())
    dirs={re.sub('[^a-zA-Z0-9_]','_',p.name):p.name for p in (HERE/'evidence').iterdir() if p.is_dir()}
    for key,v in d.items():
        p=v['p'];f=np.loadtxt(HERE/'evidence'/dirs[key]/'raw_estimated_truth.csv',delimiter=',');t=f[:,0];assert len(t)==800
        for cols,expected in [(slice(1,5),v['after']['metrics']['angle_rms_deg']),(slice(5,9),v['raw_observation']['angle_rms_deg']),(slice(10,14),v['mechanical_truth']['angle_rms_deg'])]:
            assert abs(score(f[:,cols],f[:,9],t,p)-expected)<1e-9,key
        assert v['physical_pass']==(v['mechanical_truth']['angle_rms_deg']<.1 and v['mechanical_truth']['quadrature_rms']<1e-3 and v['mechanical_truth']['pll_phase_rms']<1e-3)
        assert v['passed']==(all(v['after']['checks'].values()) and v['physical_pass'])
    n=32;lag=np.arange(n);X=np.c_[np.ones(n),-lag];h=np.array([1,0])@np.linalg.solve(X.T@X,X.T)
    assert abs(h.sum()-1)<1e-14 and abs(h@lag)<1e-12
    responses={str(f):dict(gain=float(abs(H)),phase_deg=float(np.angle(H,deg=True))) for f in [1,5,10,20] for H in [h@np.exp(-2j*np.pi*f*lag/1000)]}
    assert abs(responses['5']['gain']-1)<.1 and abs(responses['5']['phase_deg'])<5
    c=json.loads((HERE/'evidence/filter_tests.json').read_text())['checks'];assert len(c)==4 and all(c.values())
    for name,value in json.loads((HERE/'source_hashes.json').read_text()).items():assert sha(HERE.parent/'compensation_research'/name)==value
    tick=(HERE/'sn_tick.m').read_text(encoding='utf-8');assert 'r.clean' not in tick and 'p.Omega' not in tick
    return dict(cases=12,quality_and_physical_pass=sum(v['passed'] for v in d.values()),five_simulink_scoreboards=True,independent_three_output_scores=True,noise_variance_gain=float(h@h),frequency_responses=responses)
def files():return {p.relative_to(HERE).as_posix():sha(p) for p in sorted(HERE.rglob('*')) if p.is_file() and p.suffix in {'.m','.py','.json','.csv','.txt','.md','.html','.png','.slx'} and p.name!='manifest.json' and '__pycache__' not in p.parts}
def main():
    a=argparse.ArgumentParser();a.add_argument('--seal',action='store_true');args=a.parse_args();r=verify()
    if args.seal:
        for p in HERE.rglob('*'):
            if p.is_file() and p.suffix in {'.m','.py','.json','.csv','.txt','.md','.html'}:
                b=p.read_bytes();n=b.replace(b'\r\n',b'\n')
                if b!=n:p.write_bytes(n)
        (HERE/'evidence/independent_results.json').write_text(json.dumps(r,indent=2)+'\n',encoding='utf-8',newline='\n');(HERE/'manifest.json').write_text(json.dumps({'date':'2026-11-02','files':files()},ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    assert files()==json.loads((HERE/'manifest.json').read_text(encoding='utf-8'))['files'];print('PASS:',r)
if __name__=='__main__':main()
