"""Independent XML and row-assembly checks; no MATLAB control kernel calls."""
from pathlib import Path
import json,re,zipfile,xml.etree.ElementTree as ET
import numpy as np
HERE=Path(__file__).resolve().parent
def main():
    with zipfile.ZipFile(HERE/'models/hrg_wa_v10_2_modules.slx') as z:
        groups=[];delays=0
        for name in z.namelist():
            if name.startswith('simulink/systems/') and name.endswith('.xml'):
                root=ET.fromstring(z.read(name))
                for b in root.iter('Block'):
                    if b.get('BlockType')=='UnitDelay':delays+=1
                    for p in b.findall('P'):
                        if p.get('Name')=='Gain' and (p.text or '').startswith('Ad('):groups.append([int(x)-1 for x in re.findall(r'\d+',p.text)])
    checks={'five_state_owners':delays==5,'each_state_owned_once':sorted(sum(groups,[]))==list(range(12))}
    old=HERE.parent/'revision_v10_1/evidence';A=np.loadtxt(old/'Ad.csv',delimiter=',');B=np.loadtxt(old/'Bd.csv',delimiter=',')
    rng=np.random.default_rng(20261102);worst=0.
    # Dimensionless random states include all reciprocal coupling entries.
    scale=np.array([1e-11]*2+[6e-8]*2+[1.]*2+[6e-5]*2+[.1]*4)
    for _ in range(200):
        x=rng.normal(size=12)*scale;u=rng.normal(size=2);assembled=np.empty(12)
        for rows in groups:assembled[rows]=A[rows]@x+B[rows]@u
        worst=max(worst,float(np.max(abs(assembled-(A@x+B@u))/scale)))
    checks['joint_update_independent_random_vectors']=worst<1e-12
    r=json.loads((HERE/'evidence/results.json').read_text());checks['all_three_closed_loop_cases']=len(r['cases'])==3 and all(r['checks'].values())
    audit=json.loads((HERE/'evidence/reference_audit.json').read_text())
    checks['fifteen_reference_models_audited']=len(audit['models'])==15
    checks['source_external_dependency_identified']=any('SDtoolbox' in x for m in audit['models'] for x in m['library_references'])
    result=dict(checks=checks,max_normalized_row_assembly_error=worst,scope='Structural and shared-ZOH integrity; no independent claim of hardware validity')
    (HERE/'evidence/independent_results.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n')
    assert all(checks.values()),result;print('PASS',len(checks),'independent structure checks')
if __name__=='__main__':main()
