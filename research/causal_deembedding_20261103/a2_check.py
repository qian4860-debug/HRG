"""交付核验：因果性、状态连续、极点、独立频率式、噪声核、隔离重放与封存。"""
from pathlib import Path
import argparse
import json
import math
import shutil
import subprocess
import sys
import tempfile
import numpy as np
from a2_dsp import (HERE,read_json,write_json,sha,CausalFrontend,synthesize,design,response,noise_moments)


def verify(isolation=False):
    cfg=read_json(HERE/'config.json');obs=HERE/'data/observations';data=read_json(obs/'case_001.json');cal=data['calibration']
    _,u,y=synthesize(data,cfg);u,y=u[:8192],y[:8192]
    full=CausalFrontend(cal,cfg).process(u,y)
    stream=CausalFrontend(cal,cfg);parts=[]
    for start in range(0,len(u),127):parts.append(stream.process(u[start:start+127],y[start:start+127]))
    for key in full:assert np.array_equal(np.vstack([p[key] for p in parts]),full[key]),key
    # 改未来只能改变未来，且长度改变不得改变已输出前缀。
    changed=y.copy();changed[4096:]=np.random.default_rng(3).standard_normal(changed[4096:].shape)
    future=CausalFrontend(cal,cfg).process(u,changed);prefix=CausalFrontend(cal,cfg).process(u[:4096],y[:4096])
    for key in full:
        assert np.array_equal(full[key][:4096],future[key][:4096])
        assert np.array_equal(full[key][:4096],prefix[key])
    coeff=design(cal,cfg);maxpole=0.;maxfreq=0.;k=2*np.pi*cfg['carrier_Hz']/np.tan(np.pi*cfg['carrier_Hz']/cfg['sample_rate_Hz'])
    freq=np.array([10,250,999,1000,1200,6000,15000]);s=1j*k*np.tan(np.pi*freq/cfg['sample_rate_Hz'])
    wh=2*np.pi*cfg['washout_Hz'];wb=2*np.pi*cfg['regularizer_cutoff_Hz'];a=1/(cal['Rf']*cal['Cf']);g=1/cal['Rs']+cal['G0']
    for j in range(2):
        lam=2*np.pi*cal['afe_bw'][j]
        direct=-cal['Rs']*cal['Cf']/lam*(s+lam)*(s+a)*(cal['Cs']*s+g)/(s+wh)*(wb/(s+wb))**3/cfg['charge_scale_C']
        evaluated=response(coeff['inverse_sos'][j],freq,cfg['sample_rate_Hz'])
        relative=float(np.max(abs(evaluated-direct)/abs(direct)));assert relative<1e-9;maxfreq=max(maxfreq,relative)
    for sos in coeff['inverse_sos']+coeff['driver_sos']+[coeff['common_sos']]:
        for sec in sos:
            poles=np.roots(sec['a']);assert np.all(abs(poles)<1);maxpole=max(maxpole,float(np.max(abs(poles))))
    m1=noise_moments(coeff,cfg,16384);m2=noise_moments(coeff,cfg,32768)
    tail=float(np.linalg.norm(m1-m2)/np.linalg.norm(m2));assert tail<1e-7
    scores=read_json(HERE/'evidence/scores.json');assert scores['summary']['checks_matched']==scores['summary']['profile_case_comparisons']==30
    assert all(r['passed'] for r in scores['cases'])
    for window in [40,240]:
        result=read_json(HERE/'evidence'/('window_'+str(window))/'estimates.json')
        assert result['processor_sha256']==sha(HERE/'a2_process.py') and result['dsp_sha256']==sha(HERE/'a2_dsp.py')
        assert result['config_sha256']==sha(HERE/'config.json')
        for item in result['source_inputs']:assert sha(obs/item['path'])==item['sha256']
    for name in ['a2_process.py','a2_dsp.py']:
        source=(HERE/name).read_text(encoding='utf-8');assert 'private_score' not in source and 'a2_generate' not in source and 'a2_score' not in source
    # 400点会超预设5Hz/0.2rad纯延迟预算；即使无噪也必须拒绝。
    from a2_process import process_case
    short_frames,_,_=process_case(data,dict(cfg,duration_s=.35))
    saved=np.loadtxt(HERE/'evidence/window_40/case_001_frames.csv',delimiter=',',skiprows=1)
    assert np.array_equal(short_frames,saved[:len(short_frames)],equal_nan=True),'质量/参考帧逻辑不能使用未来流'
    assert np.all(np.isnan(short_frames[short_frames[:,0]<cfg['warmup_s'],5]))
    pending_frames,pending,_=process_case(data,dict(cfg,duration_s=.1))
    assert pending['reference_frame_index'] is None and np.all(np.isnan(pending_frames[:,5:7]))
    assert not np.any(pending_frames[:,7]),'不足预热长度的流必须保持等待，不能报错或发布假零角'
    too_slow=dict(cfg,demod_window_samples=400,duration_s=.35)
    frames,result,_=process_case(data,too_slow)
    assert not result['latency_budget_pass'] and not np.any(frames[:,7])
    identical=None
    if isolation:
        with tempfile.TemporaryDirectory(prefix='a2-isolation-',dir=HERE) as directory:
            tmp=Path(directory).resolve();assert tmp.is_relative_to(HERE.resolve())
            shutil.copytree(obs,tmp/'observations');assert not (tmp/'private_score').exists()
            for window in [40,240]:
                output=tmp/str(window)
                subprocess.run([sys.executable,'-X','utf8',str(HERE/'a2_process.py'),'--observations',str(tmp/'observations'),
                    '--output',str(output),'--window',str(window)],check=True,capture_output=True,cwd=tmp)
                for p in (HERE/'evidence'/('window_'+str(window))).glob('*'):
                    assert p.read_bytes()==(output/p.name).read_bytes(),p.name
            identical=True
    sim=read_json(HERE/'evidence/simulink_scoreboard.json')
    assert sim['samples']==8192 and sim['maximum_absolute_difference']<1e-8
    result=dict(profile_case_checks=30,chunked_state_bit_identical=True,future_and_prefix_causal=True,
        quality_prefix_causal_and_reference_pending_NaN=True,short_stream_reference_pending_without_error=True,
        maximum_digital_pole_radius=maxpole,independent_frequency_formula_relative_difference=maxfreq,
        noise_kernel_truncation_relative_difference=tail,excessive_delay_rejected=True,
        simulink_maximum_absolute_difference=sim['maximum_absolute_difference'],no_truth_directory_replay_identical=identical,
        scope='双精度离散算法、所列白噪/校准假设与经验角点预算；非闭环稳定性或硬件认证')
    if isolation:write_json(HERE/'evidence/independent_check.json',result)
    return result


