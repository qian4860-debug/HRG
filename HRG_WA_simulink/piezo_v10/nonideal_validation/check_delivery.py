"""Independent per-frame arithmetic; failed quality points are valid evidence."""
from pathlib import Path
import argparse,hashlib,json
import numpy as np
HERE=Path(__file__).resolve().parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def verify():
    data=json.loads((HERE/'evidence/all_results.json').read_text());score=json.loads((HERE/'evidence/scoreboard.json').read_text())
    assert len(data)==len(score)==18 and all(score.values())
    for name,item in data.items():
        case=item['case'];p=case['p'];r=item['report'];f=np.genfromtxt(HERE/'evidence'/case['id']/'quality_frames.csv',delimiter=',',names=True)
        t=f['source_center_s'];h=(t>.6*p['duration'])&(f['valid']==1)
        assert len(t)==round(p['duration']/p['Tc']) and np.all(np.diff(t)>0)
        def rms(x):return float(np.sqrt(np.mean(x[h]**2)))
        energy=float(np.mean(f['energy_normalized'][h]));quad=rms(f['quadrature']);pll=rms(f['PLL_detector']);angle=rms(f['body_angle_error_deg'])
        assert abs(energy-r['normalized_energy_mean'])<1e-11
        assert abs(quad-r['quadrature_RMS'])<1e-11 and abs(pll-r['PLL_detector_RMS'])<1e-11
        assert abs(angle-r['metrics']['angle_rms_deg'])<1e-10
        err=max(np.max(abs(f[n]-target)) for n,target in [('window_us',(p['Tc']-p['Ts'])*1e6),('center_offset_us',(p['Tc']-p['Ts'])*.5e6),('publication_delay_us',p['Ts']*1e6)])
        checks=dict(valid_fraction=float(np.mean(f['valid']))>=.95,normalized_energy=abs(energy-1)<.05,quadrature=quad<1e-3,PLL_detector=pll<1e-3,timestamps=err<1e-6,body_angle=angle<.1,no_DAC_clip=r['metrics']['dac_clip_samples']==0)
        assert checks==r['checks'] and all(checks.values())==item['passed'],name
    # Source report executable content is unchanged except name/root/output directory.
    src=HERE.parent/'quality_dashboard/quality_report.m';s=src.read_text(encoding='utf-8')
    expected=s.replace('function report=quality_report(out,p,visible)','function report=stress_report(out,p,visible,caseid)').replace('root=quality_setup;if nargin<3,visible=true;end',"root=stress_setup;if nargin<3,visible=true;end;if nargin<4,caseid='manual';end").replace("folder=fullfile(root,'evidence');","folder=fullfile(root,'evidence',caseid);")
    assert expected==(HERE/'stress_report.m').read_text(encoding='utf-8')
    old=HERE.parent/'revision_v10_2_cn';m=json.loads((old/'manifest.json').read_text(encoding='utf-8'))
    for n,h in m['files'].items():assert sha(old/n)==h,n
    return {'cases':18,'quality_pass':sum(x['passed'] for x in data.values()),'quality_fail':sum(not x['passed'] for x in data.values()),'all_execution_scoreboards_pass':True,'all_independent_scores_match':True}
def files():
    return {p.relative_to(HERE).as_posix():sha(p) for p in sorted(HERE.rglob('*')) if p.is_file() and p.suffix in {'.m','.py','.md','.json','.csv','.txt','.html','.png'} and p.name!='manifest.json' and '__pycache__' not in p.parts}
def main():
    a=argparse.ArgumentParser();a.add_argument('--seal',action='store_true');args=a.parse_args();result=verify()
    if args.seal:
        for p in HERE.rglob('*'):
            if p.is_file() and p.suffix in {'.m','.py','.md','.json','.csv','.txt','.html'}:
                b=p.read_bytes();n=b.replace(b'\r\n',b'\n')
                if b!=n:p.write_bytes(n)
        (HERE/'evidence/independent_results.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n')
        (HERE/'manifest.json').write_text(json.dumps({'date':'2026-11-02','files':files()},ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    assert files()==json.loads((HERE/'manifest.json').read_text(encoding='utf-8'))['files'];print('PASS delivery/scoreboard:',result)
if __name__=='__main__':main()
