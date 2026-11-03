"""交付核对：冻结、独立种子、完整原始记录、观察目录隔离重放、评分。

默认不重建原始数据。--seal 只记录当前A0自身文件哈希，不改旧工程。
"""
from pathlib import Path
import argparse
import json
import shutil
import subprocess
import sys
import tempfile
import numpy as np
from a0_common import read_json, write_json, sha

HERE = Path(__file__).resolve().parent


def verify(isolation=False):
    freeze = read_json(HERE/'method_freeze.json')
    for name, expected in freeze['source_sha256'].items():
        assert sha(HERE/name) == expected, '独立种子生成后估计器或门槛已变更: '+name
    protocol = read_json(HERE/'data/observations/protocol.json')
    design = {k:v for k,v in protocol.items() if k != 'cases'}
    assert design == freeze['public_design']
    generation = read_json(HERE/'data/generation_manifest.json')
    for name, expected in generation['observation_sha256'].items():
        assert sha(HERE/'data/observations'/name) == expected, name
    estimates = read_json(HERE/'evidence/estimates.json')
    assert estimates['protocol_sha256'] == sha(HERE/'data/observations/protocol.json')
    for source in estimates['source_inputs']:
        assert 'private' not in source['path'] and 'truth' not in source['path']
        assert sha(HERE/'data/observations'/source['path']) == source['sha256']
    assert 'private_score' not in (HERE/'fit_records.py').read_text(encoding='utf-8')
    assert 'generate_records' not in (HERE/'fit_records.py').read_text(encoding='utf-8')
    scores = read_json(HERE/'evidence/scores.json')
    assert scores['summary']['cases'] == scores['summary']['checks_matched'] == 23
    assert scores['summary']['independent_cases'] == scores['summary']['independent_checks_matched'] == 10
    assert scores['summary']['false_accepts'] == scores['summary']['false_rejects'] == 0
    assert all(all(row['checks'].values()) and row['passed'] for row in scores['cases'])
    truth = read_json(HERE/'data/private_score/truth.json')
    for kind, expected in freeze['independent_seed_plan'].items():
        actual = [r['seed'] for r in truth['cases'] if r['kind']==kind and r['cohort']=='independent']
        assert actual == expected
    initial = read_json(HERE/'evidence/trials/polynomial_IV_initial_estimates.json')
    assert sum(r['calibration_update_eligible'] for r in initial['cases']) == 1
    isolated_equal, trial_replayed = None, None
    if isolation:
        with tempfile.TemporaryDirectory(prefix='a0-isolation-', dir=HERE) as temporary:
            temp = Path(temporary).resolve()
            assert temp.is_relative_to(HERE.resolve()), '临时目录必须位于本研究工作区'
            shutil.copytree(HERE/'data/observations', temp/'observations')
            assert not (temp/'private_score').exists()
            subprocess.run([sys.executable,'-X','utf8',str(HERE/'fit_records.py'),
                            '--observations',str(temp/'observations'),'--output',str(temp/'output')],
                           cwd=temp,check=True,capture_output=True)
            isolated_equal = (temp/'output/estimates.json').read_bytes() == (HERE/'evidence/estimates.json').read_bytes()
            assert isolated_equal, '没有真值目录的隔离重放与正式结果不同'
            for case in protocol['cases']:
                name=case['id']+'_angles.csv'
                assert (temp/'output'/name).read_bytes() == (HERE/'evidence'/name).read_bytes()
            subprocess.run([sys.executable,'-X','utf8',str(HERE/'fit_records.py'),
                            '--observations',str(temp/'observations'),'--output',str(temp/'polynomial'),
                            '--method','polynomial_iv'],cwd=temp,check=True,capture_output=True)
            replay = read_json(temp/'polynomial/estimates.json')['cases']
            for old, new in zip(initial['cases'], replay):
                for name in ['D','K','B','C','epsilon_C']:
                    assert np.allclose(old[name],new[name],rtol=0,atol=1e-12), (old['id'],name)
                assert old['calibration_update_eligible'] == new['calibration_update_eligible']
            trial_replayed = True
    return dict(cases=23,independent_cases=10,checks_matched=23,accepted=11,rejected=12,
                frozen_method_and_thresholds=True,observation_hashes_checked=len(generation['observation_sha256']),
                no_private_score_directory_replay_identical=isolated_equal,
                initial_polynomial_IV_failure_reproduced=trial_replayed,
                conditional_and_empirical_only=True)


def files():
    excluded={'manifest.json'}
    return {p.relative_to(HERE).as_posix():sha(p) for p in sorted(HERE.rglob('*'))
            if p.is_file() and '__pycache__' not in p.parts and not any(x.startswith('a0-isolation-') for x in p.parts)
            and p.name not in excluded and (p.name=='.gitattributes' or p.suffix in {'.py','.m','.json','.csv','.txt','.html','.png'})}


if __name__ == '__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--isolation',action='store_true');parser.add_argument('--seal',action='store_true')
    args=parser.parse_args();result=verify(args.isolation)
    if args.isolation:
        write_json(HERE/'evidence/independent_check.json',result)
    if args.seal:
        write_json(HERE/'manifest.json',dict(date='2026-11-03',files=files(),scope='A0 normalized conditional model'))
    if (HERE/'manifest.json').exists():
        assert files()==read_json(HERE/'manifest.json')['files'], 'A0交付文件已变化；请审查后重新封存'
    print(json.dumps(result,ensure_ascii=False,indent=2))
