"""冻结与交付核验；独立种子后不修改核心算法、预算或评分规则。"""
from pathlib import Path
import argparse
import json
import shutil
import subprocess
import sys
import tempfile
import numpy as np
from a3_common import HERE,A2,read_json,write_json,sha,config


def verify(isolation=False):
    project=HERE.parent.parent.resolve()
    for row in read_json(HERE/'data/provenance.json')['sources']:
        path=(project/row['source']).resolve()
        assert path.is_relative_to(project) and sha(path)==row['sha256'],row['source']
    freeze=read_json(HERE/'method_freeze.json')
    for n,h in freeze['source_sha256'].items():assert sha(HERE/n)==h,'独立种子后核心已改变: '+n
    for n,h in freeze['a2_sha256'].items():assert sha(A2/n)==h,n
    for n,h in freeze['development_case_sha256'].items():assert sha(HERE/'data/observations'/n)==h,n
    for row in freeze['fresh_seed_plan']:
        d=read_json(HERE/'data/observations'/(row['id']+'.json'))
        assert d['stream_noise_seed']==row['seed'] and d['stream_noise_RMS_V']==row['sigma']
    scores=read_json(HERE/'evidence/scores.json');assert scores['summary']['profile_case_comparisons']==scores['summary']['checks_matched']==46
    assert scores['summary']['fresh_seed_comparisons']==8 and all(r['passed'] for r in scores['cases'])
    for window in [40,240]:
        result=read_json(HERE/'evidence'/('window_'+str(window))/'estimates.json')
        assert result['config_sha256']==sha(HERE/'config.json') and result['processor_sha256']==sha(HERE/'a3_process.py')
        for row in result['source_inputs']:assert sha(HERE/'data/observations'/row['path'])==row['sha256']
    for n in ['a3_process.py','a3_covariance.py','a3_reference.py','a3_source.py']:
        source=(HERE/n).read_text(encoding='utf-8');assert 'private_score' not in source and 'a3_score' not in source and 'a3_generate' not in source
    from a3_process import process_case
    from a3_reference import ReferenceManager
    for cid,duration in [('case_001',.35),('case_019',.2)]:
        frames,*_=process_case(read_json(HERE/'data/observations'/(cid+'.json')),dict(config(40),duration_s=duration))
        saved=np.loadtxt(HERE/'evidence/window_40'/(cid+'_frames.csv'),delimiter=',',skiprows=1)
        assert np.array_equal(frames,saved[:len(frames)],equal_nan=True),'参考管理器读取未来信息'
    table=np.loadtxt(HERE/'evidence/window_240/case_016_manager_scoreboard.csv',delimiter=',',skiprows=1)
    manager=ReferenceManager(config(240));output=[]
    for start in range(0,len(table),127):
        output.extend(manager.step(v[:5]) for v in table[start:start+127])
    assert np.array_equal(np.asarray(output),table[:,5:],equal_nan=True)
    motion=ReferenceManager(config(240))
    motion.step([.25,0,1,.001,1]);motion.step([.27,.02,1,.001,1])
    rejected=motion.step([.271,.25,1,.001,1])
    assert rejected[4]==1 and rejected[2]==0 and np.isnan(rejected[0]),'违反声明运动界必须锁存全局无效'
    math=read_json(HERE/'evidence/math_checks.json');assert math['maximum_shifted_kernel_Gram_relative_difference']<1e-7
    sim=read_json(HERE/'evidence/simulink_scoreboard.json');assert sim['NaN_masks_match'] and sim['maximum_absolute_difference']<1e-10
    mc=read_json(HERE/'evidence/matlab_noise_scoreboard.json')
    ratios=[v for c in mc['cases'] for v in c['relative_variance_observed_to_predicted']]
    assert all(.65<v<1.35 for v in ratios)
    identical=None
    if isolation:
        with tempfile.TemporaryDirectory(prefix='a3-isolation-',dir=HERE) as name:
            temporary=Path(name).resolve();assert temporary.is_relative_to(HERE.resolve())
            shutil.copytree(HERE/'data/observations',temporary/'observations');assert not (temporary/'private_score').exists()
            for window in [40,240]:
                target=temporary/str(window)
                subprocess.run([sys.executable,'-X','utf8',str(HERE/'a3_process.py'),'--observations',str(temporary/'observations'),
                    '--output',str(target),'--window',str(window)],check=True,capture_output=True,cwd=temporary)
                for original in (HERE/'evidence'/('window_'+str(window))).glob('*'):
                    assert original.read_bytes()==(target/original.name).read_bytes(),original.name
            identical=True
    result=dict(profile_case_checks=46,new_seed_checks=8,frozen_algorithm_budget_and_score=True,
        initial_wait_and_quality_prefix_causal=True,reference_state_chunk_bit_identical=True,
        reanchor_does_not_reset_origin_variance=True,short_gap_recovered_long_gap_global_invalid=True,motion_bound_violation_rejected=True,
        independent_Gram_relative_difference=math['maximum_shifted_kernel_Gram_relative_difference'],
        matlab_relative_variance_ratio_min=min(ratios),matlab_relative_variance_ratio_max=max(ratios),
        simulink_maximum_absolute_difference=sim['maximum_absolute_difference'],
        no_truth_directory_replay_byte_identical=identical,
        scope='白噪小扰动、冻结W和声明速率/相位界；非硬件、非全闭环或低误认证概率保证')
    if isolation:write_json(HERE/'evidence/independent_check.json',result)
    return result


def files():
    return {p.relative_to(HERE).as_posix():sha(p) for p in sorted(HERE.rglob('*')) if p.is_file()
        and '__pycache__' not in p.parts and not any(x.startswith('a3-isolation-') for x in p.parts)
        and p.name!='manifest.json' and p.suffix not in {'.slxc','.bak','.autosave'}}


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--isolation',action='store_true');parser.add_argument('--seal',action='store_true')
    args=parser.parse_args();result=verify(args.isolation)
    if args.seal:
        names=['manifest.json','config.json','a2_dsp.py','a2_score.py','data/private_score/truth.json']
        write_json(HERE/'manifest.json',dict(date='2026-11-03',files=files(),
            a2_dependencies={n:sha(A2/n) for n in names},
            project_dependencies={'research/port_to_metric_20261103/a0_common.py':sha(HERE.parent/'port_to_metric_20261103/a0_common.py')}))
    if (HERE/'manifest.json').exists():
        m=read_json(HERE/'manifest.json');assert files()==m['files'],'A3文件变化，需审查后重新封存'
        for n,h in m['a2_dependencies'].items():assert sha(A2/n)==h,n
        for n,h in m['project_dependencies'].items():assert sha(HERE.parent.parent/n)==h,n
    print(json.dumps(result,ensure_ascii=False,indent=2))
