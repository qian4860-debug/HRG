"""离线评分：验证相同全局原点、完整待发/拒绝区间及声明故障行为。"""
import json
import numpy as np
from a3_common import HERE,config,read_json,write_json
from a2_score import truth_angle


def rms(v):return float(np.sqrt(np.mean(np.asarray(v)**2)))


def score():
    truth=read_json(HERE/'data/private_score/truth.json')['cases'];rows=[]
    for window in [40,240]:
        cfg=config(window);folder=HERE/'evidence'/('window_'+str(window));estimates=read_json(folder/'estimates.json')['cases']
        assert len(truth)==len(estimates)
        for target,result in zip(truth,estimates):
            cid=target['id'];assert cid==result['id'];f=np.loadtxt(folder/(cid+'_frames.csv'),delimiter=',',skiprows=1)
            data=read_json(HERE/'data/observations'/(cid+'.json'));valid=f[:,5]==1;warm=f[:,0]>=cfg['warmup_s'];r=result['original_reference_frame']
            expected_cal=target['calibration_should_pass'];nonwhite=target['fault_kind']=='nonwhite_noise'
            finite=np.isfinite(f[:,7])&np.isfinite(f[:,8]);telescope=np.isfinite(f[:,20]);error=np.full(len(f),np.nan)
            checks=dict(calibration=result['calibration']['passed']==expected_cal,
                noise_model_screen=result['noise_model_check']['passed']==(not nonwhite),
                invalid_not_published=bool(np.all(np.isnan(f[~valid,4]))),
                fixed_and_reanchor_angles=bool(np.allclose(f[:,3],f[:,27],rtol=0,atol=1e-12,equal_nan=True)),
                fixed_and_reanchor_decisions=bool(np.array_equal(f[:,5],f[:,28])),
                joint_no_larger_than_cauchy=bool(np.all(f[finite,7]<=f[finite,8]+1e-14)),
                reanchor_keeps_origin_variance=bool(np.allclose(f[telescope,20],f[telescope,7]**2,rtol=1e-10,atol=1e-20)))
            if r is not None:
                refangle=truth_angle(f[:,1],target);refangle-=refangle[r];error=f[:,3]-refangle
                checks['no_future_origin_metadata']=bool(np.all(np.isnan(f[:r,14])) and np.all(f[:r,21]==-1))
                checks['reference_wait_not_published']=not bool(np.any(valid & (f[:,0]-f[r,0]<cfg['reference_holdoff_s']-1e-12)))
            else:checks['no_origin_no_publication']=not bool(np.any(valid))
            if np.any(valid):checks['published_angle_budget']=rms(error[valid])<=cfg['angle_budget_rad']
            if not expected_cal or nonwhite or target['low_amplitude']:
                checks['reject_entire_case']=not bool(np.any(valid))
            sigma=data['stream_noise_RMS_V'];fault=target['fault_kind']
            if expected_cal and not target['low_amplitude'] and not nonwhite and fault in ['none','fresh_noise_seed']:
                ready=(f[:,0]>=cfg['warmup_s']) & (f[:,0]-f[r,0]>=cfg['reference_holdoff_s']-1e-12)
                if sigma==500e-6:
                    checks['500u_expected_window_behavior']=bool(np.all(valid[ready])) if window==240 else not bool(np.any(valid))
                elif sigma==1e-3:checks['1mV_rejected']=not bool(np.any(valid))
                else:checks['ordinary_ready_frames_publish']=bool(np.all(valid[ready]))
                checks['reanchor_exercised']=result['final_anchor_count']>=2
            if fault=='short_dropout':
                checks['short_dropout_recovers']=not result['needs_external_reference'] and bool(np.all(valid[f[:,0]>.71]))
                checks['fault_and_guard_withheld']=not bool(np.any(valid & (f[:,0]>=.650025)&(f[:,0]<.680025-1e-12)))
            if fault=='long_dropout':
                checks['ambiguous_global_stays_invalid']=result['needs_external_reference'] and not bool(np.any(valid[f[:,0]>=.650025]))
                checks['local_diagnostic_not_global']=bool(np.any(np.isfinite(f[f[:,0]>.82,19]))) and bool(np.all(np.isnan(f[f[:,0]>.82,3])))
            if fault=='initial_dropout':
                checks['initial_wait_then_new_origin']=r is not None and f[r,0]>=.31 and not bool(np.any(valid[f[:,0]<.33]))
            rows.append(dict(id=cid,window_samples=window,noise_RMS_V=sigma,fault_kind=fault,
                fresh_seed=fault=='fresh_noise_seed',reference_frame=r,joint_valid_fraction=result['post_warmup_joint_valid_fraction'],
                cauchy_valid_fraction=result['post_warmup_cauchy_valid_fraction'],after_holdoff_valid_fraction=result['after_reference_holdoff_joint_valid_fraction'],
                published_RMS_rad=rms(error[valid]) if np.any(valid) else None,
                all_observable_candidate_RMS_rad=rms(error[np.isfinite(error)&warm]) if np.any(np.isfinite(error)&warm) else None,
                maximum_published_error_rad=float(np.max(abs(error[valid]))) if np.any(valid) else None,
                source_delay_s=result['source_delay_s'],final_anchor_count=result['final_anchor_count'],
                needs_external_reference=result['needs_external_reference'],checks=checks,passed=all(checks.values())))
    summary=dict(profile_case_comparisons=len(rows),checks_matched=sum(r['passed'] for r in rows),
        fresh_seed_comparisons=sum(r['fresh_seed'] for r in rows),scope='合成白噪/冻结W/声明速率界；全局原点未重置；非硬件或闭环稳定性通过')
    write_json(HERE/'evidence/scores.json',dict(summary=summary,cases=rows));print(json.dumps(summary,ensure_ascii=False,indent=2))
    failed=[(r['id'],r['window_samples'],r['checks']) for r in rows if not r['passed']]
    if failed:raise AssertionError(failed)
    return rows


if __name__=='__main__':score()
