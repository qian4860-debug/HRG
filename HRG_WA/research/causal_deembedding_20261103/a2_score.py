"""离线评分器：真运动仅在这里读取；不反写滤波参数、门限和发布决定。"""
import json
import numpy as np
from a2_dsp import HERE,read_json,write_json,synthesize,CausalFrontend,orientation


def truth_angle(t,record):
    v=np.exp(1j*record['nominal_modal_rate_rad_s']*t)+record['modulation_fraction']*np.exp(1j*record['modulation_rate_rad_s']*t)
    return np.unwrap(np.angle(v))


def rms(v):return float(np.sqrt(np.mean(np.asarray(v)**2)))


def score():
    cfg0=read_json(HERE/'config.json');truth=read_json(HERE/'data/private_score/truth.json')['cases'];rows=[]
    for window in [cfg0['demod_window_samples'],cfg0['comparison_demod_window_samples']]:
        cfg=dict(cfg0,demod_window_samples=window);folder=HERE/'evidence'/('window_'+str(window))
        estimates=read_json(folder/'estimates.json')['cases'];assert len(truth)==len(estimates)==15
        for target,result in zip(truth,estimates):
            assert target['id']==result['id'];cid=target['id']
            frames=np.loadtxt(folder/(cid+'_frames.csv'),delimiter=',',skiprows=1)
            t,source=frames[:,0],frames[:,3];ref=result['reference_frame_index'];warm=t>=cfg['warmup_s'];valid=frames[:,7]==1
            correct=truth_angle(source,target);correct-=correct[ref]
            unstamped=truth_angle(t,target);unstamped-=unstamped[ref]
            error=frames[:,5]-correct;uncompensated=frames[:,5]-unstamped
            checks=dict(calibration_decision=result['calibration']['passed']==target['calibration_should_pass'],
                warmup_not_published=bool(np.all(np.isnan(frames[~warm,6]))),
                invalid_not_published=bool(np.all(np.isnan(frames[~valid,6]))),
                time_ordering=bool(np.all(frames[:,1]<=frames[:,2]) and np.all(frames[:,2]<=frames[:,0]) and np.all(source<t)))
            checks['publication_and_source_timestamps']=bool(np.allclose(frames[:,0]-frames[:,17],1/cfg['sample_rate_Hz'],rtol=0,atol=1e-14)
                and np.allclose(frames[:,17]-frames[:,2],(window-1)/cfg['sample_rate_Hz'],rtol=0,atol=1e-14)
                and np.allclose(frames[:,0]-source,result['source_delay_s'],rtol=0,atol=1e-14))
            if not target['calibration_should_pass'] or target['low_amplitude']:
                checks['reject_entire_case']=not bool(np.any(valid))
            else:
                checks['published_angle_budget']=not np.any(valid) or rms(error[valid])<=cfg['angle_budget_rad']
            if cid in ['case_001','case_002','case_003']:
                checks['noiseless_publication']=bool(np.all(valid[warm]))
                checks['timestamp_improves_dynamic_angle']=rms(error[warm])*4<rms(uncompensated[warm])
            noise_ratio=None
            data=read_json(HERE/'data/observations'/(cid+'.json'))
            if data['stream_noise_RMS_V']>0 and target['calibration_should_pass'] and not target['low_amplitude']:
                _,u,clean=synthesize(data,cfg,with_noise=False)
                e=CausalFrontend(data['calibration'],cfg).process(u,clean)['envelope'][::cfg['frame_decimation']]
                a=orientation(e,data['calibration']['W'])['absolute_coordinate_angle']
                noise_angle=.5*np.angle(np.exp(2j*(frames[:,4]-a)))
                predicted=rms(frames[warm,12]);observed=rms(noise_angle[warm]);noise_ratio=observed/predicted
                checks['white_noise_propagation']=.65<=noise_ratio<=1.35
                if cid=='case_007':
                    nominal=np.loadtxt(folder/'case_001_frames.csv',delimiter=',',skiprows=1)
                    difference=(a-a[ref])-nominal[:,5]
                    checks['one_bounded_calibration_sensitivity']=float(np.max(abs(difference[warm])))<=1.1*float(np.max(frames[warm,14]))+5e-6
            rows.append(dict(id=cid,window_samples=window,kind=target['calibration_kind'],
                modal_direction_rate_rad_s=target['nominal_modal_rate_rad_s'],noise_RMS_V=data['stream_noise_RMS_V'],
                extra_seed=target['extra_seed'],calibration_pass=result['calibration']['passed'],
                valid_fraction=result['post_warmup_valid_fraction'],source_delay_s=result['source_delay_s'],
                phase_budget_use_rad=result['delay_phase_use_rad'],correct_timestamp_RMS_rad=rms(error[warm]),
                available_timestamp_RMS_rad=rms(uncompensated[warm]),
                published_RMS_rad=rms(error[valid]) if np.any(valid) else None,
                maximum_published_error_rad=float(np.max(abs(error[valid]))) if np.any(valid) else None,
                noise_observed_to_predicted_RMS_ratio=noise_ratio,checks=checks,passed=all(checks.values())))
    summary=dict(profile_case_comparisons=len(rows),checks_matched=sum(r['passed'] for r in rows),
        scope='每帧选择性发布；500μV长窗仅部分帧达预算；不是全工况或真实闭环通过')
    write_json(HERE/'evidence/scores.json',dict(summary=summary,cases=rows));print(json.dumps(summary,ensure_ascii=False,indent=2))
    failed=[(r['id'],r['window_samples'],r['checks']) for r in rows if not r['passed']]
    if failed:raise AssertionError(failed)
    return rows


if __name__=='__main__':score()
