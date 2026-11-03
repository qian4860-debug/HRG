"""仅用公开流、电路/噪声校准和冻结W处理；原始时域噪声用于源，不用于预算。"""
import argparse
import json
import numpy as np
from a2_dsp import (HERE,read_json,write_json,write_csv,sha,CausalFrontend,synthesize,
    orientation,delay_seconds,calibration_check,noise_upper,angle_sigma,corner_sensitivity,response)


def process_case(data,cfg):
    t,u,y=synthesize(data,cfg);cal=data['calibration'];front=CausalFrontend(cal,cfg)
    signals=front.process(u,y);coeff=front.coefficients
    indices=np.arange(0,len(t),cfg['frame_decimation']);tf=t[indices]
    env=signals['envelope'][indices];feed=signals['feed_envelope'][indices]
    metric=orientation(env,cal['W']);ready=np.flatnonzero(tf>=cfg['warmup_s'])
    ref=int(ready[0]) if len(ready) else None
    absolute=metric['absolute_coordinate_angle'];increment=np.full(len(tf),np.nan)
    if ref is not None:increment[ref:]=absolute[ref:]-absolute[ref]
    delay,individual=delay_seconds(cal,cfg,coeff);source=tf-delay
    publication_delay=1/cfg['sample_rate_Hz'];available=tf+publication_delay
    sigma,moments=angle_sigma(metric,tf,cal,cfg,coeff,noise_upper(data,cfg))
    # 相对角还带有首参考帧噪声；Cauchy给出保守标准差上界，未忽略该项。
    increment_sigma_upper=np.full(len(tf),np.nan);corners=np.full(len(tf),np.nan)
    if ref is not None:
        increment_sigma_upper[ref:]=sigma[ref:]+sigma[ref]
        corners[ref:]=corner_sensitivity(env,feed,cal,cfg,ref)[ref:]
    calibration=calibration_check(data,cfg)
    warm=tf>=cfg['warmup_s'];energy=metric['energy'];linearity=metric['linearity']
    quality=cfg['sigma_multiplier']*increment_sigma_upper+corners
    valid=warm & (energy>=cfg['minimum_energy_normalized']) & (linearity>=cfg['minimum_linearity'])
    phase_use=2*np.pi*cfg['reference_loop_bandwidth_Hz']*(delay+publication_delay)
    latency_compatible=phase_use<=cfg['additional_phase_budget_rad']
    valid &= calibration['passed'] & latency_compatible & (quality<=cfg['angle_budget_rad'])
    phase_reference=np.angle(response(coeff['common_sos'],cfg['carrier_Hz'],cfg['sample_rate_Hz']))
    pll=.5*np.angle(np.exp(2j*(metric['phase']-phase_reference)))
    m=cfg['demod_window_samples'];fir_start=tf-2*(m-1)/cfg['sample_rate_Hz'];fir_center=tf-(m-1)/cfg['sample_rate_Hz']
    frames=np.c_[available,fir_start,fir_center,source,absolute,increment,np.where(valid,increment,np.nan),valid.astype(int),
        energy,linearity,metric['quadrature'],pll,sigma,increment_sigma_upper,corners,quality,np.full(len(tf),int(calibration['passed'])),tf]
    summary=dict(calibration=calibration,source_delay_s=delay+publication_delay,frontend_channel_delay_s=individual,
        publication_delay_s=publication_delay,processing_end_to_source_delay_s=delay,
        latency_budget_pass=bool(latency_compatible),delay_phase_use_rad=float(phase_use),
        reference_frame_index=ref,reference_source_time_s=float(source[ref]) if ref is not None else None,
        post_warmup_valid_fraction=float(np.mean(valid[warm])) if np.any(warm) else None,
        median_absolute_angle_sigma_rad=float(np.median(sigma[warm])) if np.any(warm) else None,
        maximum_corner_increment_sensitivity_rad=float(np.max(corners[warm])) if np.any(warm) else None,
        maximum_quality_budget_use_rad=float(np.max(quality[warm])) if np.any(warm) else None,
        maximum_quadrature_residual=float(np.max(abs(metric['quadrature'][warm]))) if np.any(warm) else None,
        median_PLL_detector_residual_rad=float(np.median(pll[warm])) if np.any(warm) else None,
        noise_probe_variance_upper_V2=noise_upper(data,cfg).tolist(),noise_impulse_moments=moments.tolist(),
        coefficients=coeff)
    return frames,summary,(t,u,y,signals)


COLUMNS=['available_s','fir_window_start_s','fir_window_center_s','estimated_source_center_s',
 'coordinate_angle_rad','increment_rad','published_increment_rad','valid','energy_normalized','linearity',
 'quadrature_residual','PLL_detector_residual_rad','absolute_angle_sigma_rad','increment_sigma_upper_rad',
 'calibration_corner_sensitivity_rad','quality_budget_rad','calibration_pass','sample_end_s']


def estimate(observations,output,window=None):
    observations=observations.resolve();used=[];cfg=read_json(HERE/'config.json')
    if window is not None:cfg['demod_window_samples']=window
    def load(name):
        p=(observations/name).resolve();assert p.is_relative_to(observations)
        used.append(dict(path=name,sha256=sha(p)));return read_json(p)
    protocol=load('protocol.json');rows=[]
    for case in protocol['cases']:
        data=load(case['file']);frames,summary,signals=process_case(data,cfg)
        write_csv(output/(case['id']+'_frames.csv'),frames,COLUMNS)
        summary['id']=case['id'];rows.append(summary)
        if case['id']=='case_001':
            t,u,y,sig=signals;n=8192
            write_csv(output/'stream_scoreboard.csv',np.c_[t[:n],u[:n],y[:n],sig['z'][:n],sig['envelope'][:n].real,sig['envelope'][:n].imag],
                ['t','u_x','u_y','y_x','y_y','z_x','z_y','I_x','I_y','Q_x','Q_y'])
        print(case['id'],'calibration='+str(summary['calibration']['passed']),'valid=%.3f'%summary['post_warmup_valid_fraction'],
              'sigma=%.4g'%summary['median_absolute_angle_sigma_rad'],'corner=%.4g'%summary['maximum_corner_increment_sensitivity_rad'])
    write_json(output/'estimates.json',dict(schema='A2-estimates-v1',source_inputs=used,cases=rows,
        config_sha256=sha(HERE/'config.json'),demod_window_samples=cfg['demod_window_samples'],processor_sha256=sha(__file__),dsp_sha256=sha(HERE/'a2_dsp.py'),
        scope='白噪声预算+窄带角点敏感度；已校准W；非无参考或完整闭环'))


if __name__=='__main__':
    from pathlib import Path
    p=argparse.ArgumentParser();p.add_argument('--observations',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--window',type=int)
    a=p.parse_args();estimate(a.observations,a.output,a.window)
