"""公开端口流→共同原点协方差→参考管理；不读评分真值，不调宽A2预算。"""
from pathlib import Path
import argparse
import json
import numpy as np
from a3_common import (HERE,config,read_json,write_json,write_csv,sha,CausalFrontend,orientation,
    delay_seconds,calibration_check,noise_upper,corner_sensitivity)
from a3_covariance import KernelBank,projection,relative_variance,reanchored_variance
from a3_reference import ReferenceManager
from a3_source import stream

BANKS={}


def noise_check(data,cfg):
    probe=np.asarray(data['noise_probe_V']);p=probe-np.mean(probe,axis=0);values=[]
    for lag in cfg['noise_probe_correlation_lags']:
        for j in range(2):
            denominator=np.sqrt(np.sum(p[lag:,j]**2)*np.sum(p[:-lag,j]**2))
            values.append(float(np.sum(p[lag:,j]*p[:-lag,j])/denominator) if denominator>0 else 0.)
    maximum=max(abs(np.asarray(values)))
    return dict(passed=bool(maximum<=cfg['noise_probe_max_abs_correlation']),maximum_absolute_lag_correlation=float(maximum),
        scope='所列探针滞后相关性筛查；非白性充分证明或通用有色噪声处理')


def process_case(data,cfg):
    t,u,y,acquired=stream(data,cfg);frontend=CausalFrontend(data['calibration'],cfg)
    signals=frontend.process(u,y);coeff=frontend.coefficients
    key=json.dumps([coeff['inverse_sos'],cfg['demod_window_samples']],sort_keys=True)
    if key not in BANKS:BANKS[key]=KernelBank(coeff,cfg)
    bank=BANKS[key];idx=np.arange(0,len(t),cfg['frame_decimation']);tf=t[idx];available=tf+1/cfg['sample_rate_Hz']
    metric=orientation(signals['envelope'][idx],data['calibration']['W'])
    c,psi=projection(metric,data['calibration'],tf,cfg);variance=noise_upper(data,cfg)
    absolute,_,_=relative_variance(bank,c,psi,idx,variance,None)
    cal=calibration_check(data,cfg);noise=noise_check(data,cfg)
    guard=int(round(cfg['recovery_guard_s']*cfg['sample_rate_Hz']))
    last_bad=np.maximum.accumulate(np.where(~acquired,np.arange(len(t)),-guard-1))
    recovered=(idx-last_bad[idx])>=guard
    healthy=(tf>=cfg['warmup_s']) & recovered & (metric['energy']>=cfg['minimum_energy_normalized'])
    # 两端各取3sigma相位误差，合计不超过声明的组合相位裕量。
    healthy &= (metric['linearity']>=cfg['minimum_linearity']) & (6*np.sqrt(absolute)<=cfg['phase_uncertainty_margin_rad'])
    healthy &= cal['passed'] & noise['passed']
    candidates=np.flatnonzero(healthy);ref=int(candidates[0]) if len(candidates) else None
    absolute,relative,cross=relative_variance(bank,c,psi,idx,variance,ref)
    cauchy=np.full(len(tf),np.nan);corners=cauchy.copy()
    if ref is not None:
        cauchy[ref:]=np.sqrt(absolute[ref:])+np.sqrt(absolute[ref])
        corners[ref:]=corner_sensitivity(signals['envelope'][idx],signals['feed_envelope'][idx],data['calibration'],cfg,ref)[ref:]
    joint=np.sqrt(relative);quality=cfg['sigma_multiplier']*joint+corners
    conservative=cfg['sigma_multiplier']*cauchy+corners
    delay,_=delay_seconds(data['calibration'],cfg,coeff);delay+=1/cfg['sample_rate_Hz']
    latency=2*np.pi*cfg['reference_loop_bandwidth_Hz']*delay<=cfg['additional_phase_budget_rad']
    principal=.5*np.angle(np.exp(2j*metric['absolute_coordinate_angle']))
    manager=ReferenceManager(cfg,True);fixed=ReferenceManager(cfg,False);outputs=[];fixed_outputs=[];telescope=[];inputs=[]
    anchor=ref
    for i in range(len(tf)):
        frame=[available[i],principal[i],float(healthy[i]),quality[i],float(latency)]
        inputs.append(frame);out=manager.step(frame);fo=fixed.step(frame)
        if out[7] and out[8]:anchor=i
        rv=np.nan
        if ref is not None and i>=ref and healthy[i] and out[8]:
            rv=reanchored_variance(bank,c,psi,idx,variance,i,anchor,ref)
            assert abs(rv-relative[i])<=1e-12*max(absolute[i]+absolute[ref],1e-25)
        outputs.append(out);fixed_outputs.append(fo);telescope.append(rv)
    out=np.asarray(outputs);fo=np.asarray(fixed_outputs)
    ready=np.zeros(len(tf),bool)
    if ref is not None:ready=available-available[ref]>=cfg['reference_holdoff_s']-1e-12
    base_valid=healthy & ready & (out[:,8]==1) & latency & (conservative<=cfg['angle_budget_rad'])
    warm=tf>=cfg['warmup_s'];origin_variance=np.full(len(tf),np.nan);reference_field=np.full(len(tf),-1.)
    if ref is not None:origin_variance[ref:]=absolute[ref];reference_field[ref:]=ref
    frame_values=np.c_[available,tf-(delay-1/cfg['sample_rate_Hz']),principal,out[:,0],out[:,1],out[:,2],healthy.astype(int),
        joint,cauchy,base_valid.astype(int),quality,conservative,cross,absolute,origin_variance,out[:,3],out[:,7],out[:,5],out[:,4],
        out[:,6],telescope,reference_field,corners,np.sqrt(absolute),metric['energy'],metric['linearity'],metric['quadrature'],fo[:,0],fo[:,2]]
    ready_mask=warm & ready
    summary=dict(calibration=cal,noise_model_check=noise,source_delay_s=delay,
        original_reference_frame=ref,original_reference_source_time_s=float(frame_values[ref,1]) if ref is not None else None,
        post_warmup_joint_valid_fraction=float(np.mean(out[warm,2])) if np.any(warm) else None,
        post_warmup_cauchy_valid_fraction=float(np.mean(base_valid[warm])) if np.any(warm) else None,
        after_reference_holdoff_joint_valid_fraction=float(np.mean(out[ready_mask,2])) if np.any(ready_mask) else None,
        final_anchor_count=int(out[-1,3]),needs_external_reference=bool(out[-1,4]),final_segment=int(out[-1,5]),
        median_absolute_sigma_rad=float(np.median(np.sqrt(absolute[warm]))) if np.any(warm) else None,
        maximum_reanchor_variance_difference=float(np.nanmax(abs(np.asarray(telescope)-relative))) if np.any(np.isfinite(telescope)) else None,
        coefficients=coeff)
    return frame_values,summary,np.asarray(inputs),out,(bank,c,psi,idx,variance,metric)


