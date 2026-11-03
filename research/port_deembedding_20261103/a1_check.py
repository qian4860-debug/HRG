"""核验A1：独立KCL消元式对原12状态响应、仅观测隔离重放、源字节封存。"""
from pathlib import Path
import argparse
import json
import shutil
import subprocess
import sys
import tempfile
import numpy as np
from a1_fit import HERE,read_json,write_json,sha,complex_value


def verify(isolation=False):
    truth=read_json(HERE/'data/private_score/truth.json')['cases']
    scores=read_json(HERE/'evidence/scores.json')
    assert scores['summary']['comparisons']==scores['summary']['checks_matched']==27
    assert scores['summary']['primary_accepted']==4 and scores['summary']['primary_rejected']==5
    assert all(r['passed'] and all(r['checks'].values()) for r in scores['cases'])
    threshold=read_json(HERE/'acceptance.json');sim=read_json(HERE/'evidence/simulink_scoreboard.json')
    assert sim['states']==12 and sim['maximum_normalized_error']<threshold['simulink_normalized_max_error']
    # 另一种方程实现：不搭建12状态矩阵，直接消去各电路节点求r和y。
    maximum=0.;checked=0
    for item in truth:
        data=read_json(HERE/'data/observations'/(item['id']+'.json'));p=item['physical_parameters']
        for row in data['train']+data['validation']:
            s=2j*np.pi*row['frequency_Hz'];rs=data['electronics']['Rs'][row['load_index']-1]
            vd=complex_value(row,'u')/(1+s*np.asarray(p['driver_tau']))
            g=1/rs+p['G0'];load=-s/(p['Cs']*s+g);feed=p['Cds']*s/(p['Cs']*s+g)
            mech=s*s*np.eye(2)+s*np.asarray(item['D'])+np.asarray(item['K'])-p['kappa']*load*np.eye(2)
            r=np.linalg.solve(mech,(p['b']*np.asarray(p['drive_matrix'])+p['kappa']*feed*np.eye(2))@vd)
            vs=load*r+feed*vd;vc=vs/(rs*p['Cf']*(s+1/(p['Rf']*p['Cf'])))
            yp=(np.asarray(p['detect_matrix'])@vc)/(1+s/(2*np.pi*np.asarray(p['afe_bw'])))
            delta=np.linalg.norm(yp-complex_value(row,'y'))
            if row['sigma_V']==0:
                relative=float(delta/max(np.linalg.norm(yp),1e-100));maximum=max(maximum,relative)
                assert relative<1e-8,(item['id'],relative)
            else:assert delta<12*row['sigma_V']
            checked+=1
    # 每次运行核对所有输入哈希；检查估计器没有机械真值入口。
    fit_source=(HERE/'a1_fit.py').read_text(encoding='utf-8')
    assert 'private_score' not in fit_source and 'a1_generate' not in fit_source and 'a1_score' not in fit_source
    for mode in ['joint_loading','no_loading','raw_second_order']:
        result=read_json(HERE/'evidence'/mode/'estimates.json')
        assert result['estimator_sha256']==sha(HERE/'a1_fit.py')
        for row in result['source_inputs']:
            assert sha(HERE/'data/observations'/row['path'])==row['sha256']
    identical=None
    if isolation:
        with tempfile.TemporaryDirectory(prefix='a1-isolation-',dir=HERE) as tempname:
            temp=Path(tempname).resolve();assert temp.is_relative_to(HERE.resolve())
            shutil.copytree(HERE/'data/observations',temp/'observations');assert not (temp/'private_score').exists()
            for mode in ['joint_loading','no_loading','raw_second_order']:
                subprocess.run([sys.executable,'-X','utf8',str(HERE/'a1_fit.py'),'--observations',str(temp/'observations'),
                    '--output',str(temp/mode),'--mode',mode],check=True,capture_output=True,cwd=temp)
                for original in (HERE/'evidence'/mode).glob('*'):
                    assert original.read_bytes()==(temp/mode/original.name).read_bytes(),original.name
            identical=True
    result=dict(comparisons=27,all_behavior_and_score_checks=True,primary_accepted=4,primary_rejected=5,
        independent_KCL_rows_checked=checked,maximum_noiseless_KCL_relative_difference=maximum,
        full_12_state_Simulink_scoreboard=sim['maximum_normalized_error'],
        no_truth_directory_replay_byte_identical=identical,
        scope='实现互校与经验拒绝；非硬件、非无参考、非统计误认证概率保证')
    if isolation:write_json(HERE/'evidence/independent_check.json',result)
    return result


def files():
    return {p.relative_to(HERE).as_posix():sha(p) for p in sorted(HERE.rglob('*')) if p.is_file()
        and '__pycache__' not in p.parts and not any(x.startswith('a1-isolation-') for x in p.parts)
        and p.name!='manifest.json' and p.suffix not in {'.slxc','.bak','.autosave'}
        and not p.name.endswith('.slx.r2024b')}


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--isolation',action='store_true');parser.add_argument('--seal',action='store_true')
    args=parser.parse_args();result=verify(args.isolation)
    if args.seal:
        project=HERE.parent.parent
        dependencies=['HRG_WA_simulink/piezo_v10/revision_v10_2_cn/pcn_config.m',
            'HRG_WA_simulink/piezo_v10/revision_v10_2_cn/pcn_plant.m',
            'research/port_to_metric_20261103/a0_common.py']
        write_json(HERE/'manifest.json',dict(date='2026-11-03',files=files(),dependencies={n:sha(project/n) for n in dependencies}))
    if (HERE/'manifest.json').exists():
        manifest=read_json(HERE/'manifest.json');assert files()==manifest['files'],'A1文件已变化，须审查后封存'
        for n,expected in manifest['dependencies'].items():assert sha(HERE.parent.parent/n)==expected,n
    print(json.dumps(result,ensure_ascii=False,indent=2))
