from pathlib import Path
import argparse,hashlib,json
import numpy as np
HERE=Path(__file__).resolve().parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def verify():
    results=json.loads((HERE/'evidence/results.json').read_text());scores=json.loads((HERE/'evidence/scoreboard.json').read_text())
    assert len(results)==21 and len(scores)==7 and all(scores.values())
    for v in results.values():
        p=v['case']['p'];r=v['after'];t=np.genfromtxt(HERE/'evidence'/v['case']['id']/'quality_frames.csv',delimiter=',',names=True)
        h=(t['valid']==1)&(t['source_center_s']>.6*p['duration'])
        assert len(t)==800 and np.all(np.diff(t['source_center_s'])>0)
        rms=lambda n:float(np.sqrt(np.mean(t[n][h]**2)))
        assert abs(rms('body_angle_error_deg')-r['metrics']['angle_rms_deg'])<1e-10
        assert abs(rms('quadrature')-r['quadrature_RMS'])<1e-10
        assert abs(rms('PLL_detector')-r['PLL_detector_RMS'])<1e-10
        assert abs(float(np.mean(t['energy_normalized'][h]))-r['normalized_energy_mean'])<1e-10
        checks=dict(valid_fraction=float(np.mean(t['valid']))>=.95,normalized_energy=abs(r['normalized_energy_mean']-1)<.05,quadrature=rms('quadrature')<1e-3,PLL_detector=rms('PLL_detector')<1e-3,timestamps=r['timestamp_max_error_us']<1e-6,body_angle=rms('body_angle_error_deg')<.1,no_DAC_clip=r['metrics']['dac_clip_samples']==0)
        assert checks==r['checks'] and all(checks.values())==v['passed']
    profiles=json.loads((HERE/'independent_profiles.json').read_text());rng=np.random.default_rng(1102);error=0.
    for v in profiles.values():
        assert v['holdout']['detect']<2e-5 and v['holdout']['drive']<2e-5 and v['holdout']['mechanical_absolute_RMS']<4e-5
        K=np.array(v['dK']);D=np.array(v['dD']);w=2*np.pi*1000
        for _ in range(20):
            C=rng.normal(size=2)+1j*rng.normal(size=2);e=np.exp(1j*rng.uniform(-np.pi,np.pi))
            f1=K@(C*e).real+D@(1j*w*C*e).real;f2=((K+1j*w*D)@C*e).real
            error=max(error,float(np.max(abs(f1-f2))/max(1,np.max(abs(f1)))))
    assert error<1e-12
    ab=json.loads((HERE/'evidence/startup_and_uncertainty.json').read_text())
    assert ab['early1_zero1']['angle_rms_deg']<ab['early0_zero0']['angle_rms_deg']
    assert ab['early0_zero1']['angle_rms_deg']>ab['early0_zero0']['angle_rms_deg']
    assert ab['ten_percent_tensor_error']['angle_rms_deg']<.1
    tick=(HERE/'comp_tick.m').read_text(encoding='utf-8');assert all(n not in tick for n in ['p.Omega','p.theta0','p.split_hz','p.stiffness_axis','p.damping_half_difference','p.damping_axis'])
    src=(HERE.parent/'nonideal_validation/stress_report.m').read_text(encoding='utf-8').replace('stress_report','comp_report').replace('root=stress_setup','root=comp_setup');assert src==(HERE/'comp_report.m').read_text(encoding='utf-8')
    for n,h in json.loads((HERE/'source_hashes.json').read_text()).items():assert sha(HERE.parent/'revision_v10_2_cn'/n)==h
    return dict(cases=21,quality_pass=sum(v['passed'] for v in results.values()),holdouts_pass=sum(v['passed'] for k,v in results.items() if k.startswith('holdout')),seven_simulink_scoreboards=True,independent_scores_match=True,tensor_sign_error=error)
def snapshot():
    return {p.relative_to(HERE).as_posix():sha(p) for p in sorted(HERE.rglob('*')) if p.is_file() and p.suffix in {'.m','.py','.md','.json','.csv','.txt','.html','.png','.slx'} and p.name!='manifest.json' and '__pycache__' not in p.parts}
def main():
    a=argparse.ArgumentParser();a.add_argument('--seal',action='store_true');args=a.parse_args();r=verify()
    if args.seal:
        for p in HERE.rglob('*'):
            if p.is_file() and p.suffix in {'.m','.py','.md','.json','.csv','.txt','.html'}:
                b=p.read_bytes();n=b.replace(b'\r\n',b'\n')
                if b!=n:p.write_bytes(n)
        (HERE/'evidence/independent_results.json').write_text(json.dumps(r,indent=2)+'\n',encoding='utf-8',newline='\n')
        (HERE/'manifest.json').write_text(json.dumps({'date':'2026-11-02','files':snapshot()},ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    assert snapshot()==json.loads((HERE/'manifest.json').read_text())['files'];print('PASS:',r)
if __name__=='__main__':main()