COLUMNS=['available_s','source_center_s','principal_coordinate_angle_rad','candidate_global_rad','published_global_rad','valid','healthy',
 'joint_increment_sigma_rad','cauchy_increment_sigma_rad','cauchy_valid','joint_quality_rad','cauchy_quality_rad','covariance_to_origin_rad2',
 'current_variance_rad2','origin_variance_rad2','anchor_count','anchor_event','segment_id','needs_external_reference','local_segment_increment_rad',
 'reanchor_global_variance_rad2','original_reference_frame','calibration_corner_sensitivity_rad','absolute_sigma_rad','energy','linearity','quadrature',
 'fixed_reference_global_rad','fixed_reference_valid']


def estimate(observations,output,window):
    observations=Path(observations).resolve();output=Path(output).resolve();cfg=config(window);used=[]
    def load(name):
        p=(observations/name).resolve();assert p.is_relative_to(observations)
        used.append(dict(path=name,sha256=sha(p)));return read_json(p)
    protocol=load('protocol.json');rows=[]
    for case in protocol['cases']:
        data=load(case['file']);frames,result,inputs,outputs,_=process_case(data,cfg)
        cid=case['id'];write_csv(output/(cid+'_frames.csv'),frames,COLUMNS)
        if cid in ['case_005','case_016','case_017','case_019']:
            write_csv(output/(cid+'_manager_scoreboard.csv'),np.c_[inputs,outputs],
                ['available_s','principal','healthy','quality_rad','latency_pass','global','published','valid','anchor_count','lost','segment','local','event','origin_retained'])
        result['id']=cid;rows.append(result)
        print(cid,window,'joint=%.3f'%result['post_warmup_joint_valid_fraction'],'cauchy=%.3f'%result['post_warmup_cauchy_valid_fraction'],
              'lost='+str(result['needs_external_reference']))
    write_json(output/'estimates.json',dict(schema='A3-estimates-v1',window_samples=window,cases=rows,source_inputs=used,
        config_sha256=sha(HERE/'config.json'),processor_sha256=sha(__file__),
        scope='固定全局原点联合协方差；周期重锚定不重置原点误差；失去模π分支后不自动恢复全局角'))


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--observations',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--window',type=int,required=True)
    args=p.parse_args();estimate(args.observations,args.output,args.window)