def files():
    return {p.relative_to(HERE).as_posix():sha(p) for p in sorted(HERE.rglob('*')) if p.is_file()
        and '__pycache__' not in p.parts and not any(x.startswith('a2-isolation-') for x in p.parts)
        and p.name!='manifest.json' and p.suffix not in {'.slxc','.bak','.autosave'}}


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--isolation',action='store_true');p.add_argument('--seal',action='store_true')
    args=p.parse_args();result=verify(args.isolation)
    if args.seal:
        project=HERE.parent.parent
        names=['research/port_to_metric_20261103/a0_common.py','research/port_deembedding_20261103/manifest.json',
            'research/port_deembedding_20261103/data/private_score/truth.json',
            'research/port_deembedding_20261103/data/observations/case_002.json',
            'research/port_deembedding_20261103/evidence/joint_loading/estimates.json',
            'HRG_WA_simulink/piezo_v10/revision_v10_2_cn/pcn_plant.m',
            'HRG_WA_simulink/piezo_v10/revision_v10_2_cn/pcn_config.m',
            'HRG_WA_simulink/piezo_v10/revision_v10_2_cn/pcn_tick.m']
        write_json(HERE/'manifest.json',dict(date='2026-11-03',files=files(),dependencies={n:sha(project/n) for n in names}))
    if (HERE/'manifest.json').exists():
        m=read_json(HERE/'manifest.json');assert files()==m['files'],'A2文件变化，请审查后重新封存'
        for n,h in m['dependencies'].items():assert sha(HERE.parent.parent/n)==h,n
    print(json.dumps(result,ensure_ascii=False,indent=2))
