"""Independent CSV geometry scoreboard and exact-byte preservation check."""
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
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--seal',action='store_true');args=parser.parse_args()
    if args.seal:
        for p in ROOT.rglob('*'):
            if p.is_file() and p.suffix in {'.m','.py','.json','.md','.csv','.txt'}:
                raw=p.read_bytes();lf=raw.replace(b'\r\n',b'\n')
                if raw!=lf:p.write_bytes(lf)
    study=read(E/'carrier_study.json');audit=read(E/'quantization_audit.json')
    assert study['pass'] and all(c['pass'] for c in study['checks']) and audit['pass_']
    probe=read(E/'phase_probe_study.json');assert probe['pass_']
    assert [c['update_allowed'] for c in probe['cases']]==[True,True,False,False,False]
    checks=[]
    def check(name,error,limit):
        assert np.isfinite(error) and error<=limit,(name,error,limit)
        checks.append(dict(name=name,error=float(error),limit=float(limit)))
    nav=np.loadtxt(E/'carrier_direct_navigation.csv',delimiter=',')
    old=np.loadtxt(E/'carrier_legacy_navigation.csv',delimiter=',')
    iq=np.loadtxt(E/'carrier_iq.csv',delimiter=',')
    base=np.loadtxt(ROOT.parent/'literature_v8_research/evidence/hrg_wa_v8_carrier_2_iq.csv',delimiter=',')
    assert nav.shape==old.shape and iq.shape==base.shape
    check('same_public_sample_timestamps',np.max(abs(nav[:,0]-iq[:,0])),1e-12)
    check('sealed_V8_22bit_IQ_codes',np.max(abs(np.rint(iq[:,1:]*2**22)-np.rint(base[:,1:]*2**22))),0)
    profile=REPO/'HRG_WA_Digital_ASIC_MATLAB_v4_6_5_FRP_validation_fix/HRG_WA/config/head_default.json'
    B=read(profile)['mechanical']['bryan'];assert B==.277
    use=nav[:,3]>.5;epoch=np.flatnonzero(use)[0]
    # Complex principal-axis identity from the measured IQ, independent of the
    # MATLAB state machine; no access to mechanical truth or fitted correction.
    cx,cy,sx,sy=iq[use,1:].T
    W=cx*cx+sx*sx-cy*cy-sy*sy+2j*(cx*cy+sx*sy)
    theta=np.unwrap(np.angle(W))/4
    relative=-(theta-theta[0])/B
    check('IQ_geometry_equals_direct_navigation',np.max(abs(relative-(nav[use,1]-nav[epoch,1]))),1e-11)
    for label,data,reference in [('direct',nav,study['directAngle']),('legacy',old,study['legacyAcceptance']['angle'])]:
        index=np.flatnonzero(data[:,3]>.5)[0]
        mask=(data[:,0]>=.5)&(data[:,3]>.5)
        error=(data[:,1]-data[index,1])*180/np.pi-80*(data[:,0]-data[index,0])
        rms=float(np.sqrt(np.mean(error[mask]**2)));peak=float(np.max(abs(error[mask])))
        check(label+'_RMS_from_CSV',abs(rms-reference['rmsDeg']),1e-10)
        check(label+'_peak_from_CSV',abs(peak-reference['peakDeg']),1e-10)
    for rate in study['spectrumRates']:
        check('spectrum_rate_'+rate['name'],abs(rate['sampleTimeS']*rate['sampleRateHz']-1),1e-10)
    v8=read(ROOT.parent/'literature_v8_research/evidence/manifest.json')['sha256']
    for name,value in v8.items():assert digest(REPO/name)==value,('Changed sealed dependency',name)
    run=subprocess.run([sys.executable,str(ROOT.parent/'literature_v7/tools/verify.py')],capture_output=True,text=True,check=True)
    v7=json.loads(run.stdout)
    receipt=dict(date='2026-10-24',pass_=True,checks=checks,original_v7=v7,
        sealed_v8_dependencies=len(v8),matlab_checks=len(study['checks']),formula_checks=len(audit['checks']),
        averaged_probe_cases=len(probe['cases']),
        direct_rms_deg=study['directAngle']['rmsDeg'],legacy_rms_deg=study['legacyAcceptance']['angle']['rmsDeg'],
        scope_count=study['scopes'],spectrum_count=study['spectra'],
        boundary='Independent replay and byte preservation; synthetic fixture, noise disabled, no hardware qualification')
    target=E/'verification.json'
    encoded=json.dumps(receipt,ensure_ascii=False,indent=2)+'\n'
    if args.seal:target.write_text(encoded,encoding='utf-8',newline='\n')
    else:assert read(target)==receipt
    manifest=E/'manifest.json'
    files=[p for p in ROOT.rglob('*') if p.is_file() and p!=manifest and '__pycache__' not in p.parts]
    hashes={p.relative_to(REPO).as_posix():digest(p) for p in sorted(files)}
    if args.seal:manifest.write_text(json.dumps(dict(date='2026-10-24',sha256=hashes),indent=2)+'\n',encoding='utf-8',newline='\n')
    else:assert read(manifest)['sha256']==hashes,'Unsealed or changed artifact'
    print(json.dumps(receipt,ensure_ascii=True))

if __name__=='__main__':main()
