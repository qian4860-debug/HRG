"""A1离线评分：此文件可以读取合成真值，估计器不可调用它。"""
from pathlib import Path
import json
import numpy as np
from a1_fit import HERE,read_json,write_json


def score():
    truth=read_json(HERE/'data/private_score/truth.json')['cases']
    limits=read_json(HERE/'acceptance.json');allrows=[]
    for mode in ['joint_loading','no_loading','raw_second_order']:
        rows=read_json(HERE/'evidence'/mode/'estimates.json')['cases']
        assert len(rows)==len(truth)==9
        for t,r in zip(truth,rows):
            assert t['id']==r['id'];h=np.asarray(t['H']);hi=np.linalg.inv(h)
            errors={n:float(np.linalg.norm(np.asarray(r[n])-h@np.asarray(t[n])@hi)/np.linalg.norm(h@np.asarray(t[n])@hi)) for n in ['D','K']}
            kerror=abs(r['kappa']-t['kappa'])/t['kappa']
            angles=np.loadtxt(HERE/'evidence'/mode/(r['id']+'_angles.csv'),delimiter=',',skiprows=1)
            reference=np.asarray(t['motion_reference_rad'])
            assert len(reference)==len(angles)
            rms=lambda x:float(np.sqrt(np.mean(x*x)))
            angle_error=rms(angles[:,2]-reference) if np.all(np.isfinite(angles[:,2])) else None
            expected=t['expected_eligible'] if mode=='joint_loading' else False
            checks=dict(expected_eligibility=r['eligible']==expected)
            if expected:
                checks.update(D=errors['D']<=limits['positive_D_relative'],K=errors['K']<=limits['positive_K_relative'],
                    kappa=kerror<=limits['positive_kappa_relative'],angle=angle_error is not None and angle_error<=limits['positive_angle_rms_rad'],
                    publication_finite=bool(np.all(np.isfinite(angles[:,3]))))
            else:checks['rejected_angle_nan']=bool(np.all(np.isnan(angles[:,3])))
            allrows.append(dict(id=r['id'],mode=mode,kind=t['kind'],independent_parameter_seed=t['independent'],
                noise_sigma_V=t['phasor_noise_sigma_V'],expected_eligible=expected,eligible=r['eligible'],checks=checks,
                passed=all(checks.values()),D_relative_error=errors['D'],K_relative_error=errors['K'],kappa_relative_error=kerror,
                raw_angle_rms_rad=rms(angles[:,1]-reference),candidate_angle_rms_rad=angle_error,
                heldout_max_relative=r['maximum_validation_relative_error'],reason=r['reason']))
    summary=dict(comparisons=len(allrows),checks_matched=sum(r['passed'] for r in allrows),
        primary_cases=9,primary_accepted=sum(r['eligible'] for r in allrows if r['mode']=='joint_loading'),
        primary_rejected=sum(not r['eligible'] for r in allrows if r['mode']=='joint_loading'),
        scope='SI合成静止线性端口；无噪正例、夹具依赖校准；不证明无参考或高噪性能')
    write_json(HERE/'evidence/scores.json',dict(summary=summary,cases=allrows))
    print(json.dumps(summary,ensure_ascii=False,indent=2))
    failed=[(r['id'],r['mode'],r['checks']) for r in allrows if not r['passed']]
    if failed:raise AssertionError(failed)
    return allrows


if __name__=='__main__':score()
